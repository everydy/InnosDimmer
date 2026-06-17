# Local Release Notes

## MVP State

This local MVP contains the menu bar shell, state model, display target persistence, software dimming base path, DDC probe policy, brightness routing, schedule engine, shortcut validation/registration backend, login item wrapper, diagnostics export, and verification matrix guardrails.

## Known Limitations

- Real IOKit DDC transport is not yet implemented.
- Full manual QA is still pending.
- `xcodebuild` verification is blocked on this machine by a local Xcode IDE plug-in loading issue.
- DRM/protected playback must be recorded as pass, partial, or platform-blocked only after local observation.

## Handoff Checklist

| Area | Status | Next evidence |
| --- | --- | --- |
| Compiler/typecheck | passing | Keep running the README command after changes. |
| Hardware DDC | adapter pending | Implement and review real IOKit adapter, then probe INNOS over HDMI. |
| Software overlay | implemented base path | Manual visual QA across Spaces and apps. |
| Schedule | engine implemented | Near-future boundary manual check. |
| Shortcuts | validation/backend implemented | Finder, browser, full-screen, presentation manual checks. |
| Login item | wrapper implemented | Manual toggle and relaunch check after signing/entitlement status is known. |
| Diagnostics | snapshot/export implemented | Export after probe and platform-blocked scenarios. |
| Verification matrix | implemented | Fill every row with evidence notes. |
