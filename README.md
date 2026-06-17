# InnosDimmer

InnosDimmer is a personal macOS menu bar utility for controlling the perceived brightness and warmth of a secondary INNOS 27QA100M display on an M1 Mac connected by direct HDMI.

The app is hardware-first: it must not claim real backlight control until a local DDC/CI probe verifies write/readback behavior. Software dimming exists as an inactive safety path until the hardware probe ladder is exhausted or diagnostics explicitly forces software mode for testing.

## Current Scope

- Native macOS menu bar app
- No third-party dependencies
- Custom global shortcuts planned
- Time-table schedule planned
- Overlay/gamma software dimming planned
- Hardware DDC probe planned

## Current Status

Commit 1 scaffold only. The app shell should build as an accessory menu bar app without a Dock icon or main document window.
