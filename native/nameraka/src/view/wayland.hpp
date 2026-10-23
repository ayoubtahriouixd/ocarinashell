// Wayland side of the presenter (docs/01-ARQUITECTURA §19 «Presentación encima»): a wlr-layer-shell surface in the
// `overlay` layer, namespace ocarina-nameraka, anchored to the four edges of one output, exclusive zone -1, no keyboard
// and an EMPTY input region (mouse, keyboard and touch keep going to the app below). The buffer is the output's
// physical mode (2880×1800 on the P14s) and wp_viewport maps it onto the logical size niri gives the surface, so each
// buffer pixel lands on one panel pixel (checked with a grim capture of a test pattern).
#pragma once

#include <cstdint>
#include <string>
#include <vector>

struct wl_display;
struct wl_registry;
struct wl_compositor;
struct wl_surface;
struct wl_output;
struct zwlr_layer_shell_v1;
struct zwlr_layer_surface_v1;
struct wp_viewporter;
struct wp_viewport;
struct wp_fractional_scale_manager_v1;
struct wp_fractional_scale_v1;

namespace nk {

struct Output {
    wl_output* wl = nullptr;
    uint32_t name = 0;          // registry name
    std::string connector;      // "eDP-1" (wl_output v4 name event)
    int modeW = 0, modeH = 0;   // current physical mode
    int transform = 0;
    bool done = false;
};

class Wayland {
public:
    bool connect();
    void disconnect();
    // create the overlay surface on the output with that connector name (empty: the first one)
    bool createSurface(const std::string& connector);
    void destroySurface();
    // roundtrip until the layer surface is configured (true) or it was closed / timed out (false)
    bool waitConfigured(int timeoutMs);
    int fd() const;
    bool dispatchPending();     // read + dispatch what is available; false if the connection died
    void flush();

    wl_display* display() const { return display_; }
    wl_surface* surface() const { return surface_; }
    bool configured() const { return configured_; }
    bool closed() const { return closed_; }
    int logicalW() const { return logicalW_; }
    int logicalH() const { return logicalH_; }
    int bufferW() const { return bufferW_; }
    int bufferH() const { return bufferH_; }
    double scale() const { return scale120_ / 120.0; }
    const Output* output() const { return out_; }

    // listeners (public: called from C callbacks)
    std::vector<Output*> outputs;
    wl_compositor* compositor = nullptr;
    zwlr_layer_shell_v1* layerShell = nullptr;
    wp_viewporter* viewporter = nullptr;
    wp_fractional_scale_manager_v1* fractional = nullptr;
    void onConfigure(zwlr_layer_surface_v1* s, uint32_t serial, uint32_t w, uint32_t h);
    void onClosed() { closed_ = true; }
    void onScale(uint32_t s120) { scale120_ = s120; }

private:
    void computeBuffer();
    wl_display* display_ = nullptr;
    wl_registry* registry_ = nullptr;
    wl_surface* surface_ = nullptr;
    zwlr_layer_surface_v1* layer_ = nullptr;
    wp_viewport* viewport_ = nullptr;
    wp_fractional_scale_v1* fscale_ = nullptr;
    const Output* out_ = nullptr;
    bool configured_ = false;
    bool closed_ = false;
    int logicalW_ = 0, logicalH_ = 0;
    int bufferW_ = 0, bufferH_ = 0;
    uint32_t scale120_ = 120;
};

} // namespace nk
