# Research: Native Control Window Replica Alignment

Date: 2026-06-23

## Trigger

The current implementation replica did not fully reflect the actual AppKit control window. The user requested capture-based comparison and correction using review, research, plan-first, and implementation flow.

## Sources Checked

### Codebase

- `docs/design/window-current-replica/control-window-replica.html`
- `docs/design/window-current-replica/control-window-compare.html`
- native visual smoke test output under `/tmp/InnosDimmerSafeSmoke/`

### Runtime Evidence

The native screenshots were produced by the existing safe visual smoke test:

```bash
xcodebuild test -scheme InnosDimmer -only-testing:InnosDimmerTests/MenuBarStateTests/testUnifiedAppWindowSafeVisualSmokeRendersNonblankPages CODE_SIGNING_ALLOWED=NO
```

Observed screenshot files:

- `/tmp/InnosDimmerSafeSmoke/safe-app-window-home.png`
- `/tmp/InnosDimmerSafeSmoke/safe-app-window-display.png`
- `/tmp/InnosDimmerSafeSmoke/safe-app-window-schedule.png`
- `/tmp/InnosDimmerSafeSmoke/safe-app-window-shortcuts.png`
- `/tmp/InnosDimmerSafeSmoke/safe-app-window-settings.png`
- `/tmp/InnosDimmerSafeSmoke/safe-app-window-diagnostics.png`

All checked native captures are 1800x1280 PNG files, which corresponds to a 900x640 AppKit content view at 2x scale.

## Key Observations

### Window Model

The smoke screenshots capture only the native `contentView`, not a full decorated macOS window. Therefore, the replica must not render a browser-style or fake AppKit titlebar.

### Header Visibility Model

The native header uses page-specific controls:

- Overview: `Paused`, `Login item on`
- Schedule: `Next 19:00`
- Diagnostics: `Export diagnostics`
- Display, Shortcuts, Settings: no header controls

HTML `hidden` must be explicitly protected with `[hidden] { display: none !important; }` because button display rules can override it.

### Page Content

Overview native content is the paused/manual state, not the ideal active automation state.

Display native content contains:

- `INNOS 27QA100M`
- `Software dimming ready`
- `Paused until 19:00`
- target display row values for Display 1 and primary-screen safety review

Schedule native content contains:

- `Next 19:00`
- `Paused until 19:00`
- full three-row schedule summary
- bottom `Resume automation` and `Save schedule`

Diagnostics native content contains:

- verification summary `Verification: 0/10 handled · handled checks · 0 blocked`
- checkmark-only rows for the core handled items
- safe-smoke diagnostic log text

Shortcuts native content uses human-readable key labels rather than numeric key codes:

- `Up`
- `Down`
- `Right`
- `Left`
- `0`
- `R`
- `P`

## Implementation Hypothesis

Primary hypothesis: The existing replica can be corrected without replacing the full file. The structural shell is close enough; the major mismatch is caused by titlebar modeling, hidden CSS leakage, stale copy, stale state values, and a few page-specific layout choices.

If further mismatch remains after this pass, the next focused step is to generate per-page HTML screenshots and compare them side-by-side against each native PNG.

## Verification Plan

1. Re-run the native safe visual smoke test.
2. Capture the HTML replica with system Chrome at `900x640`, device scale factor 2.
3. Open the resulting screenshot and compare against `/tmp/InnosDimmerSafeSmoke/safe-app-window-home.png`.
4. Verify key text values by `rg`.
5. Commit only after the replica and documentation are updated.
