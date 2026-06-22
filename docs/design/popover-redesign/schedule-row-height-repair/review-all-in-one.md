# Review All In One: Schedule Row Height Regression

## Short Explanation

The production popover schedule table regressed visually after the schedule rows were changed from separate cards into one table.

The first schedule row can absorb extra vertical space, making the schedule table look broken even though the text, commands, and nonblank snapshot tests still pass.

## Findings

### Blocker: Schedule row height is under-constrained

- Evidence:
  - User screenshot: `/var/folders/br/bx40ljsn1pj62x96mn28yjjr0000gn/T/TemporaryItems/NSIRD_screencaptureui_efuWGh/스크린샷 2026-06-22 오후 3.11.21.png`
  - `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/MenuBarPopoverView.swift`
- Cause:
  - `ScheduleSummaryRowsView.rowView(for:)` used `container.heightAnchor.constraint(greaterThanOrEqualToConstant: 34)`.
  - In the fixed-height popover layout, AppKit can assign extra vertical room to one arranged subview.
  - The first arranged schedule row becomes much taller than the following rows.
- Required fix:
  - Use an exact row height for schedule rows.
  - Add a regression test that measures actual row frames after layout, not just identifiers or visible text.

### Important: Existing tests did not catch the visual failure

- Existing tests checked:
  - schedule table identifiers
  - visible text
  - overall popover fitting size
  - nonblank snapshots
- Missing test:
  - per-row equal height after AppKit layout.

### Minor: Capture refresh alone is insufficient as a gate

- Snapshot files changed and rendered nonblank, but this did not prevent a human-visible row distribution issue.
- Capture review remains useful, but must be paired with a structural layout assertion.

## Next Task

- Add a row-height testing API scoped to `ScheduleSummaryRowsView`.
- Change the row height constraint from `>= 34` to `== 34`.
- Assert all three default schedule rows are `34pt ± 1pt`.
- Refresh popover captures after tests pass.
