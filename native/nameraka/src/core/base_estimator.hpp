// Base frame rate of the captured content (docs/01-ARQUITECTURA §19 «Base»): intervals between NEW frames → mean of the
// middle half of the last 32 → snapped to the usual rates when within ±3 % → a change only applies after it has lasted > 1 s.
// A gap longer than 0.5 s (a paused video) is not an interval: it neither counts nor resets the estimate.
#pragma once

#include <deque>

namespace nk {

class BaseEstimator {
public:
    // t: arrival time of a new (non-duplicate) frame, seconds on a monotonic clock
    void push(double t);
    void reset();
    // the applied base fps (0 until there are enough intervals)
    double base() const { return base_; }
    // the current median before snapping and hysteresis (0 if unknown)
    double raw() const { return raw_; }
    static double snap(double fps);

    static constexpr int kWindow = 32;
    static constexpr int kMinIntervals = 8;
    static constexpr double kPauseGap = 0.5;
    static constexpr double kHold = 1.0;

private:
    std::deque<double> intervals_;
    double last_ = -1;
    double raw_ = 0;
    double base_ = 0;
    double candidate_ = 0;
    double candidateSince_ = 0;
};

} // namespace nk
