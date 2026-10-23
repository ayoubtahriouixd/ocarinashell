// 滑 Nameraka — system-wide video frame generation for OcarinaShell (docs/01-ARQUITECTURA §19).
//   nameraka daemon             socket-activated state machine (ocarina-nameraka.socket)
//   nameraka view …             the presenter (child of the daemon; --pattern for tests)
//   nameraka self-test [--json] checks every stage; exit codes 0 ok · 10 no ScreenCast · 11 no layer-shell /
//                               fractional-scale · 12 no Vulkan/DMA-BUF · 13 no lsfg-vk · 14 no Lossless Scaling DLL
#include <cstdio>
#include <cstring>

#include "view/view.hpp"

namespace nk {
int runDaemon(int argc, char** argv);
int runSelfTest(int argc, char** argv);
}

int main(int argc, char** argv) {
    if (argc >= 2 && !std::strcmp(argv[1], "view"))
        return nk::runView(argc - 2, argv + 2);
    if (argc >= 2 && !std::strcmp(argv[1], "daemon"))
        return nk::runDaemon(argc - 2, argv + 2);
    if (argc >= 2 && !std::strcmp(argv[1], "self-test"))
        return nk::runSelfTest(argc - 2, argv + 2);
    std::fprintf(stderr, "uso: nameraka daemon | view … | self-test [--json]\n");
    return 2;
}
