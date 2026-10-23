// Audio in sync with the generated picture (docs/01-ARQUITECTURA §19 «Audio sincronizado»): generating delays the
// picture ≈ one base frame + t_gen, so the target app's audio is delayed as much. A pw-loopback with --delay creates a
// virtual sink («nameraka-delay») that declares no latency (checked: players do not compensate for it, so the delay
// works) and plays into the current default output; the app's output streams (its process and children — Chrome
// plays from a child process) are moved there with the `target.object` metadata and moved back by DELETING it:
// WirePlumber then routes them to the default again and remembers no target (checked in fase 11).
#pragma once

#include <set>
#include <string>
#include <sys/types.h>

namespace nk {

class AudioDelay {
public:
    // keep the app's streams delayed by delayMs (re-scans for new streams; restarts the loopback past 10 ms change)
    void ensure(pid_t appPid, double delayMs);
    // streams back to their output, loopback gone
    void stop();
    bool active() const { return loopback_ > 0; }
    double delayMs() const { return delay_; }

private:
    void startLoopback(double delayMs);
    void killLoopback();
    void moveStreams(pid_t appPid);
    void restoreStreams();
    pid_t loopback_ = -1;
    double delay_ = 0;
    std::set<long> moved_;
    double lastScan_ = 0;
};

} // namespace nk
