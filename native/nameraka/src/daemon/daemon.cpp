// `nameraka daemon` (docs/01-ARQUITECTURA §19): socket-activated by ocarina-nameraka.socket
// ($XDG_RUNTIME_DIR/ocarinashell/nameraka.sock; it binds the socket itself when run by hand). One poll loop over the
// listening socket, its clients, niri's event stream, the session bus (ScreenCast) and the presenter child.
// Protocol: JSON lines. Commands: start {window?, mode, fps, flow?, perf?, battery?, exclude?} · set {…} ·
// pause {reason} · resume {reason} · fullscreen · stop · status · stats {on} · calibrate. Events: state {…} ·
// stats {…} (1/s, only to clients that asked) · error {code, msg}.
#include <algorithm>
#include <cerrno>
#include <chrono>
#include <cmath>
#include <csignal>
#include <cstdio>
#include <cstring>
#include <fcntl.h>
#include <map>
#include <memory>
#include <poll.h>
#include <set>
#include <spawn.h>
#include <string>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/wait.h>
#include <systemd/sd-daemon.h>
#include <unistd.h>
#include <vector>

#include "common/json.hpp"
#include "common/paths.hpp"
#include "core/lsfg_toml.hpp"
#include "core/multiplier.hpp"
#include "core/state_machine.hpp"
#include "daemon/audio.hpp"
#include "daemon/calibration.hpp"
#include "daemon/niri.hpp"
#include "daemon/screencast.hpp"

extern char** environ;

namespace nk {

namespace {

volatile sig_atomic_t gQuit = 0;

double nowMs() {
    return std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now().time_since_epoch()).count();
}

struct Client {
    int fd = -1;
    std::string in;
    bool stats = false;
};

// the presenter child: `nameraka view --node N --output O --hidden`, stdin = commands, stdout = events
struct Child {
    pid_t pid = -1;
    int in = -1, out = -1;
    std::string buf;
    bool capturing = false, visible = false, wantVisible = false;
    double lastHb = 0, lastPresentMs = 0, lastFrameMs = -1, spawnedAt = 0, shownAt = 0;
    Json stats;

    bool alive() const { return pid > 0; }
    void send(const char* cmd) {
        if (in < 0)
            return;
        std::string s = std::string(cmd) + "\n";
        ssize_t w = ::write(in, s.data(), s.size());
        (void)w;
    }
};

class Daemon {
public:
    int run(int argc, char** argv);

private:
    bool listen();
    void accept();
    void readClient(Client& c);
    void command(Client& c, const Json& j);
    void broadcast(const Json& j, bool statsOnly = false);
    void reply(Client& c, const Json& j);
    Json stateJson();
    void evaluate();
    void apply(State from, State to);
    bool spawnView();
    void killView(bool hard);
    void readChild();
    void reapChild();
    void watchdog();
    void writeToml(bool force = false);
    void stopAll(const char* reason);
    void audioTick();
    void guardTick();
    void setReason(std::string r) { reason_ = std::move(r); }
    bool excluded(const NiriWindow& w) const;

    int listenFd_ = -1;
    bool ownSocket_ = false;
    std::vector<std::unique_ptr<Client>> clients_;
    Niri niri_;
    std::unique_ptr<ScreenCast> cast_;
    Child child_;
    Machine machine_;
    Inputs in_;
    std::string reason_;
    std::string stateDir_, tomlPath_;
    Calibration calib_;
    // request
    bool wanted_ = false;
    uint64_t target_ = 0;
    std::string targetApp_, outputName_;
    int chosen_ = 0;            // 2/4/6, 0 = A medida
    double fps_ = 0;            // A medida target (0 = Hz)
    double flow_ = -1;          // < 0: from calibration
    int perf_ = -1;             // < 0: from calibration
    bool eco_ = false;          // battery: eco
    std::set<std::string> exclude_;
    bool fullscreenedByUs_ = false;
    bool avSync_ = false;
    AudioDelay audio_;
    double pausedSince_ = 0;
    int owner_ = -1;
    // guards (§19): one step down at a time, never back up by itself until the mode changes
    int degrade_ = 0;           // 0 none · 1 flow −0,15 · 2 flow −0,30 · 3 + performance mode · 4 pass-through
    int gpuHot_ = 0, cpuHot_ = 0, lateSecs_ = 0;
    std::vector<long> gpuSamples_;
    long lastDropped_ = 0, lastFrames_ = 0;
    std::string gpuBusyPath_, tctlPath_;
    // effective
    Effective eff_;
    double base_ = 0, hz_ = 0;
    LsfgParams written_{};
    bool tomlWritten_ = false;
    double offSince_ = 0;
    double lastStatsSent_ = 0;
    std::string dll_;
};

bool Daemon::listen() {
    int n = sd_listen_fds(1);
    if (n >= 1) {
        listenFd_ = SD_LISTEN_FDS_START;
        ::fcntl(listenFd_, F_SETFL, ::fcntl(listenFd_, F_GETFL) | O_NONBLOCK);
        return true;
    }
    std::string path = runtimeSocket();
    listenFd_ = ::socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC | SOCK_NONBLOCK, 0);
    sockaddr_un a{};
    a.sun_family = AF_UNIX;
    std::strncpy(a.sun_path, path.c_str(), sizeof a.sun_path - 1);
    // never steal a live socket (systemd's, or another daemon's): only a stale file is replaced
    int probe = ::socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
    if (::connect(probe, reinterpret_cast<sockaddr*>(&a), sizeof a) == 0) {
        ::close(probe);
        std::fprintf(stderr, "nameraka: %s ya está en uso (ocarina-nameraka.socket u otro daemon)\n", path.c_str());
        return false;
    }
    ::close(probe);
    ::unlink(path.c_str());
    if (::bind(listenFd_, reinterpret_cast<sockaddr*>(&a), sizeof a) < 0 || ::listen(listenFd_, 8) < 0) {
        std::fprintf(stderr, "nameraka: no puedo escuchar en %s: %s\n", path.c_str(), std::strerror(errno));
        return false;
    }
    ownSocket_ = true;
    return true;
}

void Daemon::accept() {
    while (true) {
        int fd = ::accept4(listenFd_, nullptr, nullptr, SOCK_CLOEXEC | SOCK_NONBLOCK);
        if (fd < 0)
            return;
        auto c = std::make_unique<Client>();
        c->fd = fd;
        clients_.push_back(std::move(c));
    }
}

void Daemon::reply(Client& c, const Json& j) {
    std::string s = j.dump() + "\n";
    if (::send(c.fd, s.data(), s.size(), MSG_NOSIGNAL | MSG_DONTWAIT) < 0 && errno != EAGAIN) {
        ::close(c.fd);
        c.fd = -1;
    }
}

void Daemon::broadcast(const Json& j, bool statsOnly) {
    for (auto& c : clients_)
        if (c->fd >= 0 && (!statsOnly || c->stats))
            reply(*c, j);
}

void Daemon::readClient(Client& c) {
    char buf[4096];
    while (true) {
        ssize_t n = ::recv(c.fd, buf, sizeof buf, MSG_DONTWAIT);
        if (n > 0) {
            c.in.append(buf, static_cast<size_t>(n));
            if (c.in.size() > 65536) {        // nobody sends that much: drop the client
                ::close(c.fd);
                c.fd = -1;
                return;
            }
            continue;
        }
        if (n == 0 || (errno != EAGAIN && errno != EINTR)) {
            if (c.fd == owner_ && wanted_) {
                owner_ = -1;
                stopAll("la shell se fue");  // a client that started Fluido and vanished never leaves it running
            }
            ::close(c.fd);
            c.fd = -1;
            return;
        }
        break;
    }
    size_t nl;
    while (c.fd >= 0 && (nl = c.in.find('\n')) != std::string::npos) {
        std::string line = c.in.substr(0, nl);
        c.in.erase(0, nl + 1);
        auto j = Json::parse(line);
        if (!j || !(*j)["cmd"].isString()) {
            reply(c, Json().set("ev", "error").set("code", 2).set("msg", "orden no válida"));
            continue;
        }
        command(c, *j);
    }
}

bool Daemon::excluded(const NiriWindow& w) const {
    if (w.appId == "gamescope" || w.appId.rfind("steam_app_", 0) == 0 || w.appId == "org.quickshell")
        return true;
    return exclude_.count(w.appId) > 0;
}

void Daemon::command(Client& c, const Json& j) {
    const std::string cmd = j["cmd"].str();
    auto params = [&](const Json& p) {
        if (p.has("mode")) {
            std::string m = p["mode"].str();
            chosen_ = m == "x2" ? 2 : m == "x4" ? 4 : m == "x6" ? 6 : 0;
        }
        if (p.has("fps")) fps_ = std::max(0.0, p["fps"].asNumber());
        if (p.has("flow")) flow_ = p["flow"].isNull() ? -1 : std::clamp(p["flow"].asNumber(), 0.25, 1.0);
        if (p.has("perf")) perf_ = p["perf"].isNull() ? -1 : (p["perf"].asBool() ? 1 : 0);
        if (p.has("battery")) eco_ = p["battery"].str() == "eco";
        if (p.has("avSync")) avSync_ = p["avSync"].asBool();
        if (p.has("mode") || p.has("fps") || p.has("flow") || p.has("perf"))
            degrade_ = 0;                    // a new choice: the guards start again from it
        if (p.has("exclude")) {
            exclude_.clear();
            for (const auto& e : p["exclude"].array())
                exclude_.insert(e.str());
        }
    };
    if (cmd == "start") {
        if (dll_.empty()) {
            reply(c, Json().set("ev", "error").set("code", 14).set("msg", "falta lsfg-vk.dll (Lossless Scaling, rama lsfg-vk)"));
            return;
        }
        params(j);
        uint64_t w = j.has("window") ? static_cast<uint64_t>(j["window"].asInt()) : niri_.lastFocusedWindow.value_or(0);
        const NiriWindow* nw = niri_.window(w);
        // just started by the socket: niri's first window list may not have arrived yet (≤ 1 s)
        for (double until = nowMs() + 1000; !nw && nowMs() < until;) {
            pollfd p{niri_.fd(), POLLIN, 0};
            if (poll(&p, 1, 50) > 0 && !niri_.read())
                break;
            if (!j.has("window"))
                w = niri_.lastFocusedWindow.value_or(0);
            nw = niri_.window(w);
        }
        if (!nw) {
            reply(c, Json().set("ev", "error").set("code", 3).set("msg", "no hay ventana a la que aplicarlo"));
            return;
        }
        if (excluded(*nw)) {
            reply(c, Json().set("ev", "error").set("code", 4).set("msg", "esta ventana está excluida (" + nw->appId + ")"));
            return;
        }
        if (wanted_ && target_ != w)
            stopAll("otra ventana");
        owner_ = c.fd;                       // the client that started it: if it goes away without «stop», we stop
        wanted_ = true;
        target_ = w;
        targetApp_ = nw->appId;
        fullscreenedByUs_ = false;
        setReason("");
        writeToml();
        evaluate();
        reply(c, stateJson());
    } else if (cmd == "set") {
        params(j);
        writeToml();
        broadcast(stateJson());
    } else if (cmd == "stop") {
        stopAll("apagado");                  // broadcasts the «off» state itself (one answer, not two)
        owner_ = -1;
    } else if (cmd == "pause" || cmd == "resume") {
        bool on = cmd == "pause";
        std::string r = j["reason"].str("popup");
        if (r == "lock") in_.locked = on;
        else if (r == "screen") in_.screenOff = on;
        else in_.shellPause = on;
        evaluate();
        reply(c, stateJson());
    } else if (cmd == "fullscreen") {
        // the island's «Pantalla completa» button for players (a toggle: only if it is not full screen yet)
        if (wanted_ && !niri_.fullscreenWindow(target_)) {
            niri_.request(Json().set("Action", Json().set("FullscreenWindow", Json().set("id", static_cast<long long>(target_)))).dump());
            fullscreenedByUs_ = true;
        }
        reply(c, stateJson());
    } else if (cmd == "status") {
        reply(c, stateJson());
    } else if (cmd == "stats") {
        c.stats = j["on"].asBool(true);
        reply(c, stateJson());
    } else if (cmd == "calibrate") {
        if (machine_.state != State::Off) {
            reply(c, Json().set("ev", "error").set("code", 5).set("msg", "apaga Fluido antes de calibrar"));
            return;
        }
        reply(c, Json().set("ev", "calibrating"));
        calib_.run(dll_, niri_);
        reply(c, Json().set("ev", "calibrated").set("ok", calib_.loaded()));
    } else {
        reply(c, Json().set("ev", "error").set("code", 2).set("msg", "orden desconocida: " + cmd));
    }
}

Json Daemon::stateJson() {
    Json j;
    j.set("ev", "state")
        .set("state", std::string(stateName(machine_.state)))
        .set("reason", reason_)
        .set("window", static_cast<long long>(target_))
        .set("app", targetApp_)
        .set("output", outputName_)
        .set("engine", "lsfg")
        .set("mode", chosen_ == 0 ? "custom" : "x" + std::to_string(chosen_))
        .set("fps", fps_)
        .set("hz", hz_)
        .set("base", base_)
        .set("m", eff_.m)
        .set("out", eff_.out)
        .set("perfect", eff_.perfect)
        .set("limited", eff_.limited)
        .set("flow", written_.flowScale)
        .set("perf", written_.performance)
        .set("eco", eco_)
        .set("avSync", avSync_)
        .set("adjusted", degrade_ > 0)
        .set("calibrated", calib_.loaded())
        .set("audioDelayMs", audio_.active() ? audio_.delayMs() : 0.0)
        .set("fullscreen", wanted_ && niri_.fullscreenWindow(target_))
        .set("player", targetApp_ == "mpv" || targetApp_ == "io.github.celluloid_player.Celluloid"
                           || targetApp_ == "org.kde.haruna" || targetApp_ == "vlc" || targetApp_ == "org.gnome.Totem"
                           || targetApp_ == "org.gnome.Showtime");
    return j;
}

void Daemon::writeToml(bool force) {
    const NiriOutput* o = target_ ? niri_.outputOf(target_) : nullptr;
    hz_ = o ? o->hz : (hz_ > 0 ? hz_ : 120);
    double base = base_ > 0 ? base_ : (fps_ > 0 && chosen_ == 0 ? fps_ / std::max(1.0, std::round(hz_ / 30.0)) : 30);
    eff_ = effective(chosen_, fps_, base, hz_);
    if (base_ <= 0) {                        // no measured base yet: the result is a guess, no warning
        eff_.perfect = true;
        eff_.limited = false;
    }
    LsfgParams p;
    p.multiplier = eff_.m;
    int w = child_.stats["w"].asInt(o ? o->modeW : 2880), h = child_.stats["h"].asInt(o ? o->modeH : 1800);
    auto q = calib_.choose(w, h, eff_.m, base);
    p.flowScale = flow_ > 0 ? flow_ : q.flow;
    p.performance = perf_ >= 0 ? perf_ == 1 : q.performance;
    if (eco_) {                              // battery «eco»: performance mode + flow −25 %
        p.performance = true;
        p.flowScale = std::max(0.25, p.flowScale * 0.75);
    }
    if (degrade_ >= 1)
        p.flowScale = std::max(0.25, p.flowScale - 0.15 * std::min(degrade_, 2));
    if (degrade_ >= 3)
        p.performance = true;
    if (degrade_ >= 4)
        p.multiplier = 1;                    // pass-through: the app as it is, with a notice
    if (!force && tomlWritten_ && p.multiplier == written_.multiplier && std::fabs(p.flowScale - written_.flowScale) < 0.01
        && p.performance == written_.performance)
        return;
    if (writeLsfgToml(tomlPath_, p)) {
        written_ = p;
        tomlWritten_ = true;
    } else {
        std::fprintf(stderr, "nameraka: no pude escribir %s\n", tomlPath_.c_str());
    }
}

bool Daemon::spawnView() {
    int pin[2], pout[2];
    if (::pipe2(pin, O_CLOEXEC) < 0 || ::pipe2(pout, O_CLOEXEC) < 0)
        return false;
    posix_spawn_file_actions_t fa;
    posix_spawn_file_actions_init(&fa);
    posix_spawn_file_actions_adddup2(&fa, pin[0], STDIN_FILENO);
    posix_spawn_file_actions_adddup2(&fa, pout[1], STDOUT_FILENO);
    std::string exe = selfExe();
    std::string node = std::to_string(cast_->node());
    std::vector<std::string> args = {exe, "view", "--node", node, "--hidden"};
    if (!outputName_.empty()) {
        args.push_back("--output");
        args.push_back(outputName_);
    }
    std::vector<char*> argv;
    for (auto& a : args)
        argv.push_back(a.data());
    argv.push_back(nullptr);
    // environment: lsfg-vk with our own file and profile; never DISABLE_LSFGVK
    std::vector<std::string> envs;
    for (char** e = environ; *e; ++e) {
        std::string kv = *e;
        if (kv.rfind("LSFGVK_", 0) == 0 || kv.rfind("DISABLE_LSFGVK=", 0) == 0)
            continue;
        envs.push_back(kv);
    }
    envs.push_back("LSFGVK_CONFIG=" + tomlPath_);
    envs.push_back("LSFGVK_PROFILE=nameraka");
    std::vector<char*> envp;
    for (auto& e : envs)
        envp.push_back(e.data());
    envp.push_back(nullptr);
    pid_t pid;
    int r = posix_spawn(&pid, exe.c_str(), &fa, nullptr, argv.data(), envp.data());
    posix_spawn_file_actions_destroy(&fa);
    ::close(pin[0]);
    ::close(pout[1]);
    if (r != 0) {
        ::close(pin[1]);
        ::close(pout[0]);
        return false;
    }
    child_ = Child{};
    child_.pid = pid;
    child_.in = pin[1];
    child_.out = pout[0];
    ::fcntl(child_.out, F_SETFL, ::fcntl(child_.out, F_GETFL) | O_NONBLOCK);
    child_.spawnedAt = child_.lastHb = nowMs();
    return true;
}

void Daemon::killView(bool hard) {
    if (!child_.alive())
        return;
    if (hard) {
        ::kill(child_.pid, SIGKILL);
    } else {
        child_.send("quit");             // the presenter removes its surface first, then tears down the capture
        // give it 300 ms to release its surface and capture cleanly
        for (int i = 0; i < 30; ++i) {
            if (::waitpid(child_.pid, nullptr, WNOHANG) == child_.pid) {
                child_.pid = -1;
                break;
            }
            ::usleep(10000);
        }
        if (child_.pid > 0)
            ::kill(child_.pid, SIGKILL);
    }
    if (child_.pid > 0)
        ::waitpid(child_.pid, nullptr, 0);
    if (child_.in >= 0) ::close(child_.in);
    if (child_.out >= 0) ::close(child_.out);
    child_ = Child{};
}

void Daemon::reapChild() {
    if (!child_.alive())
        return;
    int st;
    if (::waitpid(child_.pid, &st, WNOHANG) == child_.pid) {
        std::fprintf(stderr, "nameraka: el presentador terminó (%d)\n", WIFEXITED(st) ? WEXITSTATUS(st) : -WTERMSIG(st));
        child_.pid = -1;
        if (child_.in >= 0) ::close(child_.in);
        if (child_.out >= 0) ::close(child_.out);
        child_ = Child{};
        if (wanted_) {
            stopAll("el presentador se cerró");
            broadcast(Json().set("ev", "error").set("code", 20).set("msg", "el presentador se cerró"));
        }
    }
}

void Daemon::readChild() {
    char buf[8192];
    while (true) {
        ssize_t n = ::read(child_.out, buf, sizeof buf);
        if (n > 0) {
            child_.buf.append(buf, static_cast<size_t>(n));
            continue;
        }
        break;
    }
    size_t nl;
    bool changed = false;
    while ((nl = child_.buf.find('\n')) != std::string::npos) {
        auto j = Json::parse(child_.buf.substr(0, nl));
        child_.buf.erase(0, nl + 1);
        if (!j)
            continue;
        std::string ev = (*j)["ev"].str();
        child_.lastHb = nowMs();
        if (ev == "capturing") {
            child_.capturing = true;
            changed = true;
        } else if (ev == "ready") {
            std::fprintf(stderr, "nameraka: primer fotograma en pantalla a los %.0f ms de mostrar\n", nowMs() - child_.shownAt);
        } else if (ev == "shown") {
            std::fprintf(stderr, "nameraka: visible otra vez en %.0f ms\n", (*j)["ms"].asNumber());
            broadcast(Json().set("ev", "shown").set("ms", (*j)["ms"]));
        } else if (ev == "hb") {
            child_.visible = (*j)["visible"].asBool();
            child_.lastPresentMs = (*j)["lastPresentMs"].asNumber();
            child_.lastFrameMs = (*j)["lastFrameMs"].asNumber(-1);
        } else if (ev == "stats") {
            child_.stats = *j;
            double b = (*j)["base"].asNumber();
            if (b > 0 && std::fabs(b - base_) > 0.001) {
                base_ = b;
                writeToml();                 // the multiplier follows the measured base (hot reload)
                changed = true;
            }
            audioTick();
            guardTick();
            if (nowMs() - lastStatsSent_ > 900) {
                lastStatsSent_ = nowMs();
                Json s = stateJson();
                s.set("ev", "stats").set("gpuMs", (*j)["gpuMs"]).set("dropped", (*j)["dropped"])
                    .set("presented", (*j)["presented"]).set("frames", (*j)["frames"]).set("raw", (*j)["raw"]);
                broadcast(s, true);
            }
        } else if (ev == "error") {
            std::fprintf(stderr, "nameraka: presentador: %s\n", (*j)["msg"].str().c_str());
        }
    }
    if (changed) {
        broadcast(stateJson());
        evaluate();
    }
}

// a frozen presenter (no heartbeat 750 ms) or a hung one (frames arrive, nothing presented for 1 s while showing):
// an opaque frozen layer must never stay over the screen
void Daemon::watchdog() {
    if (!child_.alive())
        return;
    double now = nowMs();
    bool frozen = now - child_.lastHb > 750 && now - child_.spawnedAt > 3000;
    bool hung = child_.visible && machine_.state == State::Active && child_.lastPresentMs > 1000
        && child_.lastFrameMs >= 0 && child_.lastFrameMs < child_.lastPresentMs - 1000 && now - child_.shownAt > 2000;
    if (frozen || hung) {
        std::fprintf(stderr, "nameraka: vigilante: presentador %s → fuera\n", frozen ? "congelado" : "sin presentar");
        killView(true);
        stopAll("vigilante");
        broadcast(Json().set("ev", "error").set("code", 21).set("msg", "el presentador dejó de responder: se ha quitado"));
    }
}

void Daemon::stopAll(const char* reason) {
    State before = machine_.state;
    if (fullscreenedByUs_ && target_ && niri_.fullscreenWindow(target_))
        niri_.request(Json().set("Action", Json().set("FullscreenWindow", Json().set("id", static_cast<long long>(target_)))).dump());
    fullscreenedByUs_ = false;
    wanted_ = false;
    audio_.stop();
    killView(false);
    if (cast_)
        cast_->stop();
    machine_.state = State::Off;
    base_ = 0;
    degrade_ = 0;
    in_.locked = in_.screenOff = in_.shellPause = false;   // each session starts clean (the shell re-sends them)
    tomlWritten_ = false;
    setReason(reason);
    offSince_ = nowMs();
    (void)before;
    broadcast(stateJson());
}

// guards, once a second while active: GPU ≥ 95 % for 3 s, frames lost for 3 s, or Tctl ≥ 95 °C for 10 s → one step down
void Daemon::guardTick() {
    if (machine_.state != State::Active) {
        gpuHot_ = cpuHot_ = lateSecs_ = 0;
        gpuSamples_.clear();
        return;
    }
    auto readInt = [](const std::string& path) -> long {
        FILE* f = path.empty() ? nullptr : std::fopen(path.c_str(), "r");
        if (!f)
            return -1;
        long v = -1;
        if (std::fscanf(f, "%ld", &v) != 1)
            v = -1;
        std::fclose(f);
        return v;
    };
    if (gpuBusyPath_.empty() || tctlPath_.empty()) {
        for (int i = 0; i < 8 && gpuBusyPath_.empty(); ++i) {
            std::string p = "/sys/class/drm/card" + std::to_string(i) + "/device/gpu_busy_percent";
            if (::access(p.c_str(), R_OK) == 0)
                gpuBusyPath_ = p;
        }
        for (int i = 0; i < 32 && tctlPath_.empty(); ++i) {
            std::string d = "/sys/class/hwmon/hwmon" + std::to_string(i);
            char name[64] = {0};
            if (FILE* f = std::fopen((d + "/name").c_str(), "r")) {
                if (std::fgets(name, sizeof name, f) && std::strncmp(name, "k10temp", 7) == 0)
                    tctlPath_ = d + "/temp1_input";
                std::fclose(f);
            }
        }
    }
    long gpu = readInt(gpuBusyPath_), tctl = readInt(tctlPath_);
    long dropped = child_.stats["dropped"].asInt(0);
    // gpu_busy_percent is instantaneous: a 5 s mean ≥ 97 % counts, single spikes do not (they fired at 80 % average)
    gpuSamples_.push_back(gpu < 0 ? 0 : gpu);
    if (gpuSamples_.size() > 5)
        gpuSamples_.erase(gpuSamples_.begin());
    double mean = 0;
    for (long g : gpuSamples_)
        mean += static_cast<double>(g);
    mean /= static_cast<double>(gpuSamples_.size());
    gpuHot_ = gpuSamples_.size() == 5 && mean >= 97 ? 3 : 0;
    cpuHot_ = tctl >= 95000 ? cpuHot_ + 1 : 0;
    // «late» = more than 10 % of the captured frames replaced before they were shown, in each of 3 seconds in a row.
    // A single replaced frame is not lateness: Chrome repaints its controls between video frames and a 60 fps source
    // at ×2 sits exactly on the 16.7 ms budget, so a lone drop every second or two is capture jitter. Counting any drop
    // (Ayoub, 2026-10-17) walked a healthy ×2 down to pass-through in 12 s.
    long frames = child_.stats["frames"].asInt(0);
    long dFrames = frames - lastFrames_, dDropped = dropped - lastDropped_;
    bool late = dFrames > 0 && dDropped > std::max(2L, dFrames / 10);
    lateSecs_ = late ? lateSecs_ + 1 : 0;
    lastDropped_ = dropped;
    lastFrames_ = frames;
    // lost frames alone stop at step 3 (flow −0,30 + performance): passing through would not bring them back, it only
    // turns the effect off. Pass-through stays for a GPU at its limit or a hot CPU.
    bool lateOnly = lateSecs_ >= 3 && gpuHot_ < 3 && cpuHot_ < 10;
    if ((gpuHot_ >= 3 || lateSecs_ >= 3 || cpuHot_ >= 10) && degrade_ < (lateOnly ? 3 : 4)) {
        ++degrade_;
        std::fprintf(stderr, "nameraka: guardia (%s) → escalón %d · GPU %.0f %% · perdidos %ld de %ld\n",
                     gpuHot_ >= 3 ? "GPU" : lateSecs_ >= 3 ? "fotogramas tarde" : "Tctl", degrade_, mean, dDropped,
                     dFrames);
        gpuHot_ = cpuHot_ = lateSecs_ = 0;
        gpuSamples_.clear();
        writeToml();
        broadcast(stateJson());
        if (degrade_ == 4)
            broadcast(Json().set("ev", "error").set("code", 22).set("msg", "la GPU no da para más: paso directo"));
    }
}

// avSync: the app's audio delayed like the picture while active; back to normal after 2 s paused, or when switched off
void Daemon::audioTick() {
    bool want = avSync_ && wanted_ && base_ > 0
        && (machine_.state == State::Active || (machine_.state == State::Paused && nowMs() - pausedSince_ < 2000));
    if (!want) {
        if (audio_.active())
            audio_.stop();
        return;
    }
    const NiriWindow* w = niri_.window(target_);
    if (!w || w->pid <= 0)
        return;
    int iw = child_.stats["w"].asInt(2880), ih = child_.stats["h"].asInt(1800);
    double tGen = calib_.tGenMs(iw, ih, eff_.m, written_.flowScale, written_.performance);
    audio_.ensure(w->pid, audioDelayMs(base_, tGen, hz_));
}

void Daemon::evaluate() {
    // still waiting for full screen: the target follows the window you look at (you turned it on, then went to
    // the video). Once it runs, the target stays.
    if (wanted_ && machine_.state == State::Arming && niri_.focusedWindow && *niri_.focusedWindow != target_) {
        if (const NiriWindow* f = niri_.window(*niri_.focusedWindow); f && !excluded(*f)) {
            std::fprintf(stderr, "nameraka: objetivo → %s (%llu)\n", f->appId.c_str(),
                         static_cast<unsigned long long>(f->id));
            target_ = f->id;
            targetApp_ = f->appId;
            writeToml();
            broadcast(stateJson());
        }
    }
    const NiriWindow* w = wanted_ ? niri_.window(target_) : nullptr;
    in_.wanted = wanted_;
    in_.targetExists = w != nullptr;
    in_.fullscreen = w && niri_.fullscreenWindow(target_);
    // only another WINDOW taking the keyboard counts (Engawa, Torii… are layer surfaces)
    in_.focused = w && (!niri_.focusedWindow || *niri_.focusedWindow == target_);
    in_.workspaceVisible = w && niri_.workspaceVisible(target_);
    in_.overview = niri_.overview;
    in_.presenterReady = child_.alive() && child_.capturing;
    State from = machine_.state;
    if (machine_.step(in_, nowMs() / 1000.0))
        apply(from, machine_.state);
    // the effective multiplier follows Hz changes too
    if (wanted_) {
        const NiriOutput* o = niri_.outputOf(target_);
        if (o && std::fabs(o->hz - hz_) > 0.5)
            writeToml();
    }
}

void Daemon::apply(State from, State to) {
    std::fprintf(stderr, "nameraka: %s → %s\n", std::string(stateName(from)).c_str(), std::string(stateName(to)).c_str());
    if (to == State::Off) {
        std::string r = reason_.empty() ? (in_.targetExists ? "tiempo de espera" : "la ventana se cerró") : reason_;
        wanted_ = false;
        stopAll(r.c_str());
        return;
    }
    if (to == State::Arming && (from == State::Active || from == State::Paused || from == State::Starting)) {
        // left full screen: drop the presenter and the capture, wait up to 60 s for it to come back
        killView(false);
        cast_->stop();
    }
    if (to == State::Starting) {
        const NiriOutput* o = niri_.outputOf(target_);
        outputName_ = o ? o->name : "";
        if (!cast_->running() && !cast_->start(target_)) {
            setReason("niri no deja capturar la ventana");
            stopAll(reason_.c_str());
            return;
        }
        // the node arrives with a signal: wait for it here (≤ 1 s) so the presenter starts at once
        double until = nowMs() + 1000;
        while (!cast_->node() && nowMs() < until) {
            pollfd p{cast_->fd(), POLLIN, 0};
            poll(&p, 1, 20);
            cast_->process();
        }
        if (!cast_->node()) {
            setReason("niri no entregó la captura");
            stopAll(reason_.c_str());
            return;
        }
        writeToml(true);
        if (!child_.alive() && !spawnView()) {
            setReason("no se pudo lanzar el presentador");
            stopAll(reason_.c_str());
            return;
        }
    }
    if (to == State::Active && child_.alive()) {
        child_.shownAt = nowMs();
        child_.send("show");
        pausedSince_ = 0;
    } else if (to == State::Paused && child_.alive()) {
        child_.send("hide");
        pausedSince_ = nowMs();
    }
    if (to == State::Arming)
        audio_.stop();
    audioTick();
    broadcast(stateJson());
}

int Daemon::run(int argc, char** argv) {
    (void)argc;
    (void)argv;
    std::signal(SIGTERM, [](int) { gQuit = 1; });
    std::signal(SIGINT, [](int) { gQuit = 1; });
    std::signal(SIGPIPE, SIG_IGN);
    stateDir_ = stateDir();
    tomlPath_ = stateDir_ + "/lsfg.toml";
    dll_ = findLsfgDll();
    calib_.load(stateDir_ + "/calibration.json", dll_);
    if (!listen())
        return 1;
    cast_ = std::make_unique<ScreenCast>(stateDir_ + "/session");
    if (!cast_->open() || !cast_->available()) {
        std::fprintf(stderr, "nameraka: niri no ofrece org.gnome.Mutter.ScreenCast ≥ 4\n");
        return 10;
    }
    if (!niri_.connect()) {
        std::fprintf(stderr, "nameraka: no hay IPC de niri (NIRI_SOCKET)\n");
        return 10;
    }
    sd_notify(0, "READY=1");
    std::fprintf(stderr, "nameraka: listo (DLL %s)\n", dll_.empty() ? "no encontrada" : dll_.c_str());
    offSince_ = nowMs();
    while (!gQuit) {
        std::vector<pollfd> fds;
        fds.push_back({listenFd_, POLLIN, 0});
        fds.push_back({niri_.fd(), POLLIN, 0});
        short busEv = static_cast<short>(cast_->events());
        fds.push_back({cast_->fd(), static_cast<short>(busEv ? busEv : POLLIN), 0});
        fds.push_back({child_.alive() ? child_.out : -1, POLLIN, 0});
        for (auto& c : clients_)
            fds.push_back({c->fd, POLLIN, 0});
        // 100 ms while something runs (watchdog, arming, starting); 1 s when switched off with no presenter
        poll(fds.data(), fds.size(), machine_.state == State::Off && !child_.alive() ? 1000 : 100);
        if (fds[0].revents & POLLIN)
            accept();
        if (fds[1].revents & (POLLIN | POLLHUP)) {
            if (!niri_.read()) {
                std::fprintf(stderr, "nameraka: niri cerró el flujo de eventos\n");
                stopAll("niri");
                break;
            }
        }
        cast_->process();
        if (cast_->closedByNiri() && wanted_)
            stopAll("niri cerró la captura");
        if (child_.alive() && (fds[3].revents & (POLLIN | POLLHUP)))
            readChild();
        for (size_t i = 0; i < clients_.size(); ++i)
            if (fds[4 + i].revents & (POLLIN | POLLHUP))
                readClient(*clients_[i]);
        clients_.erase(std::remove_if(clients_.begin(), clients_.end(), [](auto& c) { return c->fd < 0; }), clients_.end());
        reapChild();
        watchdog();
        if (niri_.changed || machine_.state == State::Arming || machine_.state == State::Starting) {
            niri_.changed = false;
            if (wanted_ || machine_.state != State::Off)
                evaluate();
        }
        // nothing to do for 60 s: socket activation brings us back
        if (machine_.state == State::Off && !child_.alive() && nowMs() - offSince_ > 60000) {
            std::fprintf(stderr, "nameraka: 60 s apagado: salgo\n");
            break;
        }
    }
    stopAll("salida");
    cast_->close();
    niri_.close();
    for (auto& c : clients_)
        if (c->fd >= 0)
            ::close(c->fd);
    if (ownSocket_)
        ::unlink(runtimeSocket().c_str());
    return 0;
}

} // namespace

int runDaemon(int argc, char** argv) {
    Daemon d;
    return d.run(argc, argv);
}

} // namespace nk
