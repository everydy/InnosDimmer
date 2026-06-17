# InnosDimmer QA Matrix

This matrix tracks requested dimming contexts. Commit 5 only implements the inactive software dimming base path, so manual visual QA remains pending.

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

## Commit 5 Checks

- Software dimming code exists but does not activate while hardware state is `notProbed`.
- Diagnostics can force software mode through `forcedSoftwareTest`.
- Overlay panels are configured as non-opaque, click-through, all-Spaces, stationary windows.
- Overlay appearance computes separate black dimming opacity and warm tint opacity.
