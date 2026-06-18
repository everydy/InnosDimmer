# Local Release Notes

## MVP State

This local MVP contains the menu bar shell, state model, display target persistence, software-only overlay dimming path, brightness routing, schedule engine, shortcut validation/registration backend, login item wrapper, diagnostics export, and verification matrix guardrails.

## Known Limitations

- Hardware brightness control is intentionally not part of the user-facing app.
- Full manual QA is still pending.
- `xcodebuild -scheme InnosDimmer -configuration Debug build-for-testing CODE_SIGNING_ALLOWED=NO` is the current compiler/test-build verification source.
- `xcodebuild -scheme InnosDimmer -configuration Release build CODE_SIGNING_ALLOWED=NO` passed on 2026-06-18.
- The Release app was observed running from the local Xcode build products path on 2026-06-18.
- Manual smoke QA on 2026-06-18 confirmed menu bar popover opening, visible overlay dimming on `27QA100M`, brightness/warmth command updates, quick disable/restore, Finder-focused brightness shortcut, and settings window opening.
- A narrow `xcodebuild test -only-testing:InnosDimmerTests/SettingsSnapshotTests/testDecodesLegacyHardwareSettingsSnapshot` run was attempted but interrupted after the Xcode test runner stalled during app launch/finalization.
- DRM/protected playback must be recorded as pass, partial, or platform-blocked only after local observation.

## Handoff Checklist

| Area | Status | Next evidence |
| --- | --- | --- |
| Compiler/test build | passing | Keep running the Debug `xcodebuild` command after changes. |
| Release build | passing | Rebuild before each local handoff. |
| Local launch | smoke QA passed | Continue broader scenario QA from `docs/qa-matrix.md`. |
| Software overlay | manual desktop pass | Manual visual QA still needed across Spaces, full-screen apps, video, DRM/protected playback, sharing/recording, sleep/wake, and reconnect. |
| Schedule | engine implemented | Near-future boundary manual check. |
| Shortcuts | Finder smoke pass | Browser, full-screen, presentation, conflict recovery, and customization manual checks. |
| Login item | wrapper implemented | Manual toggle and relaunch check after signing/entitlement status is known. |
| Diagnostics | snapshot/export implemented | Export after overlay and platform-blocked scenarios. |
| Verification matrix | implemented | Fill every row with evidence notes. |
