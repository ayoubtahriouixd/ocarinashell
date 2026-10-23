// `nameraka self-test [--json]` (docs/01-ARQUITECTURA §19): every stage, without starting anything visible.
// Exit codes: 0 ok · 10 no niri ScreenCast · 11 no layer-shell / viewporter · 12 no Vulkan with DMA-BUF modifiers ·
// 13 no lsfg-vk · 14 no lsfg-vk.dll (Lossless Scaling, `lsfg-vk` beta). ocarina-nameraka-selftest.service runs it at
// login and writes ~/.local/state/ocarinashell/nameraka/selftest.json, which the shell reads (available + reason).
#include <cstdio>
#include <cstring>
#include <fstream>
#include <string>
#include <unistd.h>

#include "common/json.hpp"
#include "common/paths.hpp"
#include "daemon/screencast.hpp"
#include "view/vk.hpp"
#include "view/wayland.hpp"

namespace nk {

int runSelfTest(int argc, char** argv) {
    bool json = argc > 0 && !std::strcmp(argv[0], "--json");
    Json stages;
    int code = 0;
    auto fail = [&](int c) {
        if (!code)
            code = c;
    };
    // 10 · ScreenCast
    {
        ScreenCast sc(stateDir() + "/session.selftest");
        bool ok = sc.open() && sc.available();
        sc.close();
        ::unlink((stateDir() + "/session.selftest").c_str());
        stages.set("screencast", ok);
        if (!ok) fail(10);
    }
    // 11 · Wayland: layer-shell + viewporter (fractional-scale optional)
    Wayland wl;
    bool wlOk = wl.connect();
    stages.set("layerShell", wlOk);
    stages.set("fractionalScale", wlOk && wl.fractional != nullptr);
    if (!wlOk) fail(11);
    // 12 · Vulkan device with DMA-BUF import + modifiers (no lsfg-vk here)
    bool vkOk = false;
    int mods = 0;
    if (wlOk) {
        ::setenv("DISABLE_LSFGVK", "1", 1);
        Vk vk;
        vkOk = vk.init(wl.display());
        if (vkOk)
            mods = static_cast<int>(vk.modifiers().size());
        vkOk = vkOk && mods > 0;
        vk.shutdown();
        ::unsetenv("DISABLE_LSFGVK");
    }
    wl.disconnect();
    stages.set("vulkan", vkOk).set("modifiers", mods);
    if (!vkOk) fail(12);
    // 13 · lsfg-vk ≥ 2.0 (implicit layer + CLI)
    bool lsfg = lsfgLayerInstalled() && ::access("/usr/bin/lsfg-vk-cli", X_OK) == 0;
    stages.set("lsfgvk", lsfg);
    if (!lsfg) fail(13);
    // 14 · the DLL
    std::string dll = findLsfgDll();
    stages.set("dll", !dll.empty());
    if (dll.empty()) fail(14);

    static const char* reasons[] = {"", "", "", "", "", "", "", "", "", "",
                                    "niri no ofrece captura de ventanas (org.gnome.Mutter.ScreenCast)",
                                    "sin wlr-layer-shell o viewporter", "sin Vulkan con DMA-BUF y modificadores",
                                    "falta lsfg-vk (sudo pacman -S lsfg-vk)",
                                    "falta lsfg-vk.dll: Lossless Scaling en Steam, rama beta «lsfg-vk»"};
    Json out;
    out.set("version", 1)
        .set("code", code)
        .set("available", code == 0)
        .set("reason", code ? reasons[code] : "")
        .set("stages", stages)
        .set("engines", Json().set("lsfg", code == 0).set("ia", false).set("iaReason", "no integrado (puerta de la fase 11)"))
        .set("dll", dll)
        .set("dllSha256", dll.empty() ? "" : sha256(dll))
        .set("at", static_cast<long long>(::time(nullptr)));
    std::string path = stateDir() + "/selftest.json";
    {
        std::ofstream f(path + ".tmp", std::ios::trunc);
        f << out.dump() << "\n";
    }
    std::rename((path + ".tmp").c_str(), path.c_str());
    if (json)
        std::printf("%s\n", out.dump().c_str());
    else
        std::printf("滑 Nameraka self-test: %s%s\n", code ? "✗ " : "✓ todo listo", code ? reasons[code] : "");
    return code;
}

} // namespace nk
