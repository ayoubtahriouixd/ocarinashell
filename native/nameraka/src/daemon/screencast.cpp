#include "daemon/screencast.hpp"

#include <cstdio>
#include <fstream>
#include <systemd/sd-bus.h>
#include <unistd.h>

namespace nk {

namespace {
constexpr const char* kName = "org.gnome.Mutter.ScreenCast";
constexpr const char* kPath = "/org/gnome/Mutter/ScreenCast";

int onAdded(sd_bus_message* m, void* data, sd_bus_error*) {
    uint32_t node = 0;
    if (sd_bus_message_read(m, "u", &node) >= 0)
        static_cast<ScreenCast*>(data)->onStreamAdded(node);
    return 0;
}
int onClosedSig(sd_bus_message*, void* data, sd_bus_error*) {
    static_cast<ScreenCast*>(data)->onClosed();
    return 0;
}
void stopPath(sd_bus* bus, const std::string& path) {
    sd_bus_error e = SD_BUS_ERROR_NULL;
    sd_bus_call_method(bus, kName, path.c_str(), "org.gnome.Mutter.ScreenCast.Session", "Stop", &e, nullptr, "");
    sd_bus_error_free(&e);
}
} // namespace

bool ScreenCast::open() {
    if (sd_bus_open_user(&bus_) < 0)
        return false;
    // a session left by a crashed run (niri keeps it): stop it
    std::ifstream f(stateFile_);
    std::string old;
    if (f && std::getline(f, old) && old.rfind("/org/gnome/Mutter/ScreenCast/Session/", 0) == 0) {
        stopPath(bus_, old);
        std::fprintf(stderr, "nameraka: sesión huérfana %s cerrada\n", old.c_str());
    }
    remember("");
    return true;
}

void ScreenCast::close() {
    stop();
    if (bus_)
        sd_bus_flush_close_unref(bus_);
    bus_ = nullptr;
}

int ScreenCast::fd() const { return bus_ ? sd_bus_get_fd(bus_) : -1; }
int ScreenCast::events() const { return bus_ ? sd_bus_get_events(bus_) : 0; }
uint64_t ScreenCast::timeoutUs() const {
    uint64_t t = UINT64_MAX;
    if (bus_)
        sd_bus_get_timeout(bus_, &t);
    return t;
}

void ScreenCast::process() {
    if (!bus_)
        return;
    while (sd_bus_process(bus_, nullptr) > 0) {
    }
}

bool ScreenCast::available() const {
    if (!bus_)
        return false;
    sd_bus_error e = SD_BUS_ERROR_NULL;
    int32_t v = 0;
    int r = sd_bus_get_property_trivial(bus_, kName, kPath, kName, "Version", &e, 'i', &v);
    sd_bus_error_free(&e);
    return r >= 0 && v >= 4;
}

void ScreenCast::remember(const std::string& path) {
    std::ofstream f(stateFile_, std::ios::trunc);
    f << path << "\n";
}

bool ScreenCast::start(uint64_t windowId) {
    stop();
    node_ = 0;
    closed_ = false;
    sd_bus_error e = SD_BUS_ERROR_NULL;
    sd_bus_message* reply = nullptr;
    const char* path = nullptr;
    // CreateSession({})
    int r = sd_bus_call_method(bus_, kName, kPath, kName, "CreateSession", &e, &reply, "a{sv}", 0);
    if (r < 0 || sd_bus_message_read(reply, "o", &path) < 0) {
        std::fprintf(stderr, "nameraka: CreateSession: %s\n", e.message ? e.message : "?");
        sd_bus_error_free(&e);
        sd_bus_message_unref(reply);
        return false;
    }
    session_ = path;
    sd_bus_message_unref(reply);
    reply = nullptr;
    remember(session_);
    sd_bus_match_signal(bus_, &slotClosed_, kName, session_.c_str(), "org.gnome.Mutter.ScreenCast.Session", "Closed",
                        onClosedSig, this);
    // RecordWindow({"window-id": <t>, "cursor-mode": <u 0>}) — the cursor stays niri's, drawn above the overlay
    r = sd_bus_call_method(bus_, kName, session_.c_str(), "org.gnome.Mutter.ScreenCast.Session", "RecordWindow", &e,
                           &reply, "a{sv}", 2, "window-id", "t", windowId, "cursor-mode", "u", 0u);
    if (r < 0 || sd_bus_message_read(reply, "o", &path) < 0) {
        std::fprintf(stderr, "nameraka: RecordWindow(%llu): %s\n", static_cast<unsigned long long>(windowId),
                     e.message ? e.message : "?");
        sd_bus_error_free(&e);
        sd_bus_message_unref(reply);
        stop();
        return false;
    }
    stream_ = path;
    sd_bus_message_unref(reply);
    sd_bus_match_signal(bus_, &slotAdded_, kName, stream_.c_str(), "org.gnome.Mutter.ScreenCast.Stream",
                        "PipeWireStreamAdded", onAdded, this);
    r = sd_bus_call_method(bus_, kName, session_.c_str(), "org.gnome.Mutter.ScreenCast.Session", "Start", &e, nullptr, "");
    if (r < 0) {
        std::fprintf(stderr, "nameraka: Start: %s\n", e.message ? e.message : "?");
        sd_bus_error_free(&e);
        stop();
        return false;
    }
    return true;
}

void ScreenCast::stop() {
    if (slotAdded_)
        sd_bus_slot_unref(slotAdded_);
    if (slotClosed_)
        sd_bus_slot_unref(slotClosed_);
    slotAdded_ = slotClosed_ = nullptr;
    if (!session_.empty() && bus_) {
        stopPath(bus_, session_);
        remember("");
    }
    session_.clear();
    stream_.clear();
    node_ = 0;
}

} // namespace nk
