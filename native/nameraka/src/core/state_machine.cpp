#include "core/state_machine.hpp"

namespace nk {

std::string_view stateName(State s) {
    switch (s) {
    case State::Off: return "off";
    case State::Arming: return "arming";
    case State::Starting: return "starting";
    case State::Active: return "active";
    case State::Paused: return "paused";
    }
    return "off";
}

bool showable(const Inputs& in) {
    return in.fullscreen && in.focused && in.workspaceVisible && !in.overview && !in.locked && !in.screenOff
        && !in.shellPause;
}

bool Machine::step(const Inputs& in, double now) {
    State next = state;
    if (!in.wanted || !in.targetExists) {
        next = State::Off;
    } else if (!in.fullscreen) {
        // not (or no longer) full screen: wait for it up to 60 s
        if (state != State::Arming)
            armingSince = now;
        next = (state == State::Arming && now - armingSince > kArmingTimeout) ? State::Off : State::Arming;
    } else {
        switch (state) {
        case State::Off:
        case State::Arming:
            next = State::Starting;
            break;
        case State::Starting:
            if (in.presenterReady)
                next = showable(in) ? State::Active : State::Paused;
            break;
        case State::Active:
        case State::Paused:
            next = showable(in) && in.presenterReady ? State::Active : State::Paused;
            break;
        }
    }
    bool changed = next != state;
    state = next;
    return changed;
}

} // namespace nk
