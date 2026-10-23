#include "daemon/audio.hpp"

#include <chrono>
#include <csignal>
#include <cstdio>
#include <cstdlib>
#include <dirent.h>
#include <fcntl.h>
#include <fstream>
#include <map>
#include <spawn.h>
#include <string>
#include <sys/wait.h>
#include <unistd.h>
#include <vector>

#include "common/json.hpp"
#include "core/multiplier.hpp"

extern char** environ;

namespace nk {

namespace {

double nowMs() {
    return std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now().time_since_epoch()).count();
}

std::string capture(const std::string& cmd) {
    FILE* p = ::popen(cmd.c_str(), "r");
    if (!p)
        return {};
    std::string out;
    char buf[65536];
    size_t n;
    while ((n = std::fread(buf, 1, sizeof buf, p)) > 0)
        out.append(buf, n);
    ::pclose(p);
    return out;
}

void run(std::vector<std::string> args) {
    std::vector<char*> argv;
    for (auto& a : args)
        argv.push_back(a.data());
    argv.push_back(nullptr);
    pid_t pid;
    if (posix_spawnp(&pid, argv[0], nullptr, nullptr, argv.data(), environ) == 0)
        ::waitpid(pid, nullptr, 0);
}

// the app's process and all its descendants (Chrome/Electron play audio from a child)
std::set<long> processTree(pid_t root) {
    std::map<long, long> parent;
    if (DIR* d = ::opendir("/proc")) {
        while (dirent* e = ::readdir(d)) {
            char* end;
            long pid = std::strtol(e->d_name, &end, 10);
            if (*end || pid <= 0)
                continue;
            std::ifstream f(std::string("/proc/") + e->d_name + "/stat");
            std::string s;
            std::getline(f, s);
            auto rp = s.rfind(')');
            if (rp == std::string::npos)
                continue;
            long ppid = 0;
            char state;
            if (std::sscanf(s.c_str() + rp + 1, " %c %ld", &state, &ppid) == 2)
                parent[pid] = ppid;
        }
        ::closedir(d);
    }
    std::set<long> tree{root};
    bool grew = true;
    while (grew) {
        grew = false;
        for (auto& [pid, pp] : parent)
            if (tree.count(pp) && !tree.count(pid)) {
                tree.insert(pid);
                grew = true;
            }
    }
    return tree;
}

} // namespace

void AudioDelay::startLoopback(double delayMs) {
    char delay[32];
    std::snprintf(delay, sizeof delay, "--delay=%.3f", delayMs / 1000.0);
    std::vector<std::string> args = {
        "pw-loopback", delay,
        "--capture-props=media.class=Audio/Sink node.name=nameraka-delay node.virtual=true "
        "node.description=\"滑 Nameraka · retardo\" audio.position=[FL,FR]",
        "--playback-props=node.name=nameraka-delay-out media.role=Movie node.description=\"滑 Nameraka\" "
        "audio.position=[FL,FR] node.passive=false"};
    std::vector<char*> argv;
    for (auto& a : args)
        argv.push_back(a.data());
    argv.push_back(nullptr);
    posix_spawn_file_actions_t fa;
    posix_spawn_file_actions_init(&fa);
    posix_spawn_file_actions_addopen(&fa, STDOUT_FILENO, "/dev/null", O_WRONLY, 0);
    pid_t pid;
    if (posix_spawnp(&pid, "pw-loopback", &fa, nullptr, argv.data(), environ) == 0) {
        loopback_ = pid;
        delay_ = delayMs;
        std::fprintf(stderr, "nameraka: audio retrasado %.0f ms\n", delayMs);
        ::usleep(150000);                    // let the virtual sink appear before streams are pointed at it
    }
    posix_spawn_file_actions_destroy(&fa);
}

void AudioDelay::killLoopback() {
    if (loopback_ > 0) {
        ::kill(loopback_, SIGTERM);
        ::waitpid(loopback_, nullptr, 0);
    }
    loopback_ = -1;
}

void AudioDelay::moveStreams(pid_t appPid) {
    auto dump = Json::parse(capture("pw-dump 2>/dev/null"));
    if (!dump)
        return;
    auto tree = processTree(appPid);
    for (const auto& o : dump->array()) {
        const auto& p = o["info"]["props"];
        if (p["media.class"].str() != "Stream/Output/Audio")
            continue;
        long pid = std::strtol(p["application.process.id"].str("0").c_str(), nullptr, 10);
        if (p["application.process.id"].isNumber())
            pid = p["application.process.id"].asInt();
        long id = o["id"].asInt();
        if (!tree.count(pid) || moved_.count(id) || p["node.name"].str().rfind("nameraka", 0) == 0)
            continue;
        run({"pw-metadata", "-n", "default", std::to_string(id), "target.object", "nameraka-delay"});
        moved_.insert(id);
    }
}

void AudioDelay::restoreStreams() {
    for (long id : moved_)
        run({"pw-metadata", "-n", "default", "-d", std::to_string(id), "target.object"});
    moved_.clear();
}

void AudioDelay::ensure(pid_t appPid, double delayMs) {
    if (appPid <= 0 || delayMs <= 0)
        return;
    if (loopback_ > 0 && audioDelayChanged(delay_, delayMs)) {
        restoreStreams();
        killLoopback();
    }
    if (loopback_ <= 0)
        startLoopback(delayMs);
    if (loopback_ <= 0)
        return;
    // streams the app opens later (another tab, the next video) are caught by a scan every 2 s
    if (nowMs() - lastScan_ > 2000) {
        lastScan_ = nowMs();
        moveStreams(appPid);
    }
}

void AudioDelay::stop() {
    restoreStreams();
    killLoopback();
    lastScan_ = 0;
}

} // namespace nk
