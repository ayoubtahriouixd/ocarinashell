// Effective multiplier (docs/01-ARQUITECTURA §19 «Multiplicador efectivo»): lsfg-vk only paces with vsync, so the
// output is perfect only when base × m = Hz. Fixed mode N: m = max(1, min(N, ⌊Hz/base⌋)). «A medida» with target T
// (0 = Hz): m = max(1, min(round(T/base), ⌊Hz/base⌋)). m = 1 = pass-through.
// Audio delay (§19 «Audio sincronizado»): D = 1000/base + t_gen + 1,5 × 1000/Hz ms, re-applied only past 10 ms.
#pragma once

namespace nk {

struct Effective {
    int m = 1;            // the multiplier lsfg-vk gets
    double out = 0;       // base × m (fps on screen)
    bool perfect = false; // base × m = Hz (±0,5 %): one frame per refresh
    bool limited = false; // the chosen N or target was cut down by the refresh rate
};

// chosen: 2/4/6 (fixed) or 0 for «A medida»; target: custom fps for «A medida» (0 = Hz)
Effective effective(int chosen, double target, double base, double hz);

double audioDelayMs(double base, double tGenMs, double hz);
bool audioDelayChanged(double appliedMs, double wantedMs);

} // namespace nk
