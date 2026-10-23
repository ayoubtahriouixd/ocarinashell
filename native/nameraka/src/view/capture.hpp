// PipeWire side of the presenter (docs/01-ARQUITECTURA §19 «Captura sin diálogo y sin copias»): consumes niri's window
// cast node as DMA-BUF only (niri offers nothing else), offering the modifiers Vulkan can copy from (niri fixates one).
// WirePlumber does not link a client stream to niri's unregistered `Stream/Output/Video` node, so the link is created
// here with link-factory once both ports exist. Only the newest frame is kept for the render thread; older ones go
// straight back to niri.
#pragma once

#include <atomic>
#include <condition_variable>
#include <cstdint>
#include <functional>
#include <map>
#include <mutex>
#include <vector>

#include "view/vk.hpp"

struct pw_thread_loop;
struct pw_context;
struct pw_core;
struct pw_stream;
struct pw_buffer;
struct pw_registry;
struct pw_proxy;
struct spa_pod;
struct spa_dict;

namespace nk {

struct Frame {
    pw_buffer* buffer = nullptr;
    double arrival = 0;          // CLOCK_MONOTONIC seconds
    int fd = -1;
    uint32_t offset = 0, stride = 0;
    uint64_t modifier = 0;
    int w = 0, h = 0;
};

class Capture {
public:
    bool start(uint32_t nodeId, const std::vector<uint64_t>& modifiers);
    void stop();
    // render thread: wait up to timeoutMs for a new frame (false on timeout or stop)
    bool next(Frame& out, int timeoutMs);
    // render thread: give the buffer back to niri
    void done(const Frame& f);
    void setActive(bool on);
    bool linked() const { return linked_; }
    bool failed() const { return failed_; }
    int width() const { return w_; }
    int height() const { return h_; }
    // written by the PipeWire thread: a frozen render thread does not stop them (the watchdog compares)
    std::atomic<double> lastArrival{0};    // CLOCK_MONOTONIC seconds of the newest frame
    std::atomic<long> dropped{0};          // frames replaced before the render thread took them

    // called from PipeWire callbacks (pw thread)
    void onParamChanged(uint32_t id, const spa_pod* param);
    void onProcess();
    void onState(int state, const char* error);
    void onGlobal(uint32_t id, const char* type, const spa_dict* props);

private:
    void tryLink();
    pw_thread_loop* loop_ = nullptr;
    pw_context* context_ = nullptr;
    pw_core* core_ = nullptr;
    pw_stream* stream_ = nullptr;
    pw_registry* registry_ = nullptr;
    pw_proxy* link_ = nullptr;
    struct Hooks;
    Hooks* hooks_ = nullptr;
    uint32_t target_ = 0;
    uint32_t ourNode_ = 0;
    uint32_t outPort_ = 0, inPort_ = 0;
    std::map<uint32_t, uint32_t> portNode_;     // port id → node id (output ports of the target, input ports of ours)
    std::vector<uint64_t> modifiers_;
    uint64_t modifier_ = 0;
    int w_ = 0, h_ = 0;
    bool linked_ = false;
    bool failed_ = false;
    bool stopping_ = false;
    std::mutex m_;
    // done() (render thread) against stop() (main thread): stop() takes it before tearing PipeWire down, so a buffer
    // being handed back never meets a destroyed loop or stream (segfaults on every Fluido «off», fase 17). Never taken
    // by the PipeWire thread: the lock order is always doneM_ → loop lock.
    std::mutex doneM_;
    std::condition_variable cv_;
    pw_buffer* pending_ = nullptr;
    double pendingArrival_ = 0;
};

} // namespace nk
