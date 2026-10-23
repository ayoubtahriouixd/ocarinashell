#include "common/paths.hpp"

#include <array>
#include <algorithm>
#include <climits>
#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <regex>
#include <sys/stat.h>
#include <unistd.h>

namespace fs = std::filesystem;

namespace nk {

namespace {
std::string env(const char* k, const std::string& def) {
    const char* v = std::getenv(k);
    return v && *v ? v : def;
}
std::string home() { return env("HOME", "/tmp"); }
} // namespace

std::string stateDir() {
    std::string d = env("XDG_STATE_HOME", home() + "/.local/state") + "/ocarinashell/nameraka";
    std::error_code ec;
    fs::create_directories(d, ec);
    return d;
}

std::string runtimeSocket() {
    // NAMERAKA_SOCKET: a second daemon for measurements (scripts/bench-fluido.sh) without touching the systemd socket
    if (const char* o = std::getenv("NAMERAKA_SOCKET"); o && *o)
        return o;
    std::string d = env("XDG_RUNTIME_DIR", "/tmp") + "/ocarinashell";
    std::error_code ec;
    fs::create_directories(d, ec);
    return d + "/nameraka.sock";
}

std::string selfExe() {
    char buf[PATH_MAX];
    ssize_t n = ::readlink("/proc/self/exe", buf, sizeof buf - 1);
    if (n <= 0)
        return "nameraka";
    buf[n] = 0;
    // updated while running (scripts/install.sh replaces the file): the path now holds the new binary
    std::string p = buf;
    const std::string del = " (deleted)";
    if (p.size() > del.size() && p.compare(p.size() - del.size(), del.size(), del) == 0)
        p.resize(p.size() - del.size());
    return p;
}

std::vector<std::string> steamLibraries() {
    std::vector<std::string> libs;
    const std::string roots[] = {home() + "/.local/share/Steam", home() + "/.steam/steam",
                                 home() + "/.var/app/com.valvesoftware.Steam/.local/share/Steam"};
    for (const auto& r : roots) {
        std::error_code ec;
        if (fs::exists(r + "/steamapps", ec))
            libs.push_back(fs::canonical(r, ec).string());
        std::ifstream f(r + "/steamapps/libraryfolders.vdf");
        std::string line;
        static const std::regex path(R"re("path"\s+"([^"]+)")re");
        while (std::getline(f, line)) {
            std::smatch m;
            if (std::regex_search(line, m, path))
                libs.push_back(m[1].str());
        }
    }
    std::vector<std::string> uniq;
    for (auto& l : libs) {
        std::error_code ec;
        auto c = fs::weakly_canonical(l, ec).string();
        if (std::find(uniq.begin(), uniq.end(), c) == uniq.end())
            uniq.push_back(c);
    }
    return uniq;
}

std::string findLsfgDll() {
    for (const auto& lib : steamLibraries()) {
        std::string p = lib + "/steamapps/common/Lossless Scaling/lsfg-vk.dll";
        std::error_code ec;
        if (fs::is_regular_file(p, ec))
            return p;
    }
    return {};
}

std::string sha256(const std::string& path) {
    std::string cmd = "sha256sum -- '";
    for (char c : path)
        cmd += c == '\'' ? std::string("'\\''") : std::string(1, c);
    cmd += "' 2>/dev/null";
    FILE* p = ::popen(cmd.c_str(), "r");
    if (!p)
        return {};
    std::array<char, 128> buf{};
    std::string out;
    if (std::fgets(buf.data(), static_cast<int>(buf.size()), p))
        out = buf.data();
    ::pclose(p);
    auto sp = out.find(' ');
    return sp == 64 ? out.substr(0, 64) : std::string();
}

bool lsfgLayerInstalled() {
    const std::string dirs[] = {"/usr/share/vulkan/implicit_layer.d", "/etc/vulkan/implicit_layer.d",
                                home() + "/.local/share/vulkan/implicit_layer.d"};
    for (const auto& d : dirs) {
        std::error_code ec;
        if (fs::is_regular_file(d + "/VkLayer_LSFGVK_frame_generation.json", ec))
            return true;
    }
    return false;
}

} // namespace nk
