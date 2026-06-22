# Research

## Goal

Create the codebase context for safely moving the reviewed current popover mockup changes into the production AppKit menu bar popover.

The target production changes are:

- Render the three schedule summary rows as one compact table-like group, matching `mockup-current.html`.
- Remove the boxed time pill treatment from schedule rows and render time as a plain aligned table cell.
- Preserve equal distribution of the three row values while shifting the group slightly left, as approved in the mockup.
- Increase the weight of the top-level popover section labels: `Quick controls`, `Schedule`, and `Shortcuts`.
- Remove the `ENABLED` badge from the `Shortcuts` section header if the implementation follows the latest comment feedback.

Mode: `research` / Pre-Plan Research Gate.

## Scope And Entry Points

In scope:

- Production menu bar popover layout and visual rendering.
- Current-state popover mockup used for feedback.
- Popover font tokens that control section title weight.
- Tests and capture paths that verify the production popover.

Out of scope:

- App window schedule editor redesign.
- Internal command names such as `blueReduction`.
- Menu bar controller command routing.
- Persistence, settings storage, hotkey registration, and schedule editing logic.

## Relevant Files

- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/MenuBarPopoverView.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/DesignSystem/InnosDesignTokens.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmerTests/MenuBarStateTests.swift`
- `/Users/moonsoo/projects/InnosDimmer/docs/design/popover-redesign/mockup-current.html`
- `/Users/moonsoo/projects/InnosDimmer/docs/design/popover-redesign/mockup-compare.html`
- `/Users/moonsoo/projects/InnosDimmer/docs/design/popover-redesign/captures/actual-dark.png`
- `/Users/moonsoo/projects/InnosDimmer/docs/design/popover-redesign/captures/actual-light.png`

## Current Behavior

### Production AppKit Popover

`MenuBarPopoverView` builds three main sections through `makeSection(title:trailing:views:)`:

- `Quick controls`
- `Schedule`
- `Shortcuts`

The section title is created by `sectionLabel(_:)`, uppercased, and styled with `InnosDesignTokens.Font.popoverSectionLabel`.

The `Shortcuts` section currently passes a trailing compact badge:

```swift
let shortcuts = makeSection(
    title: "Shortcuts",
    trailing: pillBadge("ENABLED", tone: .neutral, compact: true),
    views: [...]
)
```

The latest review comment on `mockup-current.html` says this `ENABLED` badge can likely be removed. The badge is informational only; it does not appear to carry an action, state transition, or command-routing responsibility.

Current token:

```swift
static var popoverSectionLabel: NSFont { app(ofSize: 12, weight: .semibold) }
```

The schedule summary is owned by `ScheduleSummaryRowsView`. It currently:

- Uses a vertical `NSStackView` with `spacing = 6`.
- Creates one `PopoverContainerView(style: .subtle, content: row)` per schedule entry.
- Creates time with `pillLabel(...)`, which uses `BadgePillView`.
- Adds brightness and warmth metric views after the time pill.
- Adds a spacer at the end of each row.

Important current implementation shape:

```swift
private static func rowView(for entry: ScheduleEntry) -> NSView {
    let time = pillLabel(timeLabel(for: entry.minuteOfDay))
    time.widthAnchor.constraint(equalToConstant: 60).isActive = true

    let row = NSStackView(views: [time, brightness, warmth, spacer()])
    row.orientation = .horizontal
    row.alignment = .centerY
    row.spacing = 10

    let container = PopoverContainerView(style: .subtle, content: row)
    return container
}
```

### Current Review Mockup

`mockup-current.html` now expresses the desired schedule summary structure:

```css
.schedule-table {
  overflow: hidden;
  border: 1px solid var(--border);
  border-radius: 7px;
  background: var(--subtle);
}

.schedule-row {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 0;
  align-items: center;
  min-height: 34px;
  padding: 0 18px 0 0;
  background: var(--subtle);
}
```

The mockup removes `time-pill` and uses plain `schedule-time` text in the first column:

```html
<div class="schedule-table">
  <div class="schedule-row">
    <span class="schedule-time">09:00</span>
    <span class="metric"><span class="metric-icon sun">☀</span><span>80%</span></span>
    <span class="metric"><span class="metric-icon thermo"></span><span>12%</span></span>
  </div>
</div>
```

## Data Flow And Control Flow

1. `MenuBarController` creates and updates `MenuBarPopoverView`.
2. `MenuBarPopoverView.update(...)` builds `MenuBarViewModel`.
3. `MenuBarViewModel` derives display strings, schedule summary text, automation title, and shortcut rows.
4. `MenuBarPopoverView.buildLayout()` wires the three top-level sections.
5. `ScheduleSummaryRowsView.update(schedule:)` sorts schedule entries with `SettingsSnapshot.sortedSchedule(schedule)`.
6. Each schedule entry is rendered as a row view.
7. Button actions continue to dispatch through `MenuBarActions` and `MenuBarCommand`.

This production change should only affect step 4 section title font and step 6 schedule row layout.

## Existing Abstractions And Boundaries

- `MenuBarViewModel` owns state-derived copy and must keep `scheduleSummary`, `automationTitle`, and action titles stable.
- `ScheduleSummaryRowsView` owns the visual schedule summary rows inside the popover.
- `PopoverContainerView(style: .subtle)` already owns subtle card background, border, corner radius, and inset behavior.
- `InnosDesignTokens.Font` owns Pretendard AppKit font roles.
- `MenuBarController` owns runtime side effects and should not be changed for this visual layout pass.
- `SettingsSnapshot.sortedSchedule(schedule)` owns schedule order.
- `ShortcutSummaryRowsView` already demonstrates the compact table visual direction and should be treated as the closest production analogue.

## Side Effects And Integration Points

- Snapshot tests write `docs/design/popover-redesign/captures/actual-dark.png` and `actual-light.png`.
- `MenuBarStateTests` includes tests for popover state, command routing, snapshot generation, and visual smoke.
- The private schedule view is not currently strongly asserted as a table structure; captures are the main visual evidence.
- Changing `popoverSectionLabel` affects all popover section headers that use `sectionLabel(_:)`, not app-window section headers.
- Changing schedule summary row layout should not affect schedule editing, persisted schedule entries, or automation behavior.

## Risk To Surrounding Systems

- If the schedule table is built by duplicating `ShortcutSummaryRowsView`, it may accidentally couple shortcut-specific keyboard chip behavior to schedule rows.
- If each row remains a separate `PopoverContainerView`, the approved table effect will not be achieved.
- If the new table view bypasses `SettingsSnapshot.sortedSchedule(schedule)`, row order can regress.
- If `plainSummary` changes, existing accessibility/testing summaries may regress.
- If `popoverSectionLabel` is made too heavy globally, headers can become visually dominant relative to badges and body labels.
- If the `Shortcuts` `ENABLED` badge is removed, any tests or captures that assume the badge text appears must be updated deliberately rather than failing incidentally.
- If row dividers are implemented as full `NSBox` separators without careful constraints, the table can gain extra height and break the preferred popover fit.

## Do Not Duplicate Or Bypass

- Do not bypass `ScheduleSummaryRowsView.update(schedule:)`; update that class instead of building schedule rows in `buildLayout()`.
- Do not bypass `SettingsSnapshot.sortedSchedule(schedule)`.
- Do not rename internal `blueReduction` command or data names.
- Do not change `MenuBarCommand`, `ShortcutAction`, or controller routing for this visual update.
- Do not duplicate top-level section rendering; use `makeSection(...)` and `sectionLabel(_:)`.
- Do not create separate font literals in the view when `InnosDesignTokens.Font.popoverSectionLabel` is the existing abstraction.
- Do not remove the `MANUAL` / `AUTO` quick controls badge as part of the `Shortcuts` badge cleanup; that badge communicates automation state and has a different purpose.

## Open Questions

- No blocking product decision remains. The mockup has approved the table-like schedule row direction.
- The exact title weight may need a visual pass after implementation. Recommended default is `bold` at the existing `12pt` size because the user described the current title layer as too thin and asked for a mockup-level stronger weight.
- The latest comment says the `Shortcuts` `ENABLED` badge can be removed. Recommended default is to remove it from both production and the current-state mockup during implementation, because the badge duplicates static enablement information and competes with the stronger section label.
- The row divider color should start with existing `PopoverPalette.border(for:)`; revise only if the capture looks too strong.

## Plan Implications

- Implement the schedule table inside `ScheduleSummaryRowsView`, not in `MenuBarController`.
- Preserve `plainSummary` output exactly to avoid nonvisual regressions.
- Replace the time pill with a plain label using `InnosDesignTokens.Font.popoverLabel` or a small dedicated helper, `secondaryLabelColor`, and tabular number behavior where available.
- Use a single subtle container for all rows, with a vertical stack and thin dividers between rows.
- Use equal-width row cells to match `repeat(3, minmax(0, 1fr))`.
- Apply the left shift by asymmetrical row content constraints, matching the mockup intent of `padding: 0 18px 0 0`.
- Increase `popoverSectionLabel` from `.semibold` to `.bold` rather than changing each label manually.
- Remove the `Shortcuts` trailing `ENABLED` badge by passing `trailing: nil` for that section, and remove the matching badge from `mockup-current.html` if production sync also updates the review artifact.
- Add or update tests that can catch the new structural intent, then regenerate `actual-dark.png` and `actual-light.png`.

## Source Evaluation

- Local production code: Adopt. This is the primary source for safe implementation boundaries.
- Current-state mockup: Adopt. This is the direct design review artifact approved by the user.
- Existing tests and captures: Adopt. These are the repo's current verification surface.
- External sources: Not used. This is a local AppKit layout and project design-token task; external evidence would not materially improve the plan.

## Evidence

- `rg -n "makeSection|ScheduleSummaryRowsView|schedule-row|schedule-table|popoverSectionLabel" InnosDimmer/UI/MenuBarPopoverView.swift InnosDimmer/UI/DesignSystem/InnosDesignTokens.swift InnosDimmerTests/MenuBarStateTests.swift docs/design/popover-redesign/mockup-current.html -S`
- `sed -n '431,525p' InnosDimmer/UI/MenuBarPopoverView.swift`
- `sed -n '1500,1620p' InnosDimmer/UI/MenuBarPopoverView.swift`
- `sed -n '1370,1450p' InnosDimmer/UI/MenuBarPopoverView.swift`
- `sed -n '48,62p' InnosDimmer/UI/DesignSystem/InnosDesignTokens.swift`
- `sed -n '394,430p' docs/design/popover-redesign/mockup-current.html`
- `git status --short --branch` showed unrelated dirty files in app-window/window-redesign areas; implementation must avoid staging unrelated changes.
