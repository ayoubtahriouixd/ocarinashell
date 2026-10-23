#include "view/capture.hpp"

#include <chrono>
#include <cstdio>
#include <cstring>
#include <ctime>
#include <string>

#include <pipewire/pipewire.h>
#include <spa/debug/types.h>
#include <spa/param/video/format-utils.h>
#include <spa/pod/builder.h>
#include <spa/utils/result.h>

namespace nk {

namespace {

double monoNow() {
    timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1e9;
}

// EnumFormat: BGRx / BGRA, DMA-BUF modifiers we can copy from (niri fixates), any size, variable rate up to 1000 fps
const spa_pod* enumFormat(spa_pod_builder* b, spa_video_format fmt, const std::vector<uint64_t>& mods) {
    spa_pod_frame f[2];
    spa_pod_builder_push_object(b, &f[0], SPA_TYPE_OBJECT_Format, SPA_PARAM_EnumFormat);
    spa_pod_builder_add(b, SPA_FORMAT_mediaType, SPA_POD_Id(SPA_MEDIA_TYPE_video), 0);
    spa_pod_builder_add(b, SPA_FORMAT_mediaSubtype, SPA_POD_Id(SPA_MEDIA_SUBTYPE_raw), 0);
    spa_pod_builder_add(b, SPA_FORMAT_VIDEO_format, SPA_POD_Id(fmt), 0);
    spa_pod_builder_prop(b, SPA_FORMAT_VIDEO_modifier, SPA_POD_PROP_FLAG_MANDATORY | SPA_POD_PROP_FLAG_DONT_FIXATE);
    spa_pod_builder_push_choice(b, &f[1], SPA_CHOICE_Enum, 0);
    spa_pod_builder_long(b, static_cast<int64_t>(mods[0]));      // default
    for (uint64_t m : mods)
        spa_pod_builder_long(b, static_cast<int64_t>(m));
    spa_pod_builder_pop(b, &f[1]);
    spa_rectangle def{1920, 1080}, mn{1, 1}, mx{16384, 16384};
    spa_pod_builder_add(b, SPA_FORMAT_VIDEO_size, SPA_POD_CHOICE_RANGE_Rectangle(&def, &mn, &mx), 0);
    spa_fraction r0{0, 1};
    spa_pod_builder_add(b, SPA_FORMAT_VIDEO_framerate, SPA_POD_Fraction(&r0), 0);
    spa_fraction fd{120, 1}, fmn{0, 1}, fmx{1000, 1};
    spa_pod_builder_add(b, SPA_FORMAT_VIDEO_maxFramerate, SPA_POD_CHOICE_RANGE_Fraction(&fd, &fmn, &fmx), 0);
    return static_cast<const spa_pod*>(spa_pod_builder_pop(b, &f[0]));
}

} // namespace

struct Capture::Hooks {
    Capture* self;
    spa_hook stream{};
    spa_hook registry{};
    pw_stream_events streamEvents{};
    pw_registry_events registryEvents{};
};

bool Capture::start(uint32_t nodeId, const std::vector<uint64_t>& modifiers) {
    if (modifiers.empty()) {
        std::fprintf(stderr, "nameraka view: Vulkan no ofrece modificadores para BGRA\n");
        return false;
    }
    target_ = nodeId;
    modifiers_ = modifiers;
    pw_init(nullptr, nullptr);
    loop_ = pw_thread_loop_new("nameraka-pw", nullptr);
    context_ = pw_context_new(pw_thread_loop_get_loop(loop_), nullptr, 0);
    if (!context_ || pw_thread_loop_start(loop_) < 0)
        return false;
    pw_thread_loop_lock(loop_);
    core_ = pw_context_connect(context_, nullptr, 0);
    if (!core_) {
        pw_thread_loop_unlock(loop_);
        std::fprintf(stderr, "nameraka view: no hay conexión con PipeWire\n");
        return false;
    }
    hooks_ = new Hooks{this};
    hooks_->streamEvents.version = PW_VERSION_STREAM_EVENTS;
    hooks_->streamEvents.state_changed = [](void* d, pw_stream_state, pw_stream_state s, const char* err) {
        static_cast<Hooks*>(d)->self->onState(s, err);
    };
    hooks_->streamEvents.param_changed = [](void* d, uint32_t id, const spa_pod* p) {
        static_cast<Hooks*>(d)->self->onParamChanged(id, p);
    };
    hooks_->streamEvents.process = [](void* d) { static_cast<Hooks*>(d)->self->onProcess(); };
    hooks_->registryEvents.version = PW_VERSION_REGISTRY_EVENTS;
    hooks_->registryEvents.global = [](void* d, uint32_t id, uint32_t, const char* type, uint32_t, const spa_dict* props) {
        static_cast<Hooks*>(d)->self->onGlobal(id, type, props);
    };
    registry_ = pw_core_get_registry(core_, PW_VERSION_REGISTRY, 0);
    pw_registry_add_listener(registry_, &hooks_->registry, &hooks_->registryEvents, hooks_);

    stream_ = pw_stream_new(core_, "nameraka",
                            pw_properties_new(PW_KEY_MEDIA_TYPE, "Video", PW_KEY_MEDIA_CATEGORY, "Capture",
                                              PW_KEY_MEDIA_ROLE, "Screen", PW_KEY_NODE_NAME, "nameraka",
                                              PW_KEY_NODE_DESCRIPTION, "滑 Nameraka", nullptr));
    pw_stream_add_listener(stream_, &hooks_->stream, &hooks_->streamEvents, hooks_);
    uint8_t buf[4096];
    spa_pod_builder b = SPA_POD_BUILDER_INIT(buf, sizeof buf);
    const spa_pod* params[2] = {enumFormat(&b, SPA_VIDEO_FORMAT_BGRx, modifiers_), enumFormat(&b, SPA_VIDEO_FORMAT_BGRA, modifiers_)};
    int r = pw_stream_connect(stream_, PW_DIRECTION_INPUT, PW_ID_ANY, PW_STREAM_FLAG_DONT_RECONNECT, params, 2);
    pw_thread_loop_unlock(loop_);
    if (r < 0) {
        std::fprintf(stderr, "nameraka view: pw_stream_connect → %s\n", spa_strerror(r));
        return false;
    }
    return true;
}

void Capture::onGlobal(uint32_t id, const char* type, const spa_dict* props) {
    if (std::strcmp(type, PW_TYPE_INTERFACE_Port) != 0 || !props)
        return;
    const char* node = spa_dict_lookup(props, PW_KEY_NODE_ID);
    const char* dir = spa_dict_lookup(props, PW_KEY_PORT_DIRECTION);
    if (!node || !dir)
        return;
    uint32_t n = static_cast<uint32_t>(std::strtoul(node, nullptr, 10));
    if (n == target_ && !std::strcmp(dir, "out"))
        outPort_ = id;
    else if (ourNode_ && n == ourNode_ && !std::strcmp(dir, "in"))
        inPort_ = id;
    portNode_[id] = n;
    tryLink();
}

void Capture::tryLink() {
    if (link_ || !ourNode_ || !outPort_)
        return;
    if (!inPort_) {                       // our port may have been announced before we knew our node id
        for (auto& [port, node] : portNode_)
            if (node == ourNode_ && port != outPort_)
                inPort_ = port;
        if (!inPort_)
            return;
    }
    auto props = pw_properties_new(PW_KEY_LINK_OUTPUT_NODE, std::to_string(target_).c_str(), PW_KEY_LINK_OUTPUT_PORT,
                                   std::to_string(outPort_).c_str(), PW_KEY_LINK_INPUT_NODE,
                                   std::to_string(ourNode_).c_str(), PW_KEY_LINK_INPUT_PORT,
                                   std::to_string(inPort_).c_str(), PW_KEY_OBJECT_LINGER, "false", nullptr);
    link_ = static_cast<pw_proxy*>(pw_core_create_object(core_, "link-factory", PW_TYPE_INTERFACE_Link,
                                                         PW_VERSION_LINK, &props->dict, 0));
    pw_properties_free(props);
    linked_ = link_ != nullptr;
    std::fprintf(stderr, "nameraka view: enlace niri %u:%u → nameraka %u:%u\n", target_, outPort_, ourNode_, inPort_);
}

void Capture::onState(int state, const char* error) {
    std::fprintf(stderr, "nameraka view: PipeWire %s%s%s\n", pw_stream_state_as_string(static_cast<pw_stream_state>(state)),
                 error ? " · " : "", error ? error : "");
    if (state == PW_STREAM_STATE_ERROR || state == PW_STREAM_STATE_UNCONNECTED) {
        std::lock_guard l(m_);
        failed_ = !stopping_;
        cv_.notify_all();
        return;
    }
    if (!ourNode_ && state >= PW_STREAM_STATE_PAUSED) {
        ourNode_ = pw_stream_get_node_id(stream_);
        if (ourNode_ != SPA_ID_INVALID) {
            for (auto& [port, node] : portNode_)
                if (node == ourNode_)
                    inPort_ = port;
            tryLink();
        } else {
            ourNode_ = 0;
        }
    }
}

void Capture::onParamChanged(uint32_t id, const spa_pod* param) {
    if (id != SPA_PARAM_Format || !param)
        return;
    spa_video_info_raw info{};
    if (spa_format_video_raw_parse(param, &info) < 0)
        return;
    w_ = static_cast<int>(info.size.width);
    h_ = static_cast<int>(info.size.height);
    modifier_ = info.modifier;
    std::fprintf(stderr, "nameraka view: formato %s %dx%d modificador 0x%016llx\n",
                 spa_debug_type_find_short_name(spa_type_video_format, info.format), w_, h_,
                 static_cast<unsigned long long>(modifier_));
    uint8_t buf[1024];
    spa_pod_builder b = SPA_POD_BUILDER_INIT(buf, sizeof buf);
    const spa_pod* params[2];
    params[0] = static_cast<const spa_pod*>(spa_pod_builder_add_object(
        &b, SPA_TYPE_OBJECT_ParamBuffers, SPA_PARAM_Buffers, SPA_PARAM_BUFFERS_buffers, SPA_POD_CHOICE_RANGE_Int(4, 2, 8),
        SPA_PARAM_BUFFERS_blocks, SPA_POD_Int(1), SPA_PARAM_BUFFERS_dataType, SPA_POD_CHOICE_FLAGS_Int(1 << SPA_DATA_DmaBuf)));
    params[1] = static_cast<const spa_pod*>(spa_pod_builder_add_object(
        &b, SPA_TYPE_OBJECT_ParamMeta, SPA_PARAM_Meta, SPA_PARAM_META_type, SPA_POD_Id(SPA_META_Header),
        SPA_PARAM_META_size, SPA_POD_Int(sizeof(spa_meta_header))));
    pw_stream_update_params(stream_, params, 2);
}

void Capture::onProcess() {
    pw_buffer* newest = nullptr;
    while (pw_buffer* b = pw_stream_dequeue_buffer(stream_)) {
        spa_buffer* sb = b->buffer;
        auto* h = static_cast<spa_meta_header*>(spa_buffer_find_meta_data(sb, SPA_META_Header, sizeof(spa_meta_header)));
        bool corrupt = (h && (h->flags & SPA_META_HEADER_FLAG_CORRUPTED))
            || sb->n_datas < 1 || sb->datas[0].type != SPA_DATA_DmaBuf || sb->datas[0].chunk->size == 0;
        if (corrupt) {
            pw_stream_queue_buffer(stream_, b);
            continue;
        }
        if (newest)
            pw_stream_queue_buffer(stream_, newest);
        newest = b;
    }
    if (!newest)
        return;
    std::lock_guard l(m_);
    if (pending_) {                         // the render thread did not take the previous one: it is stale now
        pw_stream_queue_buffer(stream_, pending_);
        ++dropped;
    }
    pending_ = newest;
    pendingArrival_ = monoNow();
    lastArrival = pendingArrival_;
    cv_.notify_one();
}

bool Capture::next(Frame& out, int timeoutMs) {
    std::unique_lock l(m_);
    if (!cv_.wait_for(l, std::chrono::milliseconds(timeoutMs), [&] { return pending_ || stopping_ || failed_; }))
        return false;
    if (!pending_)
        return false;
    pw_buffer* b = pending_;
    pending_ = nullptr;
    spa_data& d = b->buffer->datas[0];
    out.buffer = b;
    out.arrival = pendingArrival_;
    out.fd = static_cast<int>(d.fd);
    out.offset = d.chunk->offset;
    out.stride = static_cast<uint32_t>(d.chunk->stride);
    out.modifier = modifier_;
    out.w = w_;
    out.h = h_;
    return true;
}

void Capture::done(const Frame& f) {
    std::lock_guard d(doneM_);
    {
        std::lock_guard l(m_);
        if (stopping_)                  // the stream is going away and takes its buffers with it
            return;
    }
    if (!f.buffer || !loop_ || !stream_)
        return;
    pw_thread_loop_lock(loop_);
    pw_stream_queue_buffer(stream_, f.buffer);
    pw_thread_loop_unlock(loop_);
}

void Capture::setActive(bool on) {
    if (!loop_ || !stream_)
        return;
    pw_thread_loop_lock(loop_);
    pw_stream_set_active(stream_, on);
    pw_thread_loop_unlock(loop_);
}

void Capture::stop() {
    {
        std::lock_guard l(m_);
        stopping_ = true;
        cv_.notify_all();
    }
    std::lock_guard d(doneM_);          // waits for a done() in flight; later ones see stopping_
    if (!loop_)
        return;
    pw_thread_loop_lock(loop_);
    if (link_)
        pw_proxy_destroy(link_);
    if (stream_) {
        pw_stream_disconnect(stream_);
        pw_stream_destroy(stream_);
    }
    if (registry_)
        pw_proxy_destroy(reinterpret_cast<pw_proxy*>(registry_));
    if (core_)
        pw_core_disconnect(core_);
    pw_thread_loop_unlock(loop_);
    pw_thread_loop_stop(loop_);
    if (context_)
        pw_context_destroy(context_);
    pw_thread_loop_destroy(loop_);
    delete hooks_;
    link_ = nullptr;
    stream_ = nullptr;
    registry_ = nullptr;
    core_ = nullptr;
    context_ = nullptr;
    loop_ = nullptr;
    hooks_ = nullptr;
    pending_ = nullptr;
}

} // namespace nk
