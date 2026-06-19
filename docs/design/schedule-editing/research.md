# Research

## Goal

Define a plan-ready UX and implementation direction for making schedule editing easier without overloading the menu bar popover or duplicating settings persistence logic.

The user intent is:

- The popover should expose a clear schedule entry point, not inline full schedule editing.
- A dedicated schedule window should open from that entry point and focus only on schedule editing.
- The app dashboard window should allow schedule editing inline without requiring a separate click into settings.
- The existing Settings window should stop being the main place for schedule editing, or should demote schedule editing to a secondary entry point.

## Scope And Entry Points

Local scope:

- Menu bar popover: `InnosDimmer/UI/MenuBarPopoverView.swift`
- Menu command routing: `MenuBarCommand`, `MenuBarActions`, `MenuBarController.perform(_:)`
- Dashboard window: `AppDashboardWindowController` in `InnosDimmer/UI/MenuBarPopoverView.swift`
- Settings window schedule fields: `InnosDimmer/UI/SettingsWindowController.swift`
- Schedule model and persistence: `ScheduleEntry`, `SettingsSnapshot`, `DisplayTargetStore`
- Runtime schedule decisions: `ScheduleEngine`, `ScheduleTimerController`, `MenuBarController.saveSchedule(_:)`

External scope:

- Apple HIG component guidance for popovers, sliders, pickers, and settings-like native controls. These are official but the browsed pages require JavaScript, so the adoption decision uses them as directional support rather than detailed implementation law.

Out of scope for this plan:

- Changing the schedule engine semantics.
- Adding calendar/date recurrence beyond time-of-day entries.
- Changing gamma/overlay dimming behavior.
- Reworking shortcut editing.

## Relevant Files

- `DESIGN.md`
- `docs/design-decisions.md`
- `docs/design/popover-redesign/mockup.html`
- `docs/design/settings-redesign/mockup.html`
- `InnosDimmer/UI/MenuBarPopoverView.swift`
- `InnosDimmer/UI/MenuBarController.swift`
- `InnosDimmer/UI/SettingsWindowController.swift`
- `InnosDimmer/Domain/ScheduleEntry.swift`
- `InnosDimmer/Domain/SettingsSnapshot.swift`
- `InnosDimmer/Services/DisplayTargetStore.swift`
- `InnosDimmer/Services/ScheduleEngine.swift`
- `InnosDimmerTests/MenuBarStateTests.swift`
- `InnosDimmerTests/ScheduleEngineTests.swift`
- `InnosDimmerTests/SettingsSnapshotTests.swift`
- `InnosDimmerTests/DisplayTargetStoreTests.swift`

## Current Behavior

The current user-visible behavior has three surfaces:

- Popover:
  - Shows schedule summary and next schedule chip.
  - Offers `Quick disable`, `Restore previous`, `Pause automation`, `Open app window`, and `Settings`.
  - Does not open a schedule-only editor.
- App dashboard:
  - Shows current schedule as a summary row.
  - Already supports direct brightness/blue-reduction controls and several action buttons.
  - Does not directly edit schedule entries.
- Settings window:
  - Contains display target, schedule, global shortcuts, login item, diagnostics export, and status feedback in one scrollable form.
  - Schedule editing is hard-coded to three rows through `Layout.scheduleEntryCount = 3`.
  - Saving schedule uses `SettingsActions.updateSchedule`.

The current schedule data model is simple and stable:

- `ScheduleEntry` stores `id`, `minuteOfDay`, `brightness`, and `warmth`.
- `SettingsSnapshot` stores `[ScheduleEntry]`.
- `DisplayTargetStore.saveSchedule(_:)` validates and persists the schedule.
- `MenuBarController.saveSchedule(_:)` updates `scheduleEntries`, records diagnostics, applies the current schedule decision, and reschedules the boundary timer.

## Data Flow And Control Flow

Current schedule save flow:

```text
SettingsWindowController.saveSchedulePressed()
  -> scheduleFromFields()
  -> SettingsActions.updateSchedule(schedule)
  -> MenuBarController.saveSchedule(schedule)
  -> DisplayTargetStore.saveSchedule(schedule)
  -> SettingsSnapshot.replacingSchedule(schedule)
  -> SettingsSnapshot.sortedSchedule(schedule)
  -> DisplayTargetStore.save(validatedSnapshot)
  -> MenuBarController.scheduleEntries = snapshot.schedule
  -> record(.schedule, ...)
  -> applyScheduleDecision()
  -> scheduleNextBoundaryTimerIfRunning()
```

Runtime automation flow:

```text
MenuBarController
  -> ScheduleEngine.decision(at:entries:state:)
  -> apply scheduled BrightnessCommand when active
  -> ScheduleTimerController.scheduleNextBoundary(...)
  -> later boundary fire re-evaluates schedule
```

The plan should keep this flow intact and reuse it from any new UI.

## Existing Abstractions And Boundaries

Use these boundaries:

- `ScheduleEntry` is the schedule row model.
- `SettingsSnapshot` is the persisted settings aggregate.
- `DisplayTargetStore` owns validation and persistence.
- `MenuBarController.saveSchedule(_:)` owns runtime side effects after saving.
- `ScheduleEngine` owns active-entry, next-boundary, manual override, and timer decision logic.
- `SettingsActions.updateSchedule` is already the right closure shape for view controllers that need schedule persistence without owning app runtime.

Potential new boundaries:

- `ScheduleActions` can be a smaller wrapper around `updateSchedule` if a schedule-only controller should not receive display/shortcut/login/diagnostics actions.
- `ScheduleEditorView` or `ScheduleEditorController` should own schedule row UI and parsing so Settings, Schedule window, and dashboard do not each duplicate field parsing.

## Side Effects And Integration Points

Schedule editing is not just persistence. A successful save currently:

- writes UserDefaults through `DisplayTargetStore`;
- updates in-memory `scheduleEntries`;
- records diagnostics;
- applies the current schedule decision immediately;
- reschedules the next boundary timer when running;
- refreshes popover/dashboard state through existing refresh paths.

Any new schedule UI must route through `MenuBarController.saveSchedule(_:)` or an equivalent closure supplied by it. Writing `DisplayTargetStore` directly from a view controller would bypass runtime side effects.

## Risk To Surrounding Systems

- Duplicating schedule parsing in multiple views can create inconsistent validation messages and different accepted input.
- Bypassing `MenuBarController.saveSchedule(_:)` can persist rows without updating the active runtime schedule or timer.
- Adding inline schedule controls to the popover would conflict with the active design decision that the popover is a compact quick-control surface.
- Growing the dashboard window without scroll or stable constraints can reintroduce clipping problems already fixed in earlier dashboard work.
- A schedule-only window that also edits shortcuts/display/login would duplicate the Settings window and weaken the user's requested separation.

## Do Not Duplicate Or Bypass

- Do not duplicate `ScheduleEngine` logic in UI.
- Do not write schedule to `UserDefaults` directly.
- Do not create a second schedule persistence key.
- Do not make the popover a full schedule table.
- Do not keep schedule editing only inside `SettingsWindowController`.
- Do not add schedule controls that fail to call `applyScheduleDecision()` and timer rescheduling indirectly through the controller save path.

## Open Questions

- Should schedule editing stay limited to exactly three rows for the next implementation, matching current `SettingsWindowController`, or should the new schedule editor allow add/remove rows?
  - Recommendation: implement add/remove in the UI only if the persistence and tests are updated in the same commit; otherwise keep three rows for the first cut.
- Should the dedicated schedule window be modal, panel-style, or a normal titled utility window?
  - Recommendation: normal titled utility window, because the user may want to compare it with the app dashboard.
- Should saving a schedule immediately apply the active entry?
  - Current behavior does this; recommendation is to preserve it.

## Plan Implications

Recommended UX split:

1. Popover:
   - Keep summary and next schedule chip.
   - Add a clear `Edit schedule` button in the Schedule section.
   - Keep `Settings` as general settings, not schedule-first.
2. Dedicated Schedule window:
   - New schedule-only editor.
   - Three current rows in v1, with clear future-compatible row controls.
   - Save uses the same runtime save path as Settings.
3. App dashboard:
   - Convert schedule summary into inline editable rows.
   - Keep diagnostics, current state, and action controls visible.
   - Use the shared schedule editor component or helper to avoid divergent behavior.
4. Settings window:
   - Demote schedule editing to a summary plus `Open schedule editor`, or reuse the same schedule editor component if it remains present.

Implementation should introduce schedule command/action routing before changing layout:

```swift
enum MenuBarCommand {
    case openScheduleEditor
    ...
}
```

Then add a schedule-specific controller/view that receives a schedule save closure:

```swift
struct ScheduleEditorActions {
    var updateSchedule: @MainActor ([ScheduleEntry]) -> Result<SettingsSnapshot, Error>
}
```

## Source Evaluation

| Source | Claim used | Evidence lanes | Score | Decision | Local transfer | Do not copy |
| --- | --- | --- | --- | --- | --- | --- |
| `DESIGN.md` | Popover should stay dense, utility-first, and not become full diagnostics/settings surface. | Local design contract | A | Adopt | Directly applies to popover/dashboard/settings roles. | Do not treat this as a ban on a separate schedule window. |
| `docs/design-decisions.md` | Popover is compact quick-control surface; sliders suit continuous dimming values. | Local decision log | A | Adopt | Supports `Edit schedule` entry point instead of full inline popover schedule editor. | Do not overload popover with all schedule rows. |
| `InnosDimmer/UI/SettingsWindowController.swift` | Current schedule editor is embedded in general settings and has a three-row form. | Local code | A | Adopt | Defines the current behavior that must be split/reused. | Do not clone this controller wholesale for schedule-only use. |
| `DisplayTargetStore` + `MenuBarController.saveSchedule(_:)` | Schedule persistence has validation and runtime side effects. | Local code | A | Adopt | Must be the save path for new UI. | Do not write UserDefaults from a new view. |
| Apple HIG Popovers | Popovers are transient and should expose a small amount of functionality. | Official / primary, JS-rendered page discovered via search | B | Adopt directionally | Supports a schedule button in popover rather than inline schedule table. | Do not over-interpret JS-inaccessible page text as detailed layout law. |
| Apple HIG Sliders | Sliders represent adjustable values on a horizontal track. | Official / primary, JS-rendered page discovered via search | B | Adopt directionally | Supports brightness/blue reduction slider rows in schedule editor. | Do not replace exact numeric entry where precision matters. |
| Apple HIG Pickers | Date/time pickers support efficient time selection. | Official / primary, JS-rendered page discovered via search | B | Pilot | Supports using native time entry/picker if AppKit implementation allows. | Do not introduce complex calendar recurrence. |

## Evidence

- Local files read:
  - `DESIGN.md`
  - `docs/design-decisions.md`
  - `docs/design/popover-redesign/mockup.html`
  - `docs/design/settings-redesign/mockup.html`
  - `InnosDimmer/UI/MenuBarPopoverView.swift`
  - `InnosDimmer/UI/MenuBarController.swift`
  - `InnosDimmer/UI/SettingsWindowController.swift`
  - `InnosDimmer/Domain/ScheduleEntry.swift`
  - `InnosDimmer/Domain/SettingsSnapshot.swift`
  - `InnosDimmer/Services/DisplayTargetStore.swift`
  - `InnosDimmer/Services/ScheduleEngine.swift`
  - `InnosDimmerTests/MenuBarStateTests.swift`
  - `InnosDimmerTests/ScheduleEngineTests.swift`
  - `InnosDimmerTests/SettingsSnapshotTests.swift`
  - `InnosDimmerTests/DisplayTargetStoreTests.swift`
- Commands:
  - `rg -n "scheduleSummary|scheduleLabel|Open app window|Settings|Pause automation|makeSummaryRow|makeSection|AppDashboard|MenuBarPopoverView|button\\(" InnosDimmer/UI/MenuBarPopoverView.swift`
  - `rg -n "saveSchedule|scheduleFromFields|ScheduleEntry|ScheduleEngine|schedule" InnosDimmerTests/...`
- Official links:
  - Apple HIG overview: https://developer.apple.com/design/human-interface-guidelines
  - Apple HIG popovers: https://developer.apple.com/design/human-interface-guidelines/popovers
  - Apple HIG sliders: https://developer.apple.com/design/human-interface-guidelines/sliders
  - Apple HIG pickers: https://developer.apple.com/design/human-interface-guidelines/pickers
- Date: 2026-06-19.
