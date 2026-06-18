# InnosDimmer QA Matrix

This matrix tracks requested dimming contexts. Manual visual QA remains pending until the app is exercised against the user's M1 HDMI INNOS setup.

Latest automation-side evidence on 2026-06-18:

- Debug `build-for-testing`: passed.
- Release build: passed.
- Release app launch: `InnosDimmer` process observed running from the Release build path.
- Manual smoke QA on the external `27QA100M` display: popover opened, overlay state was visible, brightness/warmth controls updated state and diagnostics, quick disable/restore worked, Finder-focused global brightness shortcut worked, settings window opened.
- 2026-06-19 Debug `build-for-testing` passed after adding explicit overlay failure diagnostics, stale display resolution, reconnect debounce, Settings diagnostics export, and pending-preview cleanup.
- Scenario rows below remain `not tested` until a human-visible note confirms that exact scenario.

| Scenario | Current status | Evidence required |
| --- | --- | --- |
| General desktop | pass | On 2026-06-18, external `27QA100M` popover showed `Overlay active`; `Brightness down` changed 65% -> 60% and the external screen visibly dimmed while diagnostics updated to the same value. |
| Full-screen Spaces | not tested | Confirm overlay remains visible with allSpaces/stationary behavior. |
| Presentation mode | not tested | Confirm quick disable remains available and overlay does not steal focus. |
| Browser full-screen video | not tested | Confirm perceived dimming affects the user's view. |
| DRM/protected playback | not tested | Mark pass, partial, or platform-blocked with notes. |
| Screen sharing/recording | not tested | Confirm whether overlay appears in shared output or only local view. |
| Sleep/wake | not tested | Confirm overlay target is rebuilt after display reconnect. |
| HDMI reconnect | not tested | Confirm selected display does not silently change. |
| Finder global shortcuts | pass | On 2026-06-18, with Finder focused, `Option + Shift + Down` changed brightness 60% -> 55% and diagnostics updated. |
| Browser global shortcuts | not tested | Confirm shortcuts fire while a browser is focused and do not type characters. |
| Full-screen app shortcuts | not tested | Confirm shortcuts fire in full-screen Spaces. |
| Shortcut conflict recovery | not tested | Confirm duplicate enabled bindings are rejected and user can restore safe defaults. |
| Schedule boundary | not tested | Confirm manual slider changes are not overwritten until the next schedule boundary. |

## Software Routing Checks

- Software dimming activates immediately and does not wait for hardware probing.
- Diagnostics can force software mode through `forcedSoftwareTest`.
- Overlay panels are configured as non-opaque, click-through, all-Spaces, stationary windows.
- Overlay appearance computes separate black dimming opacity and warm tint opacity.
- Hardware DDC/probe source files are removed from the app target; old settings with hardware-era extra keys are covered by a legacy decode test in source.
- Manual controls verified on 2026-06-18: `Brightness down`, `Warmth up`, `Quick disable`, and `Restore previous`.
- Diagnostics export is available from `Settings` -> `Export diagnostics`; manual file-save verification is still pending.

## Shortcut Checks

- Default shortcut bindings cover brightness up/down, warmth up/down, quick disable, and restore previous dimming.
- Enabled duplicate shortcuts are validation errors; disabled duplicates are ignored.
- Unsafe bindings without an anchor modifier plus Shift are rejected before registration.
- Native brightness/media key interception remains out of MVP scope.
- Settings window opened on 2026-06-18 and exposed the expected shortcut/settings surface; shortcut editing was not changed during QA.

## Verification Matrix Checks

- Verification matrix rows cover general desktop, full-screen Spaces, presentation, browser full-screen video, DRM/protected playback, screen sharing/recording, sleep/wake, HDMI reconnect, shortcut conflict, and schedule boundary.
- `platformBlocked` is not treated as pass; it can count as handled only with a visible explanatory note.
- The app must not claim every requested context is handled while any row is `notTested` or `fail`.

## Handoff Rule

Do not change a row to `pass`, `partial`, or `platformBlocked` without a concrete note describing the surface, app, display state, and observed behavior. DRM/protected playback may be `platformBlocked`, but only if the limitation is visible in the app and documented here.
