#include "daemon/calibration.hpp"

#include <array>
#include <cmath>
#include <cstdio>
#include <fstream>
#include <sstream>

#include "common/json.hpp"
#include "common/paths.hpp"
#include "daemon/niri.hpp"

namespace nk {

namespace {
constexpr double kMargin = 1.3;
// quality order: best first (performance mode off, then flow high → low)
constexpr std::array<std::pair<double, bool>, 6> kLadder = {{{1.0, false}, {0.75, false}, {0.5, false},
                                                             {0.75, true}, {0.5, true}, {0.35, true}}};

std::string shell(const std::string& cmd) {
    FILE* p = ::popen(cmd.c_str(), "r");
    if (!p)
        return {};
    std::string out;
    char buf[512];
    while (std::fgets(buf, sizeof buf, p))
        out += buf;
    ::pclose(p);
    return out;
}

double field(const std::string& text, const std::string& name) {
    auto pos = text.find(name);
    if (pos == std::string::npos)
        return 0;
    pos = text.find(':', pos);
    return pos == std::string::npos ? 0 : std::atof(text.c_str() + pos + 1);
}
} // namespace

void Calibration::load(const std::string& path, const std::string& dll) {
    path_ = path;
    entries_.clear();
    std::ifstream f(path);
    if (!f)
        return;
    std::stringstream ss;
    ss << f.rdbuf();
    auto j = Json::parse(ss.str());
    if (!j)
        return;
    // a calibration made with another DLL (Steam updated it) or none at all is ignored
    if (!dll.empty() && (*j)["dll"].str() != sha256(dll)) {
        std::fprintf(stderr, "nameraka: la DLL cambió desde la calibración: uso los valores por defecto\n");
        return;
    }
    for (const auto& e : (*j)["entries"].array()) {
        Entry x;
        x.w = static_cast<int>(e["w"].asInt());
        x.h = static_cast<int>(e["h"].asInt());
        x.m = static_cast<int>(e["m"].asInt());
        x.flow = e["flow"].asNumber(1);
        x.perf = e["perf"].asBool();
        x.maxBase = e["maxBase"].asNumber();
        x.tGenMs = e["tGenMs"].asNumber();
        entries_.push_back(x);
    }
}

Quality Calibration::choose(int w, int h, int m, double base) const {
    const double need = std::max(1.0, base) * kMargin;
    if (m <= 1)
        return {1.0, false, 0};
    if (!entries_.empty()) {
        // the calibrated resolution closest to this one (by pixel count), the same multiplier or the nearest above
        long px = static_cast<long>(w) * h;
        for (auto [flow, perf] : kLadder) {
            const Entry* best = nullptr;
            for (const auto& e : entries_) {
                if (std::fabs(e.flow - flow) > 0.01 || e.perf != perf || e.m < m)
                    continue;
                if (!best || std::labs(static_cast<long>(e.w) * e.h - px) < std::labs(static_cast<long>(best->w) * best->h - px)
                    || (e.m < best->m))
                    best = &e;
            }
            if (best) {
                // more pixels than calibrated: scale the maximum down
                double scale = static_cast<double>(best->w) * best->h / std::max(1L, px);
                if (best->maxBase * std::min(1.0, scale) >= need)
                    return {flow, perf, best->tGenMs};
            }
        }
        return {0.35, true, 0};
    }
    // defaults measured on the 860M
    long px = static_cast<long>(w) * h;
    if (px >= 4'500'000)                     // 2880×1800 class
        return m >= 3 ? Quality{0.5, false, 16.2} : (base > 45 ? Quality{0.5, true, 6.4} : Quality{0.75, false, 12});
    if (px >= 1'800'000)                     // 1080p class
        return m >= 4 ? Quality{0.75, false, 9} : Quality{1.0, false, 6};
    return {1.0, false, 4};
}

double Calibration::tGenMs(int w, int h, int m, double flow, bool perf) const {
    for (const auto& e : entries_)
        if (e.w == w && e.h == h && e.m == m && std::fabs(e.flow - flow) < 0.01 && e.perf == perf)
            return e.tGenMs;
    return choose(w, h, m, 30).tGenMs;
}

bool Calibration::run(const std::string& dll, const Niri& niri) {
    int w = 2880, h = 1800;
    for (const auto& [name, o] : niri.outputs)
        if (name.rfind("eDP", 0) == 0 && o.modeW > 0) {
            w = o.modeW;
            h = o.modeH;
        }
    Json::Array arr;
    entries_.clear();
    for (int m : {2, 3, 4, 5}) {
        for (auto [flow, perf] : kLadder) {
            char cmd[512];
            std::snprintf(cmd, sizeof cmd, "DISABLE_LSFGVK=1 timeout 30 lsfg-vk-cli benchmark -w %d -h %d -m %d -f %.2f %s -t 3 2>&1",
                          w, h, m, flow, perf ? "-p" : "");
            std::string out = shell(cmd);
            Entry e{w, h, m, flow, perf, field(out, "Base FPS"), field(out, "Time per iteration")};
            if (e.maxBase <= 0)
                continue;
            entries_.push_back(e);
            arr.push_back(Json().set("w", w).set("h", h).set("m", m).set("flow", flow).set("perf", perf)
                              .set("maxBase", e.maxBase).set("tGenMs", e.tGenMs));
            std::fprintf(stderr, "nameraka: calibración %dx%d ×%d flujo %.2f%s → %.1f fps base\n", w, h, m, flow,
                         perf ? " rendimiento" : "", e.maxBase);
        }
    }
    if (entries_.empty())
        return false;
    Json j;
    j.set("version", 1).set("dll", sha256(dll)).set("entries", Json(arr));
    std::ofstream f(path_ + ".tmp", std::ios::trunc);
    f << j.dump() << "\n";
    f.close();
    return std::rename((path_ + ".tmp").c_str(), path_.c_str()) == 0;
}

} // namespace nk
