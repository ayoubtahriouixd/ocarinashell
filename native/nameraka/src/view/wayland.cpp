#include "view/wayland.hpp"

#include <cerrno>
#include <cstdio>
#include <cstring>
#include <poll.h>
#include <time.h>
#include <wayland-client.h>

#include "fractional-scale-v1-client-protocol.h"
#include "viewporter-client-protocol.h"
// the generated header names a parameter `namespace` (a C++ keyword)
#define namespace namespace_
#include "wlr-layer-shell-unstable-v1-client-protocol.h"
#undef namespace

namespace nk {

namespace {

void outGeometry(void*, wl_output*, int32_t, int32_t, int32_t, int32_t, int32_t, const char*, const char*, int32_t t) {
    (void)t;
}
void outMode(void* data, wl_output*, uint32_t flags, int32_t w, int32_t h, int32_t) {
    auto* o = static_cast<Output*>(data);
    if (flags & WL_OUTPUT_MODE_CURRENT) {
        o->modeW = w;
        o->modeH = h;
    }
}
void outDone(void* data, wl_output*) { static_cast<Output*>(data)->done = true; }
void outScale(void*, wl_output*, int32_t) {}
void outName(void* data, wl_output*, const char* name) { static_cast<Output*>(data)->connector = name; }
void outDesc(void*, wl_output*, const char*) {}

void outGeometryT(void* data, wl_output* o, int32_t x, int32_t y, int32_t pw, int32_t ph, int32_t sp, const char* mk,
                  const char* md, int32_t t) {
    static_cast<Output*>(data)->transform = t;
    outGeometry(data, o, x, y, pw, ph, sp, mk, md, t);
}
const wl_output_listener kOutputListenerT = {outGeometryT, outMode, outDone, outScale, outName, outDesc};

void regGlobal(void* data, wl_registry* reg, uint32_t name, const char* iface, uint32_t version) {
    auto* w = static_cast<Wayland*>(data);
    if (!std::strcmp(iface, wl_compositor_interface.name)) {
        w->compositor = static_cast<wl_compositor*>(wl_registry_bind(reg, name, &wl_compositor_interface, 4));
    } else if (!std::strcmp(iface, zwlr_layer_shell_v1_interface.name)) {
        w->layerShell = static_cast<zwlr_layer_shell_v1*>(
            wl_registry_bind(reg, name, &zwlr_layer_shell_v1_interface, version < 4 ? version : 4));
    } else if (!std::strcmp(iface, wp_viewporter_interface.name)) {
        w->viewporter = static_cast<wp_viewporter*>(wl_registry_bind(reg, name, &wp_viewporter_interface, 1));
    } else if (!std::strcmp(iface, wp_fractional_scale_manager_v1_interface.name)) {
        w->fractional = static_cast<wp_fractional_scale_manager_v1*>(
            wl_registry_bind(reg, name, &wp_fractional_scale_manager_v1_interface, 1));
    } else if (!std::strcmp(iface, wl_output_interface.name) && version >= 4) {
        auto* o = new Output;
        o->name = name;
        o->wl = static_cast<wl_output*>(wl_registry_bind(reg, name, &wl_output_interface, 4));
        wl_output_add_listener(o->wl, &kOutputListenerT, o);
        w->outputs.push_back(o);
    }
}
void regRemove(void* data, wl_registry*, uint32_t name) {
    auto* w = static_cast<Wayland*>(data);
    for (auto it = w->outputs.begin(); it != w->outputs.end(); ++it) {
        if ((*it)->name == name) {
            wl_output_destroy((*it)->wl);
            delete *it;
            w->outputs.erase(it);
            break;
        }
    }
}
const wl_registry_listener kRegistryListener = {regGlobal, regRemove};

void layerConfigure(void* data, zwlr_layer_surface_v1* s, uint32_t serial, uint32_t w, uint32_t h) {
    static_cast<Wayland*>(data)->onConfigure(s, serial, w, h);
}
void layerClosed(void* data, zwlr_layer_surface_v1*) { static_cast<Wayland*>(data)->onClosed(); }
const zwlr_layer_surface_v1_listener kLayerListener = {layerConfigure, layerClosed};

void preferredScale(void* data, wp_fractional_scale_v1*, uint32_t s) { static_cast<Wayland*>(data)->onScale(s); }
const wp_fractional_scale_v1_listener kScaleListener = {preferredScale};

double nowMs() {
    timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1000.0 + ts.tv_nsec / 1e6;
}

} // namespace

bool Wayland::connect() {
    display_ = wl_display_connect(nullptr);
    if (!display_) {
        std::fprintf(stderr, "nameraka view: no hay conexión Wayland\n");
        return false;
    }
    registry_ = wl_display_get_registry(display_);
    wl_registry_add_listener(registry_, &kRegistryListener, this);
    wl_display_roundtrip(display_);
    wl_display_roundtrip(display_);   // output events
    if (!compositor || !layerShell || !viewporter) {
        std::fprintf(stderr, "nameraka view: falta wl_compositor, wlr-layer-shell o viewporter\n");
        return false;
    }
    return true;
}

void Wayland::disconnect() {
    destroySurface();
    for (auto* o : outputs) {
        wl_output_destroy(o->wl);
        delete o;
    }
    outputs.clear();
    if (fractional) wp_fractional_scale_manager_v1_destroy(fractional);
    if (viewporter) wp_viewporter_destroy(viewporter);
    if (layerShell) zwlr_layer_shell_v1_destroy(layerShell);
    if (compositor) wl_compositor_destroy(compositor);
    if (registry_) wl_registry_destroy(registry_);
    if (display_) wl_display_disconnect(display_);
    fractional = nullptr;
    viewporter = nullptr;
    layerShell = nullptr;
    compositor = nullptr;
    registry_ = nullptr;
    display_ = nullptr;
}

bool Wayland::createSurface(const std::string& connector) {
    out_ = nullptr;
    for (auto* o : outputs)
        if (connector.empty() || o->connector == connector) {
            out_ = o;
            break;
        }
    if (!out_) {
        std::fprintf(stderr, "nameraka view: no existe la salida «%s»\n", connector.c_str());
        return false;
    }
    configured_ = closed_ = false;
    surface_ = wl_compositor_create_surface(compositor);
    // empty input region: every pointer, touch and keyboard event goes to the window below
    wl_region* empty = wl_compositor_create_region(compositor);
    wl_surface_set_input_region(surface_, empty);
    wl_region_destroy(empty);
    viewport_ = wp_viewporter_get_viewport(viewporter, surface_);
    if (fractional) {
        fscale_ = wp_fractional_scale_manager_v1_get_fractional_scale(fractional, surface_);
        wp_fractional_scale_v1_add_listener(fscale_, &kScaleListener, this);
    }
    layer_ = zwlr_layer_shell_v1_get_layer_surface(layerShell, surface_, out_->wl, ZWLR_LAYER_SHELL_V1_LAYER_OVERLAY,
                                                   "ocarina-nameraka");
    zwlr_layer_surface_v1_add_listener(layer_, &kLayerListener, this);
    zwlr_layer_surface_v1_set_anchor(layer_, ZWLR_LAYER_SURFACE_V1_ANCHOR_TOP | ZWLR_LAYER_SURFACE_V1_ANCHOR_BOTTOM
                                                 | ZWLR_LAYER_SURFACE_V1_ANCHOR_LEFT | ZWLR_LAYER_SURFACE_V1_ANCHOR_RIGHT);
    zwlr_layer_surface_v1_set_size(layer_, 0, 0);
    zwlr_layer_surface_v1_set_exclusive_zone(layer_, -1);
    zwlr_layer_surface_v1_set_keyboard_interactivity(layer_, ZWLR_LAYER_SURFACE_V1_KEYBOARD_INTERACTIVITY_NONE);
    wl_surface_commit(surface_);
    return true;
}

void Wayland::destroySurface() {
    if (layer_) zwlr_layer_surface_v1_destroy(layer_);
    if (fscale_) wp_fractional_scale_v1_destroy(fscale_);
    if (viewport_) wp_viewport_destroy(viewport_);
    if (surface_) wl_surface_destroy(surface_);
    layer_ = nullptr;
    fscale_ = nullptr;
    viewport_ = nullptr;
    surface_ = nullptr;
    configured_ = false;
    if (display_)
        wl_display_flush(display_);
}

void Wayland::computeBuffer() {
    // the physical mode of the output (rotated if needed); fall back to logical × preferred scale
    int w = out_ ? out_->modeW : 0, h = out_ ? out_->modeH : 0;
    if (out_ && (out_->transform & 1))
        std::swap(w, h);
    if (w <= 0 || h <= 0) {
        w = static_cast<int>(logicalW_ * scale() + 0.5);
        h = static_cast<int>(logicalH_ * scale() + 0.5);
    }
    bufferW_ = w;
    bufferH_ = h;
}

void Wayland::onConfigure(zwlr_layer_surface_v1* s, uint32_t serial, uint32_t w, uint32_t h) {
    zwlr_layer_surface_v1_ack_configure(s, serial);
    logicalW_ = static_cast<int>(w);
    logicalH_ = static_cast<int>(h);
    computeBuffer();
    if (viewport_ && w > 0 && h > 0)
        wp_viewport_set_destination(viewport_, static_cast<int>(w), static_cast<int>(h));
    configured_ = true;
}

bool Wayland::waitConfigured(int timeoutMs) {
    double end = nowMs() + timeoutMs;
    while (!configured_ && !closed_ && nowMs() < end) {
        if (wl_display_roundtrip(display_) < 0)
            return false;
    }
    return configured_ && !closed_;
}

int Wayland::fd() const { return display_ ? wl_display_get_fd(display_) : -1; }

bool Wayland::dispatchPending() {
    if (!display_)
        return false;
    while (wl_display_prepare_read(display_) != 0)
        if (wl_display_dispatch_pending(display_) < 0)
            return false;
    if (wl_display_flush(display_) < 0 && errno != EAGAIN) {
        wl_display_cancel_read(display_);
        return false;
    }
    pollfd p{wl_display_get_fd(display_), POLLIN, 0};
    if (poll(&p, 1, 0) > 0 && (p.revents & POLLIN)) {
        if (wl_display_read_events(display_) < 0)
            return false;
    } else {
        wl_display_cancel_read(display_);
    }
    return wl_display_dispatch_pending(display_) >= 0;
}

void Wayland::flush() {
    if (display_)
        wl_display_flush(display_);
}

} // namespace nk
