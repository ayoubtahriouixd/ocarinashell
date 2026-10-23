#include "core/base_estimator.hpp"

#include <algorithm>
#include <cmath>
#include <vector>

namespace nk {

namespace {
constexpr double kRates[] = {10, 12, 15, 20, 23.976, 24, 25, 29.97, 30, 48, 50, 59.94, 60};
}

double BaseEstimator::snap(double fps) {
    if (fps <= 0)
        return 0;
    double best = 0, bestErr = 1e9;
    for (double r : kRates) {
        double err = std::fabs(fps - r) / r;
        if (err <= 0.03 && err < bestErr) {
            best = r;
            bestErr = err;
        }
    }
    // 29,97 and 30 (23,976/24, 59,94/60) are 0,1 % apart and arrival times are quantised to the refresh: the NTSC rate
    // wins only when the measure is clearly on its side (below the lower quarter between the two)
    for (auto [ntsc, whole] : {std::pair{23.976, 24.0}, {29.97, 30.0}, {59.94, 60.0}})
        if (best == ntsc && fps > ntsc + 0.25 * (whole - ntsc))
            best = whole;
    return best > 0 ? best : std::round(fps * 100) / 100;
}

void BaseEstimator::reset() {
    intervals_.clear();
    last_ = -1;
    raw_ = base_ = candidate_ = candidateSince_ = 0;
}

void BaseEstimator::push(double t) {
    if (last_ >= 0) {
        double dt = t - last_;
        if (dt > 0 && dt <= kPauseGap) {
            intervals_.push_back(dt);
            if (static_cast<int>(intervals_.size()) > kWindow)
                intervals_.pop_front();
        }
    }
    last_ = t;
    if (static_cast<int>(intervals_.size()) < kMinIntervals)
        return;
    // mean of the middle half: as robust as the median against a late frame, but precise enough to tell 29,97 from 30
    std::vector<double> v(intervals_.begin(), intervals_.end());
    std::sort(v.begin(), v.end());
    size_t lo = v.size() / 4, hi = v.size() - v.size() / 4;
    double sum = 0;
    for (size_t k = lo; k < hi; ++k)
        sum += v[k];
    double mean = sum / static_cast<double>(hi - lo);
    raw_ = mean > 0 ? 1.0 / mean : 0;
    double s = snap(raw_);
    if (base_ == 0) {                       // first estimate: apply at once
        base_ = candidate_ = s;
        candidateSince_ = t;
        return;
    }
    if (std::fabs(s - base_) < 1e-6) {
        candidate_ = s;
        candidateSince_ = t;
        return;
    }
    if (std::fabs(s - candidate_) > 1e-6) {  // a new candidate starts its hold time
        candidate_ = s;
        candidateSince_ = t;
        return;
    }
    if (t - candidateSince_ > kHold)
        base_ = candidate_;
}

} // namespace nk
