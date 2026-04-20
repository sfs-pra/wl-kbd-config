test_deps = [
  dependency('glib-2.0'),
  dependency('gio-2.0'),
]

test_exe = executable('test_config_modifier',
  'test_config_modifier.vala',
  '../src/wm_config_modifier.vala',
  '../src/wm_config_backup.vala',
  '../src/wm_detector.vala',
  '../src/flag_utils.vala',
  dependencies: test_deps,
  vala_args: ['--define=UNIT_TEST'],
  c_args: ['-DGETTEXT_PACKAGE="wl-kbd-config"']
)

test('config-modifier', test_exe,
  workdir: meson.current_source_dir()
)

snapshot_test = executable('test_settings_snapshot',
  'test_settings_snapshot.vala',
  '../src/settings_state_snapshot.vala',
  dependencies: test_deps,
  vala_args: ['--define=UNIT_TEST'],
  c_args: ['-DGETTEXT_PACKAGE="wl-kbd-config"']
)

test('settings-snapshot', snapshot_test,
  workdir: meson.current_source_dir()
)
