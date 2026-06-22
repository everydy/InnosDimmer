# InnosDimmer

![Platform](https://img.shields.io/badge/platform-macOS-111827)
![Swift](https://img.shields.io/badge/Swift-AppKit-f97316)
![Dependencies](https://img.shields.io/badge/dependencies-none-16a34a)
![Status](https://img.shields.io/badge/status-personal%20utility-2563eb)

InnosDimmer is a personal macOS menu bar utility for software-based dimming on an external INNOS 27QA100M display.

It reduces perceived brightness with click-through overlay windows and reduces blue output with a CoreGraphics gamma table on the selected external display. It does not attempt hardware DDC/CI monitor brightness control in normal operation.

<p align="center">
  <img src="docs/assets/innos-dimmer-app-icon-v5-source.png" alt="InnosDimmer app icon" width="128">
</p>

## Highlights

- Native macOS menu bar app built with AppKit and Swift.
- Software-only brightness command routing.
- Click-through overlay dimming for perceived brightness.
- Gamma-based blue reduction with restore safeguards.
- Display identity and selected-target persistence.
- Time-table schedule engine with manual override until the next schedule boundary.
- Custom global shortcut validation and Carbon `EventHotKey` registration.
- Diagnostics events, snapshots, Settings-window JSON export, and verification matrix guardrails.

## Dimming Modes

- `Software dimming ready`: no dimming command has been applied yet.
- `Overlay active`: perceived brightness adjustment through click-through overlay windows, with gamma-based blue reduction when configured.
- `Gamma active`: gamma-only mode is not currently exposed as a separate user path.
- `Platform blocked`: macOS or the target surface prevents reliable dimming. This is a disclosed limitation, not success.

Historical DDC/CI probe notes are archived in [docs/ddc-probe-notes.md](docs/ddc-probe-notes.md). They are not part of the current user-facing runtime.

## Current Limitations

- This app changes perceived brightness, not the monitor backlight.
- Manual QA is still required for full-screen Spaces, presentation mode, DRM/protected playback, screen sharing/recording, sleep/wake, HDMI reconnect, and global shortcut behavior.
- The app must not claim all requested dimming contexts are handled unless `VerificationMatrix.canClaimAllRequestedContextsHandled` returns true for complete rows with notes.
- Gamma/color-table dimming is used only for blue reduction and should restore the original table when cleared.

## Local Verification

The repository intentionally has no third-party package dependencies.

Current Xcode verification:

```bash
xcodebuild -scheme InnosDimmer -configuration Debug build-for-testing CODE_SIGNING_ALLOWED=NO
xcodebuild -scheme InnosDimmer -configuration Release build CODE_SIGNING_ALLOWED=NO
```

Use the Debug command after implementation changes. Use the Release command before launching the local app for manual QA.

## Manual QA

Read the public tutorial at [everydy.github.io/InnosDimmer](https://everydy.github.io/InnosDimmer/) for the basic usage flow, shortcuts, status meanings, and release-readiness cautions.

Use [docs/qa-matrix.md](docs/qa-matrix.md) as the manual QA checklist. Use [docs/operator-guide.md](docs/operator-guide.md) for local operation notes.

Diagnostics export lives in `Settings` under the `Diagnostics` section as `Export diagnostics`. Use it after a successful dimming command and after any observed blocked/failed scenario.

## Repository Map

- [DESIGN.md](DESIGN.md): current product and UI design contract.
- [docs/operator-guide.md](docs/operator-guide.md): local operation policy and shortcuts.
- [docs/qa-matrix.md](docs/qa-matrix.md): manual scenario checklist.
- [research.md](research.md): software-only dimming research basis.
- [docs/ddc-probe-notes.md](docs/ddc-probe-notes.md): archived hardware probing notes.

## Security

Please read [SECURITY.md](SECURITY.md) before reporting vulnerabilities or sharing diagnostics. Do not post private diagnostics, display identifiers, local paths, or crash data in public issues.

## Contributing

This is a personal utility with a narrow hardware target. Small issues, documentation fixes, and careful bug reports are welcome, but broad product expansion is intentionally out of scope. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

No open-source license is currently granted. All rights are reserved unless a license file is added later.
