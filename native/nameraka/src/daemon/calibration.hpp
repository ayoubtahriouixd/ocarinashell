// Calibration (docs/01-ARQUITECTURA §19 «Energía, calidad y calibración»): `lsfg-vk-cli benchmark` at the panel's
// resolution for each multiplier × flow scale × performance mode → the highest base fps each combination sustains,
// stored in ~/.local/state/ocarinashell/nameraka/calibration.json with t_gen and the DLL fingerprint (Steam updates
// the DLL by itself: a different fingerprint means «calibrate again»). The quality used is the best one whose maximum
// is ≥ 1,3 × the base it needs. Without a calibration, defaults measured on the Radeon 860M (fase 11): at 2880×1800
// ×4 flow 1,0 sustains 28,9 fps base (not enough for 30), flow 0,5 sustains 61,8.
#pragma once

#include <string>
#include <vector>

namespace nk {

class Niri;

struct Quality {
    double flow = 1.0;
    bool performance = false;
    double tGenMs = 0;
};

class Calibration {
public:
    void load(const std::string& path, const std::string& dll);
    bool loaded() const { return !entries_.empty(); }
    Quality choose(int w, int h, int m, double base) const;
    // blocking (≈ 1 min): runs the benchmarks for the internal panel's mode and saves the file
    bool run(const std::string& dll, const Niri& niri);
    double tGenMs(int w, int h, int m, double flow, bool perf) const;

private:
    struct Entry {
        int w = 0, h = 0, m = 0;
        double flow = 1;
        bool perf = false;
        double maxBase = 0;
        double tGenMs = 0;
    };
    std::vector<Entry> entries_;
    std::string path_;
};

} // namespace nk
