// Nameraka states (docs/01-ARQUITECTURA §19 «Estados»): off → arming → starting → active ⇄ paused → off.
// A pure function of what the daemon knows now (niri events + what the shell tells it), so it can be tested alone.
#pragma once

#include <string_view>

namespace nk {

enum class State { Off, Arming, Starting, Active, Paused };

std::string_view stateName(State s);

struct Inputs {
    bool wanted = false;           // Fluido is switched on
    bool targetExists = false;     // the target window is still open
    bool fullscreen = false;       // the target fills its output
    bool focused = false;          // no other window took the focus (shell surfaces do not count)
    bool workspaceVisible = false; // the target's workspace is the active one on its output
    bool overview = false;
    bool locked = false;           // told by the shell
    bool screenOff = false;        // told by the shell
    bool shellPause = false;       // `pause` from the shell (its own popups that must stay on top)
    bool presenterReady = false;   // capture + Vulkan up, first frame imported
};

struct Machine {
    State state = State::Off;
    double armingSince = 0;        // seconds (monotonic) when arming began
    static constexpr double kArmingTimeout = 60;

    // returns true when the state changed
    bool step(const Inputs& in, double now);
};

// visible conditions for `active` (all true) — anything else while running is `paused`
bool showable(const Inputs& in);

} // namespace nk
