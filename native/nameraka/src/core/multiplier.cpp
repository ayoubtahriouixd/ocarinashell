#include "core/multiplier.hpp"

#include <algorithm>
#include <cmath>

namespace nk {

Effective effective(int chosen, double target, double base, double hz) {
    Effective e;
    if (base <= 0 || hz <= 0) {
        e.m = 1;
        return e;
    }
    // a tiny tolerance so 23,976 × 5 fits under 120 and 59,94 × 2 under 119,88
    int cap = std::max(1, static_cast<int>(std::floor(hz / base + 0.01)));
    int want;
    if (chosen > 0) {
        want = chosen;
    } else {
        double t = target > 0 ? target : hz;
        want = std::max(1, static_cast<int>(std::lround(t / base)));
    }
    e.m = std::max(1, std::min(want, cap));
    e.limited = e.m < want;
    e.out = base * e.m;
    e.perfect = std::fabs(e.out - hz) <= hz * 0.005;
    return e;
}

double audioDelayMs(double base, double tGenMs, double hz) {
    if (base <= 0 || hz <= 0)
        return 0;
    return 1000.0 / base + tGenMs + 1.5 * 1000.0 / hz;
}

bool audioDelayChanged(double appliedMs, double wantedMs) {
    return std::fabs(appliedMs - wantedMs) > 10.0;
}

} // namespace nk
