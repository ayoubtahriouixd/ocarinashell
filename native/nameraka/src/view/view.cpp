// `nameraka view` — the presenter (docs/01-ARQUITECTURA §19): capture (PipeWire DMA-BUF) → copy → FIFO present on the
// overlay surface, where lsfg-vk inserts the generated frames. A child of the daemon:
//   stdin  (lines): show · hide · quit         (hide: no surface, capture and Vulkan kept → back in < 150 ms)
//   stdout (JSON lines): {"ev":"capturing"} (first frame, even hidden) · {"ev":"ready"} (first present) ·
//          {"ev":"hb",…} every 250 ms · {"ev":"stats",…} 1/s · {"ev":"hidden"} · {"ev":"error",…}
// The daemon's watchdog kills it when the heartbeat stops (a frozen process) or when frames keep arriving but nothing
// is presented for 1 s while it should be showing (a hung GPU / FIFO). A paused video presents nothing and is fine.
// Test mode for milestone a: `nameraka view --pattern [--fps 30] [--output eDP-1]`.
#include "view/view.hpp"

#include <atomic>
#include <chrono>
#include <csignal>
#include <cstdio>
#include <cstring>
#include <map>
#include <mutex>
#include <poll.h>
#include <string>
#include <thread>
#include <unistd.h>

#include "common/json.hpp"
#include "core/base_estimator.hpp"
#include "view/capture.hpp"
#include "view/vk.hpp"
#include "view/wayland.hpp"

namespace nk {

namespace {

std::atomic<bool> gQuit{false};

double monoMs();
double now() { return monoMs(); }
double monoMs() {
    return std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now().time_since_epoch()).count();
}

void emit(const Json& j) {
    std::string s = j.dump() + "\n";
    ssize_t w = ::write(STDOUT_FILENO, s.data(), s.size());
    (void)w;
}

struct Presenter {
    Wayland wl;
    Vk vk;
    Capture cap;
    bool pattern = false;
    double patternFps = 30;
    std::string output;
    uint32_t node = 0;

    std::mutex gpu;                       // the render thread holds it while it uses the swapchain
    std::atomic<bool> visible{false};
    std::atomic<bool> recreate{false};
    std::atomic<double> lastPresent{0};
    std::atomic<long> presented{0};
    std::atomic<long> frames{0};
    std::atomic<bool> readySent{false};
    std::atomic<double> showAt{0};
    double hiddenAt = 0;
    bool capturePaused = false;         // when `show` was asked: the next present reports how long it took
    std::mutex statsM;
    BaseEstimator base;
    double gpuMs = 0;
    std::map<pw_buffer*, Imported> cache;  // imported once per niri buffer
    int cacheW = 0, cacheH = 0;

    bool show() {
        showAt = monoMs();
        std::lock_guard l(gpu);
        if (visible)
            return true;
        if (!wl.createSurface(output) || !wl.waitConfigured(1000)) {
            wl.destroySurface();
            return false;
        }
        if (!vk.createSwapchain(wl.surface(), wl.bufferW(), wl.bufferH())) {
            vk.destroySwapchain();
            wl.destroySurface();
            return false;
        }
        std::fprintf(stderr, "nameraka view: superficie %dx%d lógicos, búfer %dx%d, escala %.3f\n", wl.logicalW(),
                     wl.logicalH(), wl.bufferW(), wl.bufferH(), wl.scale());
        visible = true;
        lastPresent = monoMs();
        return true;
    }
    void hide() {
        std::lock_guard l(gpu);
        if (!visible)
            return;
        visible = false;
        hiddenAt = monoMs();
        vk.destroySwapchain();
        wl.destroySurface();
        emit(Json().set("ev", "hidden"));
    }
    void markPresented() {
        double now = monoMs();
        lastPresent = now;
        ++presented;
        if (!readySent.exchange(true))
            emit(Json().set("ev", "ready"));
        if (double s = showAt.exchange(0); s > 0)
            emit(Json().set("ev", "shown").set("ms", now - s));
    }
    void renderPattern() {
        auto period = std::chrono::duration<double>(1.0 / patternFps);
        auto next = std::chrono::steady_clock::now();
        int t = 0;
        while (!gQuit) {
            next += std::chrono::duration_cast<std::chrono::steady_clock::duration>(period);
            std::this_thread::sleep_until(next);
            {
                std::lock_guard s(statsM);
                base.push(monoMs() / 1000.0);
            }
            ++frames;
            std::lock_guard l(gpu);
            if (!visible)
                continue;
            auto r = vk.presentPattern(t += 8);
            if (r == Vk::Result::Error) {
                emit(Json().set("ev", "error").set("msg", "present"));
                gQuit = true;
            } else if (r == Vk::Result::Recreate) {
                recreate = true;
            } else {
                gpuMs = vk.lastGpuMs();
                markPresented();
            }
        }
    }
    void renderCapture() {
        Frame f;
        while (!gQuit) {
            if (!cap.next(f, 200)) {
                if (cap.failed()) {
                    emit(Json().set("ev", "error").set("msg", "pipewire"));
                    gQuit = true;
                }
                continue;
            }
            {
                std::lock_guard s(statsM);
                base.push(f.arrival);
            }
            if (++frames == 1)
                emit(Json().set("ev", "capturing").set("w", f.w).set("h", f.h));
            {
                std::lock_guard l(gpu);
                if (f.w != cacheW || f.h != cacheH) {        // renegotiated: buffers are new
                    for (auto& [b, img] : cache)
                        vk.release(img);
                    cache.clear();
                    cacheW = f.w;
                    cacheH = f.h;
                }
                if (visible) {
                    auto it = cache.find(f.buffer);
                    if (it == cache.end()) {
                        Imported img;
                        if (vk.import(f.fd, f.offset, f.stride, f.modifier, f.w, f.h, img))
                            it = cache.emplace(f.buffer, img).first;
                    }
                    if (it != cache.end()) {
                        auto r = vk.presentImage(it->second);
                        if (r == Vk::Result::Recreate)
                            recreate = true;
                        else if (r == Vk::Result::Ok) {
                            gpuMs = vk.lastGpuMs();
                            markPresented();
                        }
                    }
                }
            }
            cap.done(f);
        }
    }
    Json stats() {
        std::lock_guard s(statsM);
        return Json()
            .set("ev", "stats")
            .set("visible", visible.load())
            .set("base", base.base())
            .set("raw", base.raw())
            .set("frames", frames.load())
            .set("presented", presented.load())
            .set("lastPresentMs", monoMs() - lastPresent.load())
            .set("gpuMs", gpuMs)
            .set("dropped", pattern ? 0L : cap.dropped.load())
            .set("w", pattern ? wl.bufferW() : cap.width())
            .set("h", pattern ? wl.bufferH() : cap.height());
    }
};

} // namespace

int runView(int argc, char** argv) {
    Presenter p;
    bool startVisible = true;
    for (int i = 0; i < argc; ++i) {
        std::string a = argv[i];
        if (a == "--pattern") p.pattern = true;
        else if (a == "--fps" && i + 1 < argc) p.patternFps = std::atof(argv[++i]);
        else if (a == "--output" && i + 1 < argc) p.output = argv[++i];
        else if (a == "--node" && i + 1 < argc) p.node = static_cast<uint32_t>(std::strtoul(argv[++i], nullptr, 10));
        else if (a == "--hidden") startVisible = false;
    }
    if (!p.pattern && !p.node) {
        std::fprintf(stderr, "uso: nameraka view --pattern [--fps N] | --node <id de PipeWire> [--output eDP-1] [--hidden]\n");
        return 2;
    }
    std::signal(SIGTERM, [](int) { gQuit = true; });
    std::signal(SIGINT, [](int) { gQuit = true; });
    std::signal(SIGPIPE, SIG_IGN);
    if (!p.wl.connect() || !p.vk.init(p.wl.display()))
        return 12;
    if (!p.pattern && !p.cap.start(p.node, p.vk.modifiers()))
        return 12;
    if (startVisible && !p.show())
        return 11;
    std::thread render([&] { p.pattern ? p.renderPattern() : p.renderCapture(); });

    double lastStats = 0, lastHb = 0;
    std::string line;
    while (!gQuit) {
        // only stdin wakes this loop (the Wayland fd is shared with Mesa's WSI and would wake it per frame); Wayland
        // events are read without blocking every turn, at least every 250 ms (the heartbeat period)
        pollfd fds[2] = {{-1, 0, 0}, {STDIN_FILENO, POLLIN, 0}};
        p.wl.flush();
        poll(fds, 2, 250);
        if (!p.wl.dispatchPending()) {
            emit(Json().set("ev", "error").set("msg", "wayland"));
            break;
        }
        if (p.wl.closed()) {                 // niri closed the layer surface (output gone)
            p.hide();
            emit(Json().set("ev", "error").set("msg", "closed"));
            break;
        }
        if (fds[1].revents & (POLLIN | POLLHUP)) {
            char buf[256];
            ssize_t n = ::read(STDIN_FILENO, buf, sizeof buf);
            if (n <= 0) {
                if (n == 0 && !isatty(STDIN_FILENO))
                    break;                   // the daemon went away
            } else {
                line.append(buf, static_cast<size_t>(n));
                size_t nl;
                while ((nl = line.find('\n')) != std::string::npos) {
                    std::string cmd = line.substr(0, nl);
                    line.erase(0, nl + 1);
                    if (cmd == "show") {
                        if (!p.show())
                            emit(Json().set("ev", "error").set("msg", "surface"));
                    } else if (cmd == "hide") {
                        p.hide();
                    } else if (cmd == "quit") {
                        p.hide();            // the overlay goes first: the app is back before the capture is torn down
                        p.wl.flush();
                        gQuit = true;
                    }
                }
            }
        }
        // hidden for more than 5 s (another workspace, lock, screen off): niri stops rendering the cast; Vulkan and
        // lsfg-vk stay loaded, so showing again is still fast
        if (!p.pattern) {
            bool idle = !p.visible && now() - p.hiddenAt > 5000;
            if (idle != p.capturePaused) {
                p.capturePaused = idle;
                p.cap.setActive(!idle);
            }
        }
        if (p.recreate.exchange(false) && p.visible) {   // resized / out of date: rebuild the surface
            p.hide();
            p.show();
        }
        double now = monoMs();
        if (now - lastHb >= 250) {
            lastHb = now;
            double arrival = p.pattern ? now / 1000.0 : p.cap.lastArrival.load();
            emit(Json()
                     .set("ev", "hb")
                     .set("visible", p.visible.load())
                     .set("lastPresentMs", now - p.lastPresent.load())
                     .set("lastFrameMs", arrival > 0 ? now - arrival * 1000.0 : -1.0));
        }
        if (now - lastStats >= 1000) {
            lastStats = now;
            emit(p.stats());
        }
    }
    gQuit = true;
    p.hide();
    if (!p.pattern)
        p.cap.stop();
    render.join();
    p.hide();
    {
        std::lock_guard l(p.gpu);
        for (auto& [b, img] : p.cache)
            p.vk.release(img);
        p.cache.clear();
    }
    p.vk.shutdown();
    p.wl.disconnect();
    return 0;
}

} // namespace nk
