# Local Release Notes

## MVP State

This local MVP contains the menu bar shell, state model, display target persistence, software-only overlay dimming path, brightness routing, schedule engine, shortcut validation/registration backend, login item wrapper, diagnostics export, and verification matrix guardrails.

## Known Limitations

- Hardware brightness control is intentionally not part of the user-facing app.
- Full manual QA is still pending.
- `xcodebuild -scheme InnosDimmer -configuration Debug build-for-testing CODE_SIGNING_ALLOWED=NO` is the current compiler/test-build verification source.
- DRM/protected playback must be recorded as pass, partial, or platform-blocked only after local observation.

## Handoff Checklist

| Area | Status | Next evidence |
| --- | --- | --- |
| Compiler/test build | passing | Keep running the Debug `xcodebuild` command after changes. |
| Software overlay | primary dimming path | Manual visual QA across Spaces and apps. |
| Schedule | engine implemented | Near-future boundary manual check. |
| Shortcuts | validation/backend implemented | Finder, browser, full-screen, presentation manual checks. |
| Login item | wrapper implemented | Manual toggle and relaunch check after signing/entitlement status is known. |
| Diagnostics | snapshot/export implemented | Export after overlay and platform-blocked scenarios. |
| Verification matrix | implemented | Fill every row with evidence notes. |
