// Nameraka's own lsfg-vk configuration (docs/01-ARQUITECTURA §19): ~/.local/state/ocarinashell/nameraka/lsfg.toml,
// selected with LSFGVK_CONFIG + LSFGVK_PROFILE=nameraka so the games' ~/.config/lsfg-vk/conf.toml stays untouched.
// lsfg-vk 2.0 rejects unknown keys and reloads multiplier / flow_scale / performance_mode live (inotify on the parent
// directory, IN_CLOSE_WRITE | IN_MOVED_TO: an atomic rename works). multiplier 1 = pass-through, also live.
#pragma once

#include <string>

namespace nk {

struct LsfgParams {
    int multiplier = 2;          // ≥ 1
    double flowScale = 1.0;      // 0.25 … 1.0
    bool performance = false;
    bool allowFp16 = true;
    std::string dll;             // empty: lsfg-vk finds it in the Steam library
};

std::string lsfgToml(const LsfgParams& p);
// write to path atomically (temp file in the same directory + rename); false on error
bool writeLsfgToml(const std::string& path, const LsfgParams& p);

} // namespace nk
