#include "daemon/niri.hpp"

#include <cerrno>
#include <cmath>
#include <cstdlib>
#include <cstring>
#include <fcntl.h>
#include <poll.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

namespace nk {

namespace {

int dial() {
    const char* path = std::getenv("NIRI_SOCKET");
    if (!path || !*path)
        return -1;
    int fd = ::socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
    if (fd < 0)
        return -1;
    sockaddr_un a{};
    a.sun_family = AF_UNIX;
    std::strncpy(a.sun_path, path, sizeof a.sun_path - 1);
    if (::connect(fd, reinterpret_cast<sockaddr*>(&a), sizeof a) < 0) {
        ::close(fd);
        return -1;
    }
    return fd;
}

bool sendLine(int fd, const std::string& s) {
    std::string line = s + "\n";
    size_t off = 0;
    while (off < line.size()) {
        ssize_t n = ::write(fd, line.data() + off, line.size() - off);
        if (n <= 0)
            return false;
        off += static_cast<size_t>(n);
    }
    return true;
}

// read one line with a timeout (request connections)
std::optional<std::string> readLine(int fd, int timeoutMs) {
    std::string out;
    char c[4096];
    while (true) {
        size_t nl = out.find('\n');
        if (nl != std::string::npos)
            return out.substr(0, nl);
        pollfd p{fd, POLLIN, 0};
        if (poll(&p, 1, timeoutMs) <= 0)
            return std::nullopt;
        ssize_t n = ::read(fd, c, sizeof c);
        if (n <= 0)
            return std::nullopt;
        out.append(c, static_cast<size_t>(n));
    }
}

} // namespace

std::optional<Json> Niri::request(const std::string& req) const {
    int fd = dial();
    if (fd < 0)
        return std::nullopt;
    std::optional<Json> r;
    if (sendLine(fd, req))
        if (auto line = readLine(fd, 1000))
            r = Json::parse(*line);
    ::close(fd);
    if (!r || !r->has("Ok"))
        return std::nullopt;
    return (*r)["Ok"];
}

bool Niri::connect() {
    fd_ = dial();
    if (fd_ < 0)
        return false;
    if (!sendLine(fd_, "\"EventStream\"")) {
        close();
        return false;
    }
    ::fcntl(fd_, F_SETFL, ::fcntl(fd_, F_GETFL) | O_NONBLOCK);
    refreshOutputs();
    return true;
}

void Niri::close() {
    if (fd_ >= 0)
        ::close(fd_);
    fd_ = -1;
    buf_.clear();
}

bool Niri::refreshOutputs() {
    auto r = request("\"Outputs\"");
    if (!r)
        return false;
    outputs.clear();
    for (const auto& [name, o] : (*r)["Outputs"].object()) {
        NiriOutput out;
        out.name = name;
        out.logicalW = static_cast<int>(o["logical"]["width"].asInt());
        out.logicalH = static_cast<int>(o["logical"]["height"].asInt());
        long long cm = o["current_mode"].asInt(-1);
        const auto& modes = o["modes"].array();
        if (cm >= 0 && cm < static_cast<long long>(modes.size())) {
            out.hz = modes[static_cast<size_t>(cm)]["refresh_rate"].asNumber() / 1000.0;
            out.modeW = static_cast<int>(modes[static_cast<size_t>(cm)]["width"].asInt());
            out.modeH = static_cast<int>(modes[static_cast<size_t>(cm)]["height"].asInt());
        }
        if (out.logicalW > 0)                   // disabled outputs have no logical size
            outputs[name] = out;
    }
    changed = true;
    return true;
}

bool Niri::read() {
    char c[65536];
    while (true) {
        ssize_t n = ::read(fd_, c, sizeof c);
        if (n > 0) {
            buf_.append(c, static_cast<size_t>(n));
            continue;
        }
        if (n == 0)
            return false;
        if (errno == EAGAIN || errno == EWOULDBLOCK)
            break;
        if (errno == EINTR)
            continue;
        return false;
    }
    size_t nl;
    while ((nl = buf_.find('\n')) != std::string::npos) {
        std::string line = buf_.substr(0, nl);
        buf_.erase(0, nl + 1);
        if (auto j = Json::parse(line))
            apply(*j);
    }
    return true;
}

void Niri::setWindow(const Json& w) {
    NiriWindow nw;
    nw.id = static_cast<uint64_t>(w["id"].asInt());
    nw.appId = w["app_id"].str();
    nw.title = w["title"].str();
    nw.pid = static_cast<int>(w["pid"].asInt());
    nw.workspace = static_cast<uint64_t>(w["workspace_id"].asInt());
    nw.focused = w["is_focused"].asBool();
    const auto& size = w["layout"]["window_size"].array();
    if (size.size() == 2) {
        nw.w = size[0].asNumber();
        nw.h = size[1].asNumber();
    }
    const auto& pos = w["layout"]["tile_pos_in_workspace_view"];
    nw.tileAtOrigin = pos.isNull()
        || (pos.array().size() == 2 && std::fabs(pos.array()[0].asNumber()) < 1 && std::fabs(pos.array()[1].asNumber()) < 1);
    windows[nw.id] = nw;
    if (nw.focused) {
        focusedWindow = nw.id;
        lastFocusedWindow = nw.id;
    }
}

void Niri::apply(const Json& ev) {
    if (ev.has("WindowsChanged")) {
        windows.clear();
        focusedWindow.reset();
        for (const auto& w : ev["WindowsChanged"]["windows"].array())
            setWindow(w);
    } else if (ev.has("WindowOpenedOrChanged")) {
        setWindow(ev["WindowOpenedOrChanged"]["window"]);
    } else if (ev.has("WindowClosed")) {
        uint64_t id = static_cast<uint64_t>(ev["WindowClosed"]["id"].asInt());
        windows.erase(id);
        if (focusedWindow == id)
            focusedWindow.reset();
    } else if (ev.has("WindowFocusChanged")) {
        const auto& id = ev["WindowFocusChanged"]["id"];
        for (auto& [k, w] : windows)
            w.focused = false;
        if (id.isNull()) {
            focusedWindow.reset();             // a layer surface (the shell) took the keyboard: not another window
        } else {
            focusedWindow = static_cast<uint64_t>(id.asInt());
            lastFocusedWindow = focusedWindow;
            if (auto it = windows.find(*focusedWindow); it != windows.end())
                it->second.focused = true;
        }
    } else if (ev.has("WindowLayoutsChanged")) {
        for (const auto& ch : ev["WindowLayoutsChanged"]["changes"].array()) {
            const auto& pair = ch.array();
            if (pair.size() != 2)
                continue;
            auto it = windows.find(static_cast<uint64_t>(pair[0].asInt()));
            if (it == windows.end())
                continue;
            const auto& size = pair[1]["window_size"].array();
            if (size.size() == 2) {
                it->second.w = size[0].asNumber();
                it->second.h = size[1].asNumber();
            }
            const auto& pos = pair[1]["tile_pos_in_workspace_view"];
            it->second.tileAtOrigin = pos.isNull()
                || (pos.array().size() == 2 && std::fabs(pos.array()[0].asNumber()) < 1
                    && std::fabs(pos.array()[1].asNumber()) < 1);
        }
    } else if (ev.has("WorkspacesChanged")) {
        workspaces.clear();
        for (const auto& w : ev["WorkspacesChanged"]["workspaces"].array()) {
            NiriWorkspace ws;
            ws.id = static_cast<uint64_t>(w["id"].asInt());
            ws.output = w["output"].str();
            ws.active = w["is_active"].asBool();
            workspaces[ws.id] = ws;
        }
        refreshOutputs();                      // outputs come and go with their workspaces
    } else if (ev.has("WorkspaceActivated")) {
        uint64_t id = static_cast<uint64_t>(ev["WorkspaceActivated"]["id"].asInt());
        auto it = workspaces.find(id);
        if (it != workspaces.end()) {
            for (auto& [k, w] : workspaces)
                if (w.output == it->second.output)
                    w.active = false;
            it->second.active = true;
        }
    } else if (ev.has("OverviewOpenedOrClosed")) {
        overview = ev["OverviewOpenedOrClosed"]["is_open"].asBool();
    } else if (ev.has("ConfigLoaded")) {
        refreshOutputs();                      // Hz or scale may have changed (Displays, Shinobi)
    } else {
        return;
    }
    changed = true;
}

const NiriWindow* Niri::window(uint64_t id) const {
    auto it = windows.find(id);
    return it == windows.end() ? nullptr : &it->second;
}

const NiriOutput* Niri::outputOf(uint64_t windowId) const {
    const NiriWindow* w = window(windowId);
    if (!w)
        return nullptr;
    auto ws = workspaces.find(w->workspace);
    if (ws == workspaces.end())
        return nullptr;
    auto o = outputs.find(ws->second.output);
    return o == outputs.end() ? nullptr : &o->second;
}

bool Niri::workspaceVisible(uint64_t windowId) const {
    const NiriWindow* w = window(windowId);
    if (!w)
        return false;
    auto ws = workspaces.find(w->workspace);
    return ws != workspaces.end() && ws->second.active;
}

bool Niri::fullscreenWindow(uint64_t id, uint64_t) const {
    const NiriWindow* w = window(id);
    const NiriOutput* o = outputOf(id);
    if (!w || !o)
        return false;
    return std::fabs(w->w - o->logicalW) <= 1.01 && std::fabs(w->h - o->logicalH) <= 1.01 && w->tileAtOrigin;
}

} // namespace nk
