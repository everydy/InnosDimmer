# InnosDimmer

InnosDimmer is a personal macOS menu bar utility for a secondary INNOS 27QA100M display on an M1 Mac connected by direct HDMI.

The current app is software-overlay only. It reduces perceived brightness and adds warmth with click-through overlay windows on the selected external display. It does not attempt hardware DDC/CI monitor brightness control in normal operation.

## Dimming Modes

- `Software dimming ready`: no dimming command has been applied yet.
- `Overlay active`: perceived brightness/warmth adjustment through click-through overlay windows.
- `Gamma active`: reserved for a future optional experiment; not the current default.
- `Platform blocked`: macOS or the target surface prevents reliable dimming. This is a disclosed limitation, not success.

Historical DDC/CI probe notes are archived in [docs/ddc-probe-notes.md](docs/ddc-probe-notes.md). They are not part of the current user-facing runtime.

## Implemented Scope

- Native macOS menu bar app shell.
- Display identity and target selection persistence.
- Software-only brightness command routing.
- Click-through overlay dimming with separate brightness and warmth appearance.
- Time-table schedule engine with manual override until the next schedule boundary.
- Custom global shortcut defaults, validation, conflict detection, and Carbon EventHotKey registration backend.
- Login item wrapper using `SMAppService` where available.
- Diagnostics events, snapshots, Settings-window JSON export, and verification matrix guardrails.

## Current Limitations

- This app changes perceived brightness, not the monitor backlight.
- Manual QA is still required for full-screen Spaces, presentation mode, DRM/protected playback, screen sharing/recording, sleep/wake, HDMI reconnect, and global shortcut behavior.
- The app must not claim all requested dimming contexts are handled unless `VerificationMatrix.canClaimAllRequestedContextsHandled` returns true for complete rows with notes.
- Gamma/color-table dimming is deferred until overlay QA shows a real need for it.

## Local Verification

The repository intentionally has no third-party package dependencies.

Current Xcode verification:

```bash
xcodebuild -scheme InnosDimmer -configuration Debug build-for-testing CODE_SIGNING_ALLOWED=NO
xcodebuild -scheme InnosDimmer -configuration Release build CODE_SIGNING_ALLOWED=NO
```

Use the Debug command after implementation changes. Use the Release command before launching the local app for manual QA.

## QA Handoff

Use [docs/qa-matrix.md](docs/qa-matrix.md) as the manual QA checklist. Use [docs/operator-guide.md](docs/operator-guide.md) for local operation notes.

Diagnostics export lives in `Settings` under the `Diagnostics` section as `Export diagnostics`. Use it after a successful dimming command and after any observed blocked/failed scenario.

## Planning References

- Software-only implementation plan: [docs/2026-06-18-software-only-dimming-plan.md](docs/2026-06-18-software-only-dimming-plan.md)
- Overlay reliability plan: [docs/2026-06-19-overlay-reliability-plan-first.md](docs/2026-06-19-overlay-reliability-plan-first.md)
- Software-only research basis: [research.md](research.md)
- Archived DDC/CI reference: [docs/ddc-probe-notes.md](docs/ddc-probe-notes.md)
- Full-context manual evidence checklist: [docs/qa-matrix.md](docs/qa-matrix.md)
