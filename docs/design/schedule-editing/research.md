# Research

## Goal

Prepare a plan-ready codebase research document for applying the approved `docs/design/schedule-editing/mockup.html` direction to the native Swift/AppKit app.

The current approved UX direction is:

- Keep the popover compact.
- Remove the popover Schedule section's separate `Current` label.
- Remove the ambiguous Schedule title-row `Next` chip; if next-boundary information stays visible, place it inside the status block.
- Render popover schedule rows directly left-aligned under the status block.
- Render popover shortcut hints as aligned rows, table-like without heavy grid decoration.
- Make `Edit schedule` open the app dashboard/window schedule area instead of opening another schedule editor window.
- Treat the app dashboard as the full editing hub for current dimming, automation, schedule rows, shortcuts, diagnostics, and save feedback.
- Keep Settings focused on general preferences and route schedule work to the app window.

Trigger mode: Pre-Plan Research Gate for `plan-first-implementation`.

## Scope And Entry Points

Primary implementation scope:

- `InnosDimmer/UI/MenuBarPopoverView.swift`
  - `MenuBarViewModel`
  - `ScheduleSummaryRowsView`
  - `MenuBarPopoverView.buildLayout()`
  - `AppDashboardViewModel`
  - `AppDashboardWindowController`
- `InnosDimmer/UI/MenuBarController.swift`
  - `perform(_:)`
  - `showAppWindow()`
  - `showScheduleEditor()`
  - `makeSettingsActions()`
  - `makeScheduleEditorActions()`
- `InnosDimmer/UI/SettingsWindowController.swift`
  - schedule summary/navigation copy
  - shortcut table-style editing remains general settings
- `InnosDimmer/UI/ScheduleEditorView.swift`
  - reusable fixed-row schedule editor already exists
- `InnosDimmer/UI/ScheduleEditorWindowController.swift`
  - already exists, but no longer matches the preferred primary flow
- `InnosDimmerTests/MenuBarStateTests.swift`
  - popover view model assertions
  - popover button routing
  - dashboard routing and schedule save tests
  - snapshot capture tests
- `InnosDimmerTests/HotkeyBindingTests.swift`
  - settings schedule navigation routing

Supporting scope:

- `DESIGN.md`
- `docs/design/schedule-editing/mockup.html`
- `InnosDimmer/Domain/ScheduleEntry.swift`
- `InnosDimmer/Domain/ShortcutBinding.swift`
- `InnosDimmer/Domain/SettingsSnapshot.swift`
- `InnosDimmer/Services/DisplayTargetStore.swift`
- `InnosDimmer/Services/ScheduleEngine.swift`
- `InnosDimmerTests/DisplayTargetStoreTests.swift`
- `InnosDimmerTests/ScheduleEngineTests.swift`
- `InnosDimmerTests/SettingsSnapshotTests.swift`

Out of scope:

- Dynamic add/remove schedule rows.
- Schedule engine semantics.
- Persistence schema changes.
- Blue-reduction/gamma implementation changes.
- External design benchmarking; local code and the approved HTML mockup are sufficient evidence for this plan.

## Relevant Files

Files read for this research:

- `/Users/moonsoo/projects/InnosDimmer/DESIGN.md`
- `/Users/moonsoo/projects/InnosDimmer/docs/design/schedule-editing/mockup.html`
- `/Users/moonsoo/projects/InnosDimmer/docs/design/schedule-editing/research.md`
- `/Users/moonsoo/projects/InnosDimmer/docs/2026-06-19-schedule-editing-plan-first.md`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/MenuBarPopoverView.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/MenuBarController.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/ScheduleEditorView.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/ScheduleEditorWindowController.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/SettingsWindowController.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Domain/ScheduleEntry.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Domain/ShortcutBinding.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Domain/SettingsSnapshot.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmerTests/MenuBarStateTests.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmerTests/DisplayTargetStoreTests.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmerTests/ScheduleEngineTests.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmerTests/SettingsSnapshotTests.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmerTests/HotkeyBindingTests.swift`

## Current Behavior

Confirmed current behavior from local code:

- The popover already has the main quick-control structure and fixed AppKit styling:
  - `MenuBarPopoverView.preferredContentSize = NSSize(width: 480, height: 700)`
  - `ProgressTrackView` supports click/drag percentage changes for brightness and blue reduction.
  - `PopoverCommandButton.minimumHeight = 30`, addressing the previous thin-button issue.
- The popover already has an `Edit schedule` command:
  - `MenuBarCommand.openScheduleEditor` exists.
  - `MenuBarCommand.buttonCommands` includes `.openScheduleEditor`.
  - `MenuBarController.perform(_:)` routes `.openScheduleEditor` to `showScheduleEditor()`.
- The popover Schedule section still differs from the latest mockup:
  - It creates a title-row `scheduleNextChip` from `scheduleNextLabel`.
  - It renders `makeSummaryRow(title: "Status", value: automationLabel)`.
  - It renders `makeSummaryRow(title: "Current", value: scheduleSummaryRowsView)`.
  - The latest mockup removes the `Current` label and title-row `Next` chip.
- The popover Shortcuts section still differs from the latest mockup:
  - `MenuBarViewModel.shortcutSummary` returns one multiline string.
  - `MenuBarPopoverView` displays that string in `shortcutSummaryLabel` inside `PopoverContainerView`.
  - The latest mockup wants aligned rows, not a single wrapping text block.
- A reusable fixed-row `ScheduleEditorView` already exists:
  - It renders three fixed schedule rows.
  - It validates `HH:mm` time and `0...100` brightness/blue reduction.
  - It returns sorted `ScheduleEntry` values via `editedSchedule()`.
- A `ScheduleEditorWindowController` already exists:
  - It can save through injected `ScheduleEditorActions.updateSchedule`.
  - It is now at odds with the latest approved flow, where `Edit schedule` should open the app window instead of another window.
- The app dashboard already has inline schedule editing:
  - `AppDashboardWindowController` owns `scheduleEditorView`.
  - `saveScheduleFromEditor(reportsStatus:)` uses `scheduleActions.updateSchedule`.
  - It still shows a summary row labeled `Current` before the editor.
- Settings already routes schedule editing through an action:
  - `SettingsActions.openScheduleEditor` exists.
  - `SettingsWindowController` shows `Open schedule editor`.
  - `MenuBarController.makeSettingsActions()` currently routes this to `showScheduleEditor()`, not `showAppWindow()`.

## Data Flow And Control Flow

Current command flow:

```text
Popover "Edit schedule"
  -> MenuBarPopoverView.openScheduleEditorPressed()
  -> MenuBarActions.perform(.openScheduleEditor)
  -> MenuBarController.perform(.openScheduleEditor)
  -> MenuBarController.showScheduleEditor()
  -> ScheduleEditorWindowController.configure(schedule:)
  -> separate schedule window opens
```

Target command flow from the latest mockup:

```text
Popover "Edit schedule"
  -> MenuBarActions.perform(.openScheduleEditor)
  -> MenuBarController.perform(.openScheduleEditor)
  -> MenuBarController.showAppWindow(focus: schedule area) or showAppWindow()
  -> AppDashboardWindowController.update(...)
  -> dashboard inline schedule editor is visible/editable
```

Current Settings schedule navigation:

```text
Settings "Open schedule editor"
  -> SettingsActions.openScheduleEditor()
  -> MenuBarController.showScheduleEditor()
```

Target Settings schedule navigation:

```text
Settings "Open app window schedule"
  -> SettingsActions.openScheduleEditor() or renamed callback
  -> MenuBarController.showAppWindow(focus: schedule area) or showAppWindow()
```

Current schedule save flow to preserve:

```text
ScheduleEditorView.editedSchedule()
  -> ScheduleEditorActions.updateSchedule([ScheduleEntry])
  -> MenuBarController.saveSchedule(_:)
  -> DisplayTargetStore.saveSchedule(_:)
  -> SettingsSnapshot.replacingSchedule(_:)
  -> scheduleEntries = snapshot.schedule
  -> record(.schedule, "Saved ...")
  -> applyScheduleDecision()
  -> scheduleNextBoundaryTimerIfRunning()
```

The native app must keep this save path. UI code must not call `DisplayTargetStore.saveSchedule(_:)` directly.

## Existing Abstractions And Boundaries

Keep these boundaries:

- `MenuBarCommand` is the UI command vocabulary for popover/dashboard button routing.
- `MenuBarActions` is the AppKit view-to-controller boundary for dimming/navigation commands.
- `ScheduleEditorActions` is the schedule-save boundary for schedule editor surfaces.
- `ScheduleEditorView` owns fixed-row schedule input and parsing.
- `MenuBarController.saveSchedule(_:)` owns runtime schedule side effects after persistence.
- `DisplayTargetStore` owns settings persistence and validation.
- `ScheduleEngine` owns active-entry, next-boundary, pause/resume, and timer decision logic.
- `SettingsWindowController` owns general preferences: display target, shortcuts, login item, diagnostics export, and schedule navigation only.

Implementation should not create a second schedule parser unless it is a read-only formatter for summary rows.

## Side Effects And Integration Points

Schedule edits affect more than visible UI:

- successful saves write the persisted settings snapshot;
- `scheduleEntries` in `MenuBarController` updates;
- diagnostics are recorded;
- current schedule decision may apply a dimming command immediately;
- boundary timers are rescheduled;
- popover/dashboard visible state is refreshed through controller update paths.

Navigation also has user-visible side effects:

- opening the app window calls `NSApp.activate(ignoringOtherApps: true)`;
- currently opening the schedule editor records `Opened schedule editor`;
- after rerouting, diagnostics/copy should avoid implying that a separate schedule window opened.

## Risk To Surrounding Systems

- Removing `scheduleNextLabel` without replacing tests can break `MenuBarStateTests.testMenuBarViewModelUsesStateValues`.
- Keeping `MenuBarCommand.openScheduleEditor` but changing its meaning can make tests named around "schedule editor" stale even if the route is correct.
- Deleting `ScheduleEditorWindowController` immediately would create unnecessary project-file churn and test churn; leaving it unused as fallback is lower risk.
- Shortcut display should not reuse a single multiline label if the goal is stable table-like alignment.
- If `Edit schedule` opens the app window but the dashboard does not show or scroll to the schedule area, the route may technically work but fail the UX goal.
- If the dashboard schedule editor remains below too much content, "open app window schedule area" may feel like a hidden route.
- Settings navigation copy must change with the route; "Open schedule editor" implies the retired separate-window flow.
- Snapshot capture tests can rewrite PNGs; these generated files are already dirty and should be handled intentionally during implementation verification.

## Do Not Duplicate Or Bypass

- Do not duplicate `ScheduleEngine` logic in UI.
- Do not write schedule directly to `UserDefaults` from UI.
- Do not create a second schedule persistence key.
- Do not implement add/remove rows in this plan.
- Do not restore the popover diagnostics block; it was intentionally removed from the compact popover.
- Do not keep a title-row `Next` chip in the popover Schedule section.
- Do not keep a visible `Current` row label in the popover Schedule section.
- Do not make `Edit schedule` open a separate schedule window in the primary command path.
- Do not remove the dashboard's editable current-state brightness/blue-reduction controls.
- Do not rename persisted schema fields outside current code's existing `blueReduction` migration work.

## Open Questions

- Should `ScheduleEditorWindowController` be removed entirely or kept as an unused fallback for now?
  - Recommendation for this plan: keep the file and tests only if doing so lowers churn, but remove it from the primary route. A later cleanup can delete it.
- Should the app window scroll directly to the schedule section after opening?
  - Recommendation: yes if AppKit implementation can do it narrowly; otherwise open the dashboard and place the schedule editor high enough to be visible without scrolling.
- Should `MenuBarCommand.openScheduleEditor` be renamed to `openScheduleInAppWindow`?
  - Recommendation: not in the first commit unless tests become confusing. A user-facing route can change while keeping the command name as an internal compatibility bridge.

## Plan Implications

Plan-ready implications:

- Treat the current codebase as partially implemented, not greenfield.
- Start with popover presentation changes because they are the user's latest feedback and have narrow blast radius.
- Change command routing so `.openScheduleEditor` opens the app dashboard, not `ScheduleEditorWindowController`.
- Keep schedule save behavior centralized through `ScheduleEditorActions` and `MenuBarController.saveSchedule(_:)`.
- Update Settings copy and route to "Open app window" / "Open app window schedule" semantics.
- Update tests to reflect the new route and popover presentation:
  - remove or revise `scheduleNextLabel` expectations;
  - assert shortcut rows remain aligned/readable via a test-facing representation;
  - assert `.openScheduleEditor` does not apply dimming and results in app-window route behavior;
  - preserve existing schedule save tests for dashboard inline editing.

Suggested AppKit shape for popover schedule status:

```swift
// Proposed, illustrative only.
private let scheduleStatusTitleLabel = NSTextField(labelWithString: "")
private let scheduleStatusDetailLabel = NSTextField(labelWithString: "")

let schedule = makeSection(
    title: "Schedule",
    trailing: nil,
    views: [
        PopoverContainerView(style: .subtle, content: makeScheduleStatusView()),
        scheduleSummaryRowsView,
        makeActionRow([
            button("Edit schedule", command: .openScheduleEditor, action: #selector(openScheduleEditorPressed), style: .primary),
            automationActionButton
        ]),
        statusField("Edit schedule opens the app window schedule area.")
    ]
)
```

Suggested AppKit shape for shortcut rows:

```swift
// Proposed, illustrative only.
private final class ShortcutSummaryRowsView: NSView {
    func update(shortcuts: [ShortcutBinding]) {
        // four focused rows:
        // Brightness up/down, Blue up/down
        // left column: action label
        // right column: aligned keycap label
    }
}
```

Suggested routing change:

```swift
// Proposed, illustrative only.
case .openScheduleEditor:
    showAppWindow(focus: .schedule)
```

If focus support is too broad for this pass, the safer first implementation is:

```swift
case .openScheduleEditor:
    showAppWindow()
```

## Source Evaluation

| Source | Claim used | Quality | Decision | Notes |
| --- | --- | --- | --- | --- |
| `docs/design/schedule-editing/mockup.html` | Latest approved UX direction for popover schedule, shortcut rows, app-window route, settings role. | A, local approved artifact | Adopt | This is the primary source of truth for visual/flow changes. |
| `DESIGN.md` | Popover should be compact, dense, quick-control oriented; long schedule/shortcut/diagnostics should be summarized. | A, local design contract | Adopt | Supports removing extra labels and keeping schedule editing out of the popover. |
| `MenuBarPopoverView.swift` | Actual current AppKit implementation and mismatches with mockup. | A, local code | Adopt | Defines implementation targets and existing reusable classes. |
| `MenuBarController.swift` | Current command routing and schedule save side effects. | A, local code | Adopt | Confirms route change must preserve `saveSchedule(_:)` path. |
| `ScheduleEditorView.swift` | Existing fixed-row editor and validation. | A, local code | Adopt | Avoids re-planning a greenfield editor. |
| `MenuBarStateTests.swift` and `HotkeyBindingTests.swift` | Current test surface and expected regressions. | A, local tests | Adopt | Determines required verification updates. |
| External design/web sources | Not needed for this request. | Not used | Skip | The user approved the local mockup; no fast-changing external facts affect this plan. |

## Evidence

Commands run on 2026-06-19:

- `rg --files`
- `find .. -name AGENTS.md -print`
- `git status --short`
- `rg -n "Popover|popover|Schedule|schedule|Shortcut|shortcut|Diagnostics|Settings|App window|Dashboard|Quick disable|Restore previous|Open app window|Brightness|Blue reduction|Current" .`
- `rg -n "openScheduleEditor|scheduleNextLabel|scheduleSummaryForTesting|shortcutSummaryForTesting|ScheduleEditor|AppDashboard|SettingsWindow" InnosDimmerTests InnosDimmer/UI`
- `sed -n ...` reads for the files listed in `Relevant Files`.

Confirmed dirty state before writing this research:

```text
 M docs/design/popover-redesign/captures/actual-dark.png
 M docs/design/popover-redesign/captures/actual-light.png
 M docs/design/popover-redesign/captures/dashboard-dark.png
 M docs/design/popover-redesign/captures/dashboard-light.png
 M docs/design/schedule-editing/mockup.html
```

No external web research was used. Local code and approved design artifacts were sufficient.
