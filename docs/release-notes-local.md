# Local Release Notes

## MVP State

This local MVP contains the menu bar shell, state model, display target persistence, software overlay dimming path, brightness routing, schedule engine, shortcut validation/registration backend, login item wrapper, diagnostics export, and verification matrix guardrails.

## Known Limitations

- Hardware brightness control is intentionally not part of the user-facing MVP.
- Full manual QA is still pending.
- `xcodebuild` verification is blocked on this machine by a local Xcode IDE plug-in loading issue.
- DRM/protected playback must be recorded as pass, partial, or platform-blocked only after local observation.

## Handoff Checklist

| Area | Status | Next evidence |
| --- | --- | --- |
| Compiler/typecheck | passing | Keep running the README command after changes. |
| Software overlay | primary dimming path | Manual visual QA across Spaces and apps. |
| Schedule | engine implemented | Near-future boundary manual check. |
| Shortcuts | validation/backend implemented | Finder, browser, full-screen, presentation manual checks. |
| Login item | wrapper implemented | Manual toggle and relaunch check after signing/entitlement status is known. |
| Diagnostics | snapshot/export implemented | Export after overlay and platform-blocked scenarios. |
| Verification matrix | implemented | Fill every row with evidence notes. |
