# wl-kbd-config

`wl-kbd-config` is a GTK3 configuration tool for keyboard layouts and layout switching in Wayland sessions.

It started as a `labwc` helper, but now supports multiple Wayland window managers:

- labwc
- sway
- wayfire
- river
- hyprland

## What it does

- edit the configured layout list
- reorder layouts
- choose a predefined switching shortcut
- set a custom XKB option
- preview the resulting `XKB_DEFAULT_LAYOUT` and `XKB_DEFAULT_OPTIONS`
- apply settings to `labwc` directly through `~/.config/labwc/environment`
- apply settings to supported WM config files with automatic backup creation

## Screenshots

Add layouts dialog:

![Add layouts dialog](snapshot/add.png)

Switching and preview section:

![Switching and preview](snapshot/key.png)

## Current behavior

- The top subtitle shows the detected WM.
- The main window is simplified to the editable sections only.
- Preview lines are selectable, so you can copy the generated values.
- `Cancel` restores the state captured when the window was opened.
- `Apply` keeps the window open.
- `Close` closes the window.

## Backup and migration

Before modifying a supported WM configuration, `wl-kbd-config` creates a backup in:

```text
~/.config/wl-kbd-config/backups/
```

If an older `labwc-kbd` backup directory exists, the application migrates it to the new location when possible.

For managed config blocks, the writer now emits:

```text
# BEGIN wl-kbd-config
...
# END wl-kbd-config
```

Old `labwc-kbd` managed blocks are removed automatically during rewrite.

## Build

```bash
meson setup build --prefix=/usr
meson compile -C build
```

Tests:

```bash
meson setup build --prefix=/usr -Dtests=true
meson test -C build
```

## Install

```bash
DESTDIR=/tmp/pkg meson install -C build
```

Or package it with Arch `makepkg` using the provided `PKGBUILD`.

## Runtime requirements

- `wl-kbd-assets` for flag icons and keyboard layout catalog
- `gtk3`
- `libxkbcommon`

## Notes

- For `labwc`, the tool edits `~/.config/labwc/environment`.
- For other supported WMs, it can patch their config files directly after confirmation.
- The project gettext domain is `wl-kbd-config`.
