// niri IPC for the daemon: one long-lived connection on the event stream (windows, workspaces, focus, overview) and
// short request connections (Outputs). The model answers what the state machine needs about the target window.
// niri 26.04 has no `is_fullscreen`: a window is full screen when layout.window_size equals its output's logical size
// ±1 px (1646×1029 against 1645×1028 at scale 1,75) and, if present, tile_pos_in_workspace_view is (0, 0).
#pragma once

#include <cstdint>
#include <map>
#include <optional>
#include <string>

#include "common/json.hpp"

namespace nk {

struct NiriWindow {
    uint64_t id = 0;
    std::string appId, title;
    int pid = 0;
    uint64_t workspace = 0;
    bool focused = false;
    double w = 0, h = 0;                 // layout.window_size (logical)
    bool tileAtOrigin = true;            // tile_pos_in_workspace_view null or (0, 0)
};

struct NiriWorkspace {
    uint64_t id = 0;
    std::string output;
    bool active = false;
};

struct NiriOutput {
    std::string name;
    int logicalW = 0, logicalH = 0;
    double hz = 0;
    int modeW = 0, modeH = 0;
};

class Niri {
public:
    bool connect();                      // event stream; false if NIRI_SOCKET is missing or refuses
    void close();
    int fd() const { return fd_; }
    // read what is available and apply it; false when the stream died
    bool read();
    bool refreshOutputs();               // request Outputs (blocking, ~1 ms)
    std::optional<Json> request(const std::string& req) const;
    bool fullscreenWindow(uint64_t id, uint64_t workspace = 0) const;

    std::map<uint64_t, NiriWindow> windows;
    std::map<uint64_t, NiriWorkspace> workspaces;
    std::map<std::string, NiriOutput> outputs;
    std::optional<uint64_t> focusedWindow;    // a window, or none (focus on a layer surface: the shell)
    std::optional<uint64_t> lastFocusedWindow;
    bool overview = false;
    bool changed = false;                // something the state machine cares about changed since the last look

    const NiriWindow* window(uint64_t id) const;
    const NiriOutput* outputOf(uint64_t windowId) const;
    bool workspaceVisible(uint64_t windowId) const;

private:
    void apply(const Json& ev);
    void setWindow(const Json& w);
    int fd_ = -1;
    std::string buf_;
};

} // namespace nk
