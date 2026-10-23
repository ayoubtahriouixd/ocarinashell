// niri's org.gnome.Mutter.ScreenCast (version 4) over ONE sd-bus connection: CreateSession → RecordWindow(window-id t,
// cursor-mode u 0) → Start → Stream.PipeWireStreamAdded(node). niri does not track the client: a session left behind by
// a crash stays alive (inactive), so the session path is written to a file and stopped at the next start-up.
#pragma once

#include <cstdint>
#include <string>

struct sd_bus;
struct sd_bus_slot;
struct sd_bus_message;

namespace nk {

class ScreenCast {
public:
    explicit ScreenCast(std::string stateFile) : stateFile_(std::move(stateFile)) {}
    bool open();                          // user bus; stops an orphan session recorded by a previous run
    void close();
    int fd() const;
    int events() const;
    uint64_t timeoutUs() const;
    void process();                       // dispatch pending bus traffic (signals)
    bool available() const;               // the API exists (version ≥ 4)

    bool start(uint64_t windowId);        // false if niri refused (window gone)
    void stop();
    bool running() const { return !session_.empty(); }
    uint32_t node() const { return node_; }    // 0 until PipeWireStreamAdded
    bool closedByNiri() const { return closed_; }

    // signal handlers
    void onStreamAdded(uint32_t node) { node_ = node; }
    void onClosed() { closed_ = true; }

private:
    void remember(const std::string& path);
    sd_bus* bus_ = nullptr;
    sd_bus_slot* slotAdded_ = nullptr;
    sd_bus_slot* slotClosed_ = nullptr;
    std::string session_, stream_;
    uint32_t node_ = 0;
    bool closed_ = false;
    std::string stateFile_;
};

} // namespace nk
