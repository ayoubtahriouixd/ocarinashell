# 滑 Nameraka — system-wide video frame generation helper (docs/01-ARQUITECTURA §19, fase 11 B).
# One binary, three modes: daemon (socket-activated state machine), view (capture → present), self-test.
project('nameraka', 'cpp',
  version: '0.1.0',
  license: 'GPL-3.0-or-later',
  meson_version: '>=1.4',
  default_options: ['cpp_std=c++20', 'warning_level=3', 'buildtype=release', 'b_ndebug=if-release'])

# development: meson setup build --werror (built-in option)
add_project_arguments('-Wno-missing-field-initializers', language: 'cpp')

wayland_client = dependency('wayland-client')
wayland_scanner = find_program(dependency('wayland-scanner', native: true).get_variable('wayland_scanner'))
vulkan = dependency('vulkan')
pipewire = dependency('libpipewire-0.3', include_type: 'system')
libdrm = dependency('libdrm', include_type: 'system')
sdbus = dependency('libsystemd')
threads = dependency('threads')

wp_dir = dependency('wayland-protocols').get_variable('pkgdatadir')
wlr_dir = dependency('wlr-protocols').get_variable('pkgdatadir')
protocols = {
  'wlr-layer-shell-unstable-v1': wlr_dir / 'unstable/wlr-layer-shell-unstable-v1.xml',
  'viewporter': wp_dir / 'stable/viewporter/viewporter.xml',
  'fractional-scale-v1': wp_dir / 'staging/fractional-scale/fractional-scale-v1.xml',
  'xdg-shell': wp_dir / 'stable/xdg-shell/xdg-shell.xml',
}
proto_src = []
foreach name, xml : protocols
  proto_src += custom_target(name + '-client-header', input: xml, output: name + '-client-protocol.h',
    command: [wayland_scanner, 'client-header', '@INPUT@', '@OUTPUT@'])
  proto_src += custom_target(name + '-code', input: xml, output: name + '-protocol.c',
    command: [wayland_scanner, 'private-code', '@INPUT@', '@OUTPUT@'])
endforeach
add_languages('c', native: false)

core = static_library('nameraka-core',
  'src/core/base_estimator.cpp', 'src/core/multiplier.cpp', 'src/core/state_machine.cpp',
  'src/core/lsfg_toml.cpp', 'src/common/json.cpp', 'src/common/paths.cpp',
  include_directories: include_directories('src'))
core_dep = declare_dependency(link_with: core, include_directories: include_directories('src'))

executable('nameraka',
  'src/main.cpp',
  'src/view/view.cpp', 'src/view/wayland.cpp', 'src/view/vk.cpp', 'src/view/capture.cpp',
  'src/daemon/daemon.cpp', 'src/daemon/niri.cpp', 'src/daemon/screencast.cpp', 'src/daemon/selftest.cpp',
  'src/daemon/calibration.cpp', 'src/daemon/audio.cpp',
  proto_src,
  dependencies: [core_dep, wayland_client, vulkan, pipewire, libdrm, sdbus, threads],
  install: true)

test('core', executable('test-core', 'tests/test_core.cpp', dependencies: [core_dep]))
