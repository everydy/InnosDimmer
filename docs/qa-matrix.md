# InnosDimmer QA Matrix

This matrix tracks requested dimming contexts. Manual visual QA remains pending until the app is exercised against the user's M1 HDMI INNOS setup.

Latest automation-side evidence on 2026-06-18:

- Debug `build-for-testing`: passed.
- Release build: passed.
- Release app launch: `InnosDimmer` process observed running from the Release build path.
- Scenario rows below remain `not tested` until a human-visible note confirms the actual screen behavior.

| Scenario | Current status | Evidence required |
| --- | --- | --- |
| General desktop | not tested | Confirm overlay dims and warms only the selected display. |
| Full-screen Spaces | not tested | Confirm overlay remains visible with allSpaces/stationary behavior. |
| Presentation mode | not tested | Confirm quick disable remains available and overlay does not steal focus. |
| Browser full-screen video | not tested | Confirm perceived dimming affects the user's view. |
| DRM/protected playback | not tested | Mark pass, partial, or platform-blocked with notes. |
| Screen sharing/recording | not tested | Confirm whether overlay appears in shared output or only local view. |
| Sleep/wake | not tested | Confirm overlay target is rebuilt after display reconnect. |
| HDMI reconnect | not tested | Confirm selected display does not silently change. |
| Finder global shortcuts | not tested | Confirm default and customized shortcuts fire outside the app. |
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

## Shortcut Checks

- Default shortcut bindings cover brightness up/down, warmth up/down, quick disable, and restore previous dimming.
- Enabled duplicate shortcuts are validation errors; disabled duplicates are ignored.
- Unsafe bindings without an anchor modifier plus Shift are rejected before registration.
- Native brightness/media key interception remains out of MVP scope.

## Verification Matrix Checks

- Verification matrix rows cover general desktop, full-screen Spaces, presentation, browser full-screen video, DRM/protected playback, screen sharing/recording, sleep/wake, HDMI reconnect, shortcut conflict, and schedule boundary.
- `platformBlocked` is not treated as pass; it can count as handled only with a visible explanatory note.
- The app must not claim every requested context is handled while any row is `notTested` or `fail`.

## Handoff Rule

Do not change a row to `pass`, `partial`, or `platformBlocked` without a concrete note describing the surface, app, display state, and observed behavior. DRM/protected playback may be `platformBlocked`, but only if the limitation is visible in the app and documented here.
