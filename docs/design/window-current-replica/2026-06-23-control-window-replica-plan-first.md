# Plan First: Control Window Replica Alignment

Date: 2026-06-23

## Objective

Make `docs/design/window-current-replica/control-window-replica.html` reflect the current native AppKit control window as captured by the safe visual smoke screenshots.

The replica is not the ideal redesign mockup. It is a current-implementation clone used for visual comparison.

## Skill Routing Manifest

- `review-all-in-one`: identify concrete mismatches between current HTML and native screenshots.
- `research`: inspect codebase and runtime screenshot evidence before editing.
- `plan-first-implementation`: lock the edit strategy before implementation.
- `구현커밋`: implement, verify, and commit.

## Evidence Baseline

Native screenshot source:

```bash
xcodebuild test -scheme InnosDimmer -only-testing:InnosDimmerTests/MenuBarStateTests/testUnifiedAppWindowSafeVisualSmokeRendersNonblankPages CODE_SIGNING_ALLOWED=NO
```

HTML screenshot source:

```js
await import("playwright")
// launch with /Applications/Google Chrome.app/Contents/MacOS/Google Chrome
// viewport: 900x640, deviceScaleFactor: 2
```

System Chrome is used because the Playwright bundled browser is unavailable locally and dependency download is blocked by the supply-chain freeze.

## Implementation Plan

### Unit 1: Correct the replica window frame

Change:

- Remove the visible fake titlebar.
- Make the replica `900x640` with no outer border/radius/shadow.
- Make `.app-body` occupy the full 640px height.

Expected result:

- Sidebar and content start at the same top-left contentView origin as native screenshots.

### Unit 2: Fix page-specific header visibility

Change:

- Add `[hidden] { display: none !important; }`.
- Overview header: `Paused`, `Login item on`.
- Schedule header: `Next 19:00`.
- Diagnostics header: `Export diagnostics`.

Expected result:

- Hidden schedule/diagnostic controls no longer leak into Overview.

### Unit 3: Align Overview values

Change:

- Quick actions chip: `Manual`.
- Action button: `Resume automation`.
- Status schedule: `09:00 · 80% / warmth 12%`.
- Diagnostics: `clear`.

Expected result:

- Overview replica reflects `/tmp/InnosDimmerSafeSmoke/safe-app-window-home.png`.

### Unit 4: Align Display structure and values

Change:

- Add `Mode: Software dimming ready`.
- Use `INNOS 27QA100M`.
- Use `Paused until 19:00`.
- Use Display 1 and primary-screen review safety copy.
- Use field rows for target display details instead of only boxed summary-table rows.

Expected result:

- Display replica reflects `/tmp/InnosDimmerSafeSmoke/safe-app-window-display.png`.

### Unit 5: Align Schedule state and actions

Change:

- Use `Next 19:00`.
- Use `Paused until 19:00`.
- Change bottom action to `Resume automation`.

Expected result:

- Schedule replica reflects paused automation state in `/tmp/InnosDimmerSafeSmoke/safe-app-window-schedule.png`.

### Unit 6: Align Shortcuts, Settings, and Diagnostics details

Change:

- Shortcuts key values become `Up`, `Down`, `Right`, `Left`, `0`, `R`, `P`.
- Checked boxes use green filled styling.
- Diagnostics summary and log text match the safe-smoke output.
- Settings stays a compact Launch at Login page.

Expected result:

- Secondary pages no longer carry stale keycode/log/status copy.

## Verification Checklist

- `xcodebuild test` safe smoke test succeeds.
- HTML capture succeeds through system Chrome.
- `rg` finds the expected current implementation strings.
- `git diff` contains only current-replica docs and HTML changes.

## Commit Strategy

One commit is sufficient because the docs and HTML changes are one cohesive replica-alignment unit.
