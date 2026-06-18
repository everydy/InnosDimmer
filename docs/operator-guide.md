# Operator Guide

## Purpose

InnosDimmer is built for personal use on macOS with an M1 Mac, direct HDMI, and an INNOS 27QA100M secondary monitor.

## Operating Policy

- Use software overlay dimming as the primary and only user-facing dimming path.
- Do not attempt to change the monitor's hardware brightness in normal operation.
- Apply brightness, warmth, schedule, quick disable, and restore commands immediately through the overlay.
- Keep platform-blocked states visible.
- Do not intercept native brightness/media keys in the MVP; use custom global shortcuts.

## Default Schedule

| Time | Brightness | Warmth |
| --- | ---: | ---: |
| 09:00 | 80 | 12 |
| 19:00 | 45 | 32 |
| 23:00 | 25 | 58 |

Manual changes pause automation until the next schedule boundary.

## Default Shortcuts

| Action | Shortcut |
| --- | --- |
| Brightness up | Option + Shift + Up |
| Brightness down | Option + Shift + Down |
| Warmth up | Option + Shift + Right |
| Warmth down | Option + Shift + Left |
| Quick disable overlay | Option + Shift + 0 |
| Restore previous dimming | Option + Shift + R |

## Local QA

1. Run the Debug verification command from the README.
2. Build the Release app from the README.
3. Launch the Release app locally.
3. Complete `docs/qa-matrix.md` with notes for every row.
4. Export diagnostics after testing overlay mode, shortcut conflicts, sleep/wake, and reconnect.

## No Package Dependency Policy

Do not add third-party package dependencies for the MVP. The current code uses AppKit, Foundation, ServiceManagement, and Carbon from the macOS SDK.
