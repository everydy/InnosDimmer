# InnosDimmer

InnosDimmer is a personal macOS menu bar utility for a secondary INNOS 27QA100M display on an M1 Mac connected by direct HDMI.

The app is hardware-first. It must not claim real monitor backlight control until a local DDC/CI write/readback probe verifies that the display can be changed and restored safely. If hardware control is unavailable, the app can reduce perceived brightness with software dimming and must disclose that mode clearly.

## Brightness Modes

- `Hardware DDC`: real monitor brightness control after a successful DDC write/readback probe.
- `Overlay active`: perceived brightness/warmth adjustment through click-through overlay windows.
- `Gamma active`: reserved for a scoped, reversible gamma path.
- `Platform blocked`: macOS or the target surface prevents reliable dimming. This is a disclosed limitation, not success.

On M1 direct HDMI, hardware DDC is unverified until the local probe succeeds. The current default DDC adapter is intentionally safe and does not perform real IOKit monitor writes.

## Implemented Scope

- Native macOS menu bar app shell.
- Display identity and target selection persistence.
- Brightness state, command, and hardware/software routing policy.
- Inactive software dimming path with overlay appearance and platform-blocked state.
- Safe DDC probe state machine and hardware strategy abstraction.
- Time-table schedule engine with manual override until the next schedule boundary.
- Custom global shortcut defaults, validation, conflict detection, and Carbon EventHotKey registration backend.
- Login item wrapper using `SMAppService` where available.
- Diagnostics events, snapshots, JSON export, and verification matrix guardrails.

## Current Limitations

- Real DDC/CI transport for the INNOS monitor still needs a reviewed IOKit adapter before hardware brightness can be empirically verified.
- Manual QA is still required for full-screen Spaces, presentation mode, DRM/protected playback, screen sharing/recording, sleep/wake, HDMI reconnect, and global shortcut behavior.
- The app must not claim all requested dimming contexts are handled unless `VerificationMatrix.canClaimAllRequestedContextsHandled` returns true for complete rows with notes.

## Local Verification

The repository intentionally has no third-party package dependencies.

Current compiler-level verification:

```bash
SDK=$(xcrun --show-sdk-path --sdk macosx)
rm -rf /tmp/InnosDimmerModule
mkdir -p /tmp/InnosDimmerModule
xcrun swiftc -sdk "$SDK" -parse-as-library -enable-testing -emit-module -module-name InnosDimmer -emit-module-path /tmp/InnosDimmerModule/InnosDimmer.swiftmodule $(find InnosDimmer -name '*.swift' | sort)
DEV=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer
xcrun swiftc -sdk "$SDK" -I "$DEV/usr/lib" -F "$DEV/Library/Frameworks" -I /tmp/InnosDimmerModule -typecheck $(find InnosDimmerTests -name '*.swift' | sort)
```

`xcodebuild` is not currently the verification source on this machine because the local Xcode install is failing while loading IDE plug-ins.

## QA Handoff

Use [docs/qa-matrix.md](docs/qa-matrix.md) as the manual QA checklist. Use [docs/operator-guide.md](docs/operator-guide.md) for local operation notes and [docs/ddc-probe-notes.md](docs/ddc-probe-notes.md) for hardware probe policy.

## Planning References

- Plan-first implementation document: `/Users/moonsoo/projects/Chat-Bot/docs/superpowers/plans/2026-06-18-external-monitor-brightness-app-plan.md`
- Hardware probe policy and M1 HDMI assumptions: [docs/ddc-probe-notes.md](docs/ddc-probe-notes.md)
- Full-context manual evidence checklist: [docs/qa-matrix.md](docs/qa-matrix.md)
