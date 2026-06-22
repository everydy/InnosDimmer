# Contributing

InnosDimmer is a personal macOS utility with a narrow hardware target: an M1 Mac connected over HDMI to an INNOS 27QA100M display.

## What Fits

- focused bug reports with macOS version, display setup, and exact reproduction steps
- documentation fixes
- small reliability improvements for overlay dimming, gamma restore, diagnostics, or shortcut handling
- tests that preserve the current software-only dimming contract

## What Is Out Of Scope

- hardware DDC/CI brightness control
- broad multi-monitor product expansion
- package dependency additions for the MVP
- changes that claim full-screen, DRM, screen-sharing, sleep/wake, or reconnect support without manual evidence in `docs/qa-matrix.md`

## Local Checks

Run the Debug verification command before proposing implementation changes:

```bash
xcodebuild -scheme InnosDimmer -configuration Debug build-for-testing CODE_SIGNING_ALLOWED=NO
```

Run the Release build before manual app QA:

```bash
xcodebuild -scheme InnosDimmer -configuration Release build CODE_SIGNING_ALLOWED=NO
```

## Pull Request Expectations

- Keep changes scoped and explain the display/macOS surface tested.
- Update `docs/qa-matrix.md` only with concrete observed evidence.
- Do not add third-party package dependencies without a separate design decision.
- Preserve the distinction between perceived brightness dimming and hardware backlight control.
