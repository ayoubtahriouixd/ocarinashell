// Where Nameraka keeps things (docs/01-ARQUITECTURA §19 «Procesos y ficheros»).
#pragma once

#include <string>
#include <vector>

namespace nk {

std::string stateDir();          // ~/.local/state/ocarinashell/nameraka (created)
std::string runtimeSocket();     // $XDG_RUNTIME_DIR/ocarinashell/nameraka.sock
std::string selfExe();           // /proc/self/exe resolved
// lsfg-vk.dll from the `lsfg-vk` beta of Lossless Scaling, in any Steam library; empty if not found
std::string findLsfgDll();
std::vector<std::string> steamLibraries();
// sha256 of a file as hex (via sha256sum; empty on error) — the DLL fingerprint for calibration
std::string sha256(const std::string& path);
bool lsfgLayerInstalled();       // the implicit layer manifest of lsfg-vk ≥ 2.0

} // namespace nk
