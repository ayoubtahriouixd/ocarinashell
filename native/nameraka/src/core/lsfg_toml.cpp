#include "core/lsfg_toml.hpp"

#include <algorithm>
#include <cstdio>
#include <fcntl.h>
#include <unistd.h>

namespace nk {

namespace {
std::string tomlString(const std::string& s) {
    std::string out = "\"";
    for (char c : s) {
        if (c == '"' || c == '\\')
            out += '\\';
        if (c == '\n' || c == '\r')
            continue;
        out += c;
    }
    return out + "\"";
}
} // namespace

std::string lsfgToml(const LsfgParams& p) {
    char flow[16];
    std::snprintf(flow, sizeof flow, "%.2f", std::clamp(p.flowScale, 0.25, 1.0));
    std::string t = "# GENERATED — owner: nameraka (滑 Nameraka). Rewritten on every change; do not edit.\n"
                    "version = 2\n\n[global]\n";
    t += std::string("allow_fp16 = ") + (p.allowFp16 ? "true" : "false") + "\n";
    if (!p.dll.empty())
        t += "dll = " + tomlString(p.dll) + "\n";
    t += "\n[[profile]]\nname = \"nameraka\"\nactive_in = \"nameraka\"\n";
    t += "multiplier = " + std::to_string(std::max(1, p.multiplier)) + "\n";
    t += std::string("flow_scale = ") + flow + "\n";
    t += std::string("performance_mode = ") + (p.performance ? "true" : "false") + "\n";
    t += "pacing_mode = \"vsync\"\n";
    return t;
}

bool writeLsfgToml(const std::string& path, const LsfgParams& p) {
    const std::string text = lsfgToml(p);
    const std::string tmp = path + ".tmp";
    int fd = ::open(tmp.c_str(), O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0644);
    if (fd < 0)
        return false;
    bool ok = ::write(fd, text.data(), text.size()) == static_cast<ssize_t>(text.size());
    ok = ::fsync(fd) == 0 && ok;
    ::close(fd);
    if (!ok || ::rename(tmp.c_str(), path.c_str()) != 0) {
        ::unlink(tmp.c_str());
        return false;
    }
    return true;
}

} // namespace nk
