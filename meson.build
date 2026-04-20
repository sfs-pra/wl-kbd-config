project(
  'wl-kbd-config',
  'vala',
  version: '0.2.0',
  default_options: ['warning_level=2']
)

subdir('po')

gtk_dep = dependency('gtk+-3.0')

# Install desktop file
install_data(
  'wl-kbd-config.desktop',
  install_dir: join_paths(get_option('datadir'), 'applications')
)

# Install man page
install_data(
  'doc/man1/wl-kbd-config.1',
  install_dir: join_paths(get_option('mandir'), 'man1')
)

# Main executable
executable(
  'wl-kbd-config',
  [
    'src/flag_utils.vala',
    'src/wm_detector.vala',
    'src/wm_config_backup.vala',
    'src/wm_config_modifier.vala',
    'src/settings_state_snapshot.vala',
    'src/main.vala',
    'src/settings_window.vala',
    'src/config.h',
  ],
  dependencies: [gtk_dep],
  install: true,
  c_args: [
    '-DGETTEXT_PACKAGE="wl-kbd-config"',
    '-include', 'src/config.h',
  ]
)

if get_option('tests')
  subdir('tests')
endif
