# Research

## Goal

Prepare the evidence basis for a full redesign of the standalone InnosDimmer app window so the real AppKit window can be rebuilt from `docs/design/window-redesign/app-window-componentized-mockup.html` without losing current runtime behavior.

Trigger mode: `research` Pre-Plan Research Gate.

Target outcome for the later implementation plan:

- Replace the current split `SettingsWindowController` + `AppDashboardWindowController` experience with one app-window surface using the home + detail-page structure from the componentized HTML mockup.
- Remove the standalone settings window after its display, shortcuts, launch-at-login, diagnostics export, verification summary, and transient status behavior are represented inside the app window.
- Preserve existing dimming, display, schedule, shortcut, login item, diagnostics, and command routing behavior.
- Reuse the shared popover/window component language instead of creating another one-off AppKit layout.

## Scope And Entry Points

In scope:

- Static review artifact: `docs/design/window-redesign/app-window-componentized-mockup.html`
- Existing app-window/design notes: `docs/design/window-redesign/feedback.md`
- Product design contract: `DESIGN.md`
- Shared popover/window contract: `docs/design/shared-control-system/contract.md`
- Current Settings window: `InnosDimmer/UI/SettingsWindowController.swift`
- Current dashboard window: `AppDashboardWindowController` inside `InnosDimmer/UI/MenuBarPopoverView.swift`
- Routing merge target: `MenuBarCommand.openSettings`, `MenuBarCommand.openAppWindow`, `MenuBarCommand.openScheduleEditor`, and `MenuBarController.openSettings()`
- Shared tokens/components: `InnosDimmer/UI/DesignSystem/InnosDesignTokens.swift`, `InnosDimmer/UI/DesignSystem/InnosDesignComponents.swift`
- Runtime command and persistence integration through `InnosDimmer/UI/MenuBarController.swift`
- Test boundaries in `InnosDimmerTests/MenuBarStateTests.swift`, `InnosDimmerTests/HotkeyBindingTests.swift`, `InnosDimmerTests/SettingsSnapshotTests.swift`, and `InnosDimmerTests/VerificationMatrixTests.swift`

Out of scope for this research pass:

- Implementing the AppKit redesign.
- Changing dimming algorithms, gamma behavior, overlay behavior, or schedule semantics.
- Adding third-party dependencies.
- Reverting any existing dirty worktree changes.

## Relevant Files

Files read for this research:

- `/Users/moonsoo/projects/InnosDimmer/DESIGN.md`
- `/Users/moonsoo/projects/InnosDimmer/README.md`
- `/Users/moonsoo/projects/InnosDimmer/docs/design/window-redesign/app-window-componentized-mockup.html`
- `/Users/moonsoo/projects/InnosDimmer/docs/design/window-redesign/feedback.md`
- `/Users/moonsoo/projects/InnosDimmer/docs/design/shared-control-system/contract.md`
- `/Users/moonsoo/projects/InnosDimmer/docs/design-components/README.md`
- `/Users/moonsoo/projects/InnosDimmer/docs/design-components/contracts/action-row.md`
- `/Users/moonsoo/projects/InnosDimmer/docs/design-components/contracts/dimming-control-group.md`
- `/Users/moonsoo/projects/InnosDimmer/docs/design/popover-redesign/research.md`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/SettingsWindowController.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/MenuBarPopoverView.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/MenuBarController.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/ScheduleEditorView.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/DesignSystem/InnosDesignTokens.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/DesignSystem/InnosDesignComponents.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmerTests/MenuBarStateTests.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmerTests/HotkeyBindingTests.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmerTests/SettingsSnapshotTests.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmerTests/VerificationMatrixTests.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Services/DisplayTargetStore.swift`

Commands used:

- `rg --files`
- `git status --short`
- `find /Users/moonsoo/projects/InnosDimmer -name AGENTS.md -print`
- `sed -n ...`
- `rg -n ...`

## Current Behavior

The app currently has two separate native window surfaces:

1. `SettingsWindowController`
   - 500 x 620 titled settings window.
   - A single vertical `NSScrollView` form.
   - Owns target display picker, schedule summary/open app window action, shortcut table, launch-at-login checkbox, diagnostics export, verification matrix summary, and transient status label.
   - Uses many direct `NSButton`, `NSTextField`, and `NSStackView` helpers rather than the newer shared design component files.

2. `AppDashboardWindowController`
   - Defined in `MenuBarPopoverView.swift`, not in its own file.
   - 560 x 880 resizable dashboard window with a vertical scroll layout.
   - Shows current state, inline schedule editor, configuration actions, diagnostics text view, and schedule saving.
   - Shares some popover-private primitives such as `PopoverContainerView`, `ProgressTrackView`, `PopoverCommandButton`, and `PopoverPalette`.
   - It is already opened from `MenuBarController.showAppWindow()` and from `openScheduleEditor` with schedule focus.

The current mockup proposes a third shape:

- one 860 x 620 app window
- a Home page
- detail pages: `Current status`, `Display`, `Schedule`, `Shortcuts`, `Settings`, `Diagnostics`
- navigation tiles instead of one long scroll form
- current-state quick actions on Home
- vertical `Next actions` summary list
- tokenized component mapping to shared AppKit components

The mockup is static and does not represent real data binding or real AppKit accessibility/focus behavior.

User decision added after the first research pass:

- The standalone settings window should be removed.
- The app window should absorb the settings-window feature set.
- `Settings` should become an app-window page, not a separate `NSWindowController`.
- `openSettings` should no longer open `SettingsWindowController`; it should route into the unified app window, probably to `.shortcuts` when invoked from the popover `Edit Shortcuts` button and to `.settings` when invoked as a general settings entry.

Latest mockup deltas confirmed in `app-window-componentized-mockup.html`:

- Home now uses `Quick actions`, not `Current snapshot`.
- Home quick-command visible labels are shortened to `Disable`, `Restore`, and `Resume`; the implementation should keep explicit accessibility labels such as `Quick disable overlay`, `Restore previous dimming`, and `Resume automation`.
- Home `Next actions` is a vertical list of only useful summary rows: schedule next row, diagnostics warning count, and shortcut enabled count.
- The navigation tile is titled `Schedule`, but the underlying static page still uses `data-page="automation"` and `<h2>Automation</h2>`. Implementation should normalize the real page name to `Schedule`.
- The Schedule page is now vertically stacked: compact schedule summary first, schedule rows second.
- The Schedule rows table uses a native table-like layout with columns `Time`, `Bright`, and `Warmth`, plus a remove column. Because product vocabulary has moved to blue reduction, production should use `Blue` or `Blue reduction` instead of `Warmth`.
- Each schedule value cell should be one horizontal row: value input, drag/track, then adjacent `-`/`+` buttons. This mirrors the shared `DimmingControlGroup` order while adding direct numeric entry.
- `Pause automation` and `Save schedule` are bottom actions for the Schedule page, not header actions.
- Diagnostics page should display real log rows directly, not a dashboard-style card summary.
- Verification matrix should use a compact score + row list layout, but the data must still come from `VerificationMatrix.summary(for:)` or its row model.

Mockup-to-AppKit translation inventory:

| Mockup area | Existing source | Implementation implication |
| --- | --- | --- |
| Home `Quick actions` | `AppDashboardWindowController` current-state section + `MenuBarPopoverView` quick controls | Rebuild with shared dimming controls and route through `MenuBarActions.perform`. |
| Home `Next actions` | `MenuBarViewModel.scheduleStatusDetail`, diagnostics latest event, `HotkeyManager.summary` | Add an app-window view model that reduces runtime state into three compact rows. |
| Navigation tiles | no native equivalent yet | Add `AppWindowPage` and a tile component, preferably with `InnosDesignTokens` and an `InnosNavigationTileView`. |
| Current status page | `AppDashboardViewModel` labels | Make read-only; do not duplicate Home controls. |
| Display page | `SettingsWindowController.renderDisplayPicker`, `DisplayTargetStore.saveSelectedDisplay` | Move picker behavior into unified window and keep `Use automatic` path as `nil` selected display. |
| Schedule page | `ScheduleEditorView`, `ScheduleEditorActions`, `ScheduleEngine` | Extend or replace `ScheduleEditorView` with a table-like row editor supporting time text, percent text, sliders, and `-`/`+` steppers. |
| Shortcuts page | `SettingsWindowController.makeShortcutStack`, `ShortcutKeyField`, `SettingsActions.updateShortcuts` | Extract shortcut row editor before deleting the settings window. |
| Settings page | `LoginItemController`, `SettingsWindowController.renderLoginItem`, `DisplayTargetStore.load` | Keep launch-at-login side effects behind injected action; show saved-state summary read-only. |
| Diagnostics page | `DiagnosticsStore.events`, `DiagnosticsExporter`, `VerificationMatrix` | Render real event rows and preserve export action. |

Schedule row implementation hypothesis:

```swift
private final class ScheduleValueControl: NSStackView {
    let valueField = NSTextField(string: "")
    let trackView = InnosDimmingTrackView()
    let decrementButton: NSButton
    let incrementButton: NSButton

    init(label: String, target: AnyObject?, decrement: Selector?, increment: Selector?) {
        decrementButton = InnosCommandButton(title: "-", target: target, action: decrement)
        incrementButton = InnosCommandButton(title: "+", target: target, action: increment)
        super.init(frame: .zero)
        orientation = .horizontal
        alignment = .centerY
        spacing = InnosDesignTokens.Spacing.rowGap
        setViews([valueField, trackView, decrementButton, incrementButton], in: .leading)
        setAccessibilityLabel(label)
    }
}
```

That helper should not save directly. It should update an in-memory row model, then the page-level `Save schedule` button should call the existing `ScheduleEditorActions.updateSchedule`.

## Data Flow And Control Flow

Current runtime flow:

1. `AppDelegate.applicationDidFinishLaunching` creates `MenuBarController`.
2. `MenuBarController.start()` loads persisted settings through `DisplayTargetStore`, resolves the display, applies the schedule decision, installs the popover, registers hotkeys, observes screen/wake changes, schedules the next boundary timer, and currently calls `showAppWindow()`.
3. `MenuBarController.perform(_:)` is the central command router for `MenuBarCommand`.
4. `MenuBarController.showAppWindow(focus:)` creates or reuses `AppDashboardWindowController`, injects `MenuBarActions` and `ScheduleEditorActions`, calls `refreshAppWindow()`, and optionally focuses the schedule section.
5. `MenuBarController.openSettings()` configures `SettingsWindowController` with a fresh persisted snapshot, active display candidates, and login item status.
6. `SettingsWindowController` sends durable-setting actions back through `SettingsActions`.
7. `AppDashboardWindowController` sends live command actions through `MenuBarActions` and schedule edits through `ScheduleEditorActions`.
8. Diagnostics flow through `DiagnosticsStore.record(...)`; `MenuBarController.record(...)` also calls `refreshAppWindow()`.

Important consequence:

- The implementation must not create a direct path from a window control to `BrightnessController`, `DisplayTargetStore`, `LoginItemController`, or `DiagnosticsStore`.
- The window should keep using injected actions and `MenuBarController.perform(_:)` / save helpers as the side-effect boundary.

Target unified routing flow:

1. `MenuBarCommand.openAppWindow` should show the unified app window on `.home` or preserve the current page if already visible.
2. `MenuBarCommand.openScheduleEditor` should show the unified app window focused to the Schedule page or the schedule editor region.
3. `MenuBarCommand.openSettings` should stop opening `SettingsWindowController` and should instead show the unified app window on the most relevant page.
4. The current popover button titled `Edit Shortcuts` currently emits `.openSettings`; after unification either:
   - keep `.openSettings` but route it to `.shortcuts`, or
   - introduce a more specific command such as `.openShortcuts` and update tests.
5. The current dashboard `Settings` button also emits `.openSettings`; after unification it should route to `.settings` or be replaced by page navigation.
6. `SettingsActions` should be moved from `SettingsWindowController` ownership to unified app-window ownership, then optionally renamed to clarify that these are durable settings actions rather than a separate settings-window action bundle.

Proposed routing API shape:

```swift
@MainActor
enum AppWindowFocusTarget {
    case home
    case current
    case display
    case schedule
    case shortcuts
    case settings
    case diagnostics
}
```

Routing should not depend on the old static HTML name `automation`; use `.schedule` everywhere in Swift and treat `data-page="automation"` as mockup residue.

```swift
private func showAppWindow(focus: AppWindowFocusTarget? = nil) {
    let controller = appWindowController ?? AppWindowController(
        actions: makeAppWindowActions()
    )
    appWindowController = controller
    refreshAppWindow()
    controller.showWindow(nil)
    controller.focus(focus)
    NSApp.activate(ignoringOtherApps: true)
}
```

```swift
private func openSettings() {
    record(.appLifecycle, "Opened settings page")
    showAppWindow(focus: .settings)
    refreshPopover()
}
```

If the popover `Edit Shortcuts` control keeps using `.openSettings`, the implementation should route that specific button through a more specific action/command so it lands on the Shortcuts page instead of the generic Settings page.

Recommended command split for planning:

```swift
enum MenuBarCommand: Equatable, Hashable {
    case openAppWindow
    case openScheduleEditor
    case openShortcuts
    case openSettings
    case openDiagnostics
    // existing dimming and automation cases stay unchanged
}
```

This keeps existing behavior readable:

- `Open Control Window` -> `.openAppWindow` -> `.home`
- `Edit schedule` -> `.openScheduleEditor` -> `.schedule`
- `Edit Shortcuts` -> `.openShortcuts` -> `.shortcuts`
- generic Settings tile/button -> `.openSettings` -> `.settings`
- diagnostics warning/action -> `.openDiagnostics` -> `.diagnostics`

## Existing Abstractions And Boundaries

Reusable domain/runtime boundaries:

- `BrightnessState` is the current UI state source for display, brightness, blue reduction, mode, automation pause, and command source.
- `SettingsSnapshot` is the durable state schema for selected display, brightness state, schedule, and shortcuts.
- `DisplayTargetStore` owns persistence and legacy migration.
- `ScheduleEngine` owns active row, next boundary, manual override, pause, and resume semantics.
- `ShortcutBinding` and `HotkeyManager` own shortcut normalization and registration.
- `LoginItemController` owns launch-at-login integration.
- `DiagnosticsStore`, `DiagnosticsExporter`, and `VerificationMatrix` own diagnostics state and exportable summaries.

Reusable UI/design boundaries:

- `InnosDesignTokens` defines shared colors, spacing, font, radius, and sizing primitives.
- `InnosDesignComponents` currently provides:
  - `InnosSectionView`
  - `InnosStatusChipView`
  - `InnosCommandButton`
  - `InnosDimmingTrackView`
  - `InnosDimmingControlGroupView`
  - `InnosComponentFactory.section`
  - `InnosComponentFactory.actionRow`
  - `InnosComponentFactory.summaryRow`
- `docs/design-components/README.md` states the popover is the canonical control surface and the app window should not invent a different visual language.
- `docs/design/shared-control-system/contract.md` identifies `SectionShell`, `StatusChip`, `DimmingControlGroup`, `ActionRow`, `SummaryRow`, `OpsStrip`, `NavigationTile`, `DiagnosticsRow`, and `FooterStatus` as the preferred component priority.

Current duplication risk:

- `MenuBarPopoverView.swift` has private equivalents of several now-shared concepts: `PopoverPalette`, `PopoverContainerView`, `ProgressTrackView`, `PopoverCommandButton`, and app-dashboard helper methods.
- `SettingsWindowController.swift` has older ad hoc helpers and does not use `InnosDesignComponents`.
- The full redesign should avoid creating a third set of helpers inside the window controller.

Settings-window removal boundary:

- `SettingsActions` is currently declared in `SettingsWindowController.swift`, but it is not conceptually a settings-window-only type. It should be extracted to a neutral file such as `InnosDimmer/UI/AppWindowActions.swift` or `InnosDimmer/UI/SettingsActions.swift` before `SettingsWindowController.swift` is deleted.
- `ShortcutKeyField` is currently private to `SettingsWindowController.swift`. It must be extracted or replaced before the Shortcuts page can preserve human-readable key labels and validation behavior.
- `SettingsFormError.invalidShortcutKey` is currently private to `SettingsWindowController.swift`. The unified shortcut editor needs equivalent validation/copy, or tests must be intentionally rewritten.
- `SettingsWindowController.scheduleSummary(for:)` contains stale visible copy using `warmth`; the unified window should rely on `Blue reduction` vocabulary and centralize schedule formatting.
- `SettingsWindowController` test hooks (`saveShortcutsForTesting`, `setShortcutForTesting`, `shortcutForTesting`, `openScheduleEditorForTesting`) must move to `AppWindowController` equivalents before old tests are removed.

## Side Effects And Integration Points

The redesign touches user-visible UI only, but several controls trigger live side effects:

- Brightness and blue reduction controls call `MenuBarCommand.setBrightness`, `.setBlueReduction`, `.brightnessDown`, `.brightnessUp`, `.blueReductionDown`, or `.blueReductionUp`.
- Manual dimming commands pause automation through `MenuBarController.pauseAutomationAfterManualCommandIfNeeded`.
- `Quick disable` currently stores a previous command, applies brightness `100` and blue reduction `0`, and later `restorePrevious()` replays the stored command.
- Schedule save uses `DisplayTargetStore.saveSchedule`, refreshes schedule entries, applies schedule decisions, and reschedules timers.
- Shortcut save uses `DisplayTargetStore.saveShortcuts`, may re-register Carbon hotkeys, and records diagnostics.
- Display save uses `DisplayTargetStore.saveSelectedDisplay` and may resolve a fresh external display.
- Login item update can require system-level approval and must preserve status reporting.
- Diagnostics export records an app lifecycle event before exporting.

Integration points that need explicit tests:

- `MenuBarController.showAppWindow(focus:)`
- `MenuBarController.openSettings()`
- `AppDashboardWindowController.update(...)` or its replacement
- button command mapping through `commandButtonForTesting(_:)`
- schedule row editing and save through `ScheduleEditorActions`
- shortcut editing and save through `SettingsActions.updateShortcuts`
- display picker save through `SettingsActions.selectDisplay`
- login item toggle through `SettingsActions.setLaunchAtLogin`
- diagnostics export through `SettingsActions.exportDiagnostics`
- popover `Edit Shortcuts` routing after settings-window removal
- app-window `Settings` navigation after settings-window removal
- old settings-window shortcut customization tests migrated to unified app-window tests

## Risk To Surrounding Systems

High risk:

- Splitting the app-window UI into multiple pages can accidentally hide controls that tests or real workflows expect to remain reachable.
- Moving schedule editing from the old inline dashboard to the new Schedule page can break `AppDashboardWindowController` tests and `openScheduleEditor` focus behavior.
- Replacing `SettingsWindowController` entirely can break display picker, shortcut editing, login item, diagnostics export, or status label behavior if each old action is not mapped.
- Adding yet another UI helper layer can make popover/window components drift again.
- Removing `SettingsWindowController` before extracting `SettingsActions`, `ShortcutKeyField`, shortcut validation, and test hooks will break compilation and settings tests.
- Reusing `.openSettings` for multiple destinations can make routing ambiguous: popover `Edit Shortcuts` wants the Shortcuts page, while generic Settings navigation wants the Settings page.

Medium risk:

- The HTML mockup currently still has some stale copy in detail pages, such as `Warmth` references in existing Swift view models and some mockup captions. The implementation should normalize visible copy to `Blue reduction` unless an existing test intentionally locks older labels.
- Existing `AppDashboardWindowController` lives in `MenuBarPopoverView.swift`. Continuing to grow it there increases file size and makes review harder.
- The current app starts by calling `showAppWindow()` in `MenuBarController.start()`. A full window redesign may make this more noticeable; if the desired product behavior is menu-bar-only on launch, that should be a separate product decision before implementation.
- Some tests currently assert labels such as `Edit Shortcuts`, `Open Control Window`, `Resume automation`, and `Settings`. Label changes need deliberate test updates rather than incidental failures.

Low risk:

- Static text and visual grouping changes are safe if command identity, persistence actions, and test hooks remain stable.
- The HTML mockup already maps its key classes to shared component names, so it is a good design target for AppKit translation.

## Do Not Duplicate Or Bypass

Do not bypass:

- `MenuBarController.perform(_:)` for dimming, automation, quick disable, restore, popover, settings, and app-window commands.
- `SettingsActions` or its extracted successor for durable settings operations currently owned by `SettingsWindowController`.
- `ScheduleEditorActions` for schedule saves.
- `DisplayTargetStore` for selected display, schedule, shortcut persistence, and migration.
- `ScheduleEngine` for active row, boundary, pause, and resume semantics.
- `DiagnosticsStore` and `DiagnosticsExporter` for log and export behavior.
- `VerificationMatrix.summary(for:)` for capability summary.
- `InnosDesignTokens` and `InnosDesignComponents` for the redesigned AppKit surface.

Do not duplicate:

- A third custom palette if `InnosDesignTokens` can cover the new window.
- A separate dimming control implementation if `InnosDimmingControlGroupView` only needs small API extensions.
- A separate action row implementation if `InnosComponentFactory.actionRow` can support equal-width and compact variants.
- A separate shortcut parser if `ShortcutKeyField` remains usable or can be extracted.
- A separate schedule parser if `ScheduleEditorView.editedSchedule()` can be reused or extended.
- A parallel settings persistence path; all durable display/schedule/shortcut state should still flow through `DisplayTargetStore`.
- A parallel login-item status path; all login item state should still flow through `LoginItemController`.

## Open Questions

Questions that can change the implementation plan:

1. Should `AppDashboardWindowController` be renamed/moved into its own file and become the redesigned window, or should a new `AppWindowController` be introduced?
2. Should `MenuBarController.start()` continue to show the app window immediately on launch?
3. Should the existing separate `ScheduleEditorWindowController` be deleted with `SettingsWindowController`, or can it remain temporarily as an internal/legacy shell while the unified Schedule page becomes the primary route?
4. Should the mockup's shortened home command labels `Disable`, `Restore`, and `Resume` become production labels, or should production keep longer accessibility labels while using shorter visible titles?
5. Should remaining user-facing `Warmth` strings in current Swift tests/view models be normalized to `Blue reduction` during this redesign? Current recommendation: yes for visible product text, while internal property names can remain `blueReduction`.
6. Should `MenuBarCommand.openSettings` be kept and interpreted as `focus: .settings`, or should it be replaced/supplemented with specific routing commands such as `.openShortcuts`, `.openSettingsPage`, and `.openDiagnostics`? Current recommendation: split commands for page-specific entry points.
7. Should the schedule column label be `Blue`, `Blue reduction`, or `Warmth`? Current recommendation: `Blue` in tight table headers and `Blue reduction` in accessibility labels/status text.

Current recommendation:

- The old `SettingsWindowController` retirement decision is no longer open; the user wants it removed after integration.
- Treat questions 1, 3, 5, 6, and 7 as plan decisions.
- Treat question 2 as a product behavior decision and avoid changing it unless explicitly requested.
- Treat question 4 as an accessibility implementation detail: visible title may be short, accessibility label should stay explicit.

## Plan Implications

Recommended implementation direction:

1. Use the current `AppDashboardWindowController` as the behavioral starting point because `MenuBarController.showAppWindow()` already routes to it and tests already cover its command buttons, tracks, schedule save, diagnostics, and paused/resume state.
2. Move or split `AppDashboardWindowController` out of `MenuBarPopoverView.swift` before or during the redesign so the popover file does not keep growing.
3. Build a page enum and root container matching the mockup.
4. Reuse `InnosDesignComponents` first; extend them only when the mockup requires a missing primitive.
5. Extract settings-window-owned reusable code before deletion:
   - `SettingsActions`
   - `ShortcutKeyField`
   - shortcut form error/validation helpers
   - shortcut row test hooks
   - display picker rendering logic or its view-model equivalent
6. Route `openSettings` into the unified app window and stop instantiating `SettingsWindowController`.
7. Recreate every old settings-window behavior in the new app window:
   - selected display picker/save/use automatic
   - schedule page entry and schedule save
   - shortcut table, save/reset, Open popover shortcut
   - launch-at-login toggle and status
   - diagnostics summary, verification matrix, export
   - transient status label
8. Add focused tests around page reachability, command routing, and old settings behavior coverage before deleting the old stacked form.
9. Normalize stale static/product copy during implementation:
   - `Automation` page title -> `Schedule`
   - visible `Warmth` schedule/control labels -> `Blue` or `Blue reduction`
   - retain explicit accessibility labels for shortened commands.

Implementation skeleton:

```swift
private enum AppWindowPage: CaseIterable {
    case home
    case current
    case display
    case schedule
    case shortcuts
    case settings
    case diagnostics
}
```

```swift
private var activePage: AppWindowPage = .home {
    didSet { renderActivePage() }
}

private func renderActivePage() {
    pageContainer.subviews.forEach { $0.removeFromSuperview() }

    let nextView: NSView
    switch activePage {
    case .home:
        nextView = makeHomePage()
    case .current:
        nextView = makeCurrentStatusPage()
    case .display:
        nextView = makeDisplayPage()
    case .schedule:
        nextView = makeSchedulePage()
    case .shortcuts:
        nextView = makeShortcutsPage()
    case .settings:
        nextView = makeSettingsPage()
    case .diagnostics:
        nextView = makeDiagnosticsPage()
    }

    pageContainer.addSubview(nextView)
    pin(nextView, to: pageContainer)
}
```

Recommended controller dependencies:

```swift
struct AppWindowActions {
    var menu: MenuBarActions
    var settings: SettingsActions
    var schedule: ScheduleEditorActions
}
```

After `SettingsActions` is extracted, an explicit unified action bundle can avoid leaking the old settings-window name into the new implementation:

```swift
struct AppWindowActions {
    var performCommand: @MainActor (MenuBarCommand) -> Void
    var selectDisplay: @MainActor (DisplayIdentity?) -> Result<SettingsSnapshot, Error>
    var updateSchedule: @MainActor ([ScheduleEntry]) -> Result<SettingsSnapshot, Error>
    var updateShortcuts: @MainActor ([ShortcutBinding]) -> Result<SettingsSnapshot, Error>
    var setLaunchAtLogin: @MainActor (Bool) -> Result<LoginItemStatus, Error>
    var exportDiagnostics: @MainActor () -> Result<Data, Error>
}
```

Recommended view model expansion:

```swift
struct AppWindowViewModel: Equatable {
    var modeTitle: String
    var displayValue: String
    var brightnessValue: String
    var blueReductionValue: String
    var automationValue: String
    var automationActionTitle: String
    var nextActionRows: [SummaryRow]
    var shortcutRows: [ShortcutBinding]
    var diagnosticsRows: [DiagnosticsEvent]
    var verificationSummary: String
}
```

Recommended migration order:

1. Extract the current app-dashboard controller into its own file with no behavior change.
2. Extract settings-window-only reusable pieces that must survive deletion: `SettingsActions`, `ShortcutKeyField`, shortcut validation, and test hooks.
3. Add `AppWindowPage` and a page container while keeping current dashboard content equivalent.
4. Implement Home with `Quick actions`, `Next actions`, and navigation tiles.
5. Implement `Current status` and `Diagnostics` pages because they are mostly read-only and lower risk.
6. Implement `Schedule` page by replacing/extending `ScheduleEditorView` with a table-like editor:
   - columns: `Time`, `Bright`, `Blue`
   - time text field
   - brightness value field + track + adjacent `-`/`+`
   - blue reduction value field + track + adjacent `-`/`+`
   - optional remove-row button
   - page-bottom `Pause automation` and `Save schedule` action row
7. Implement `Display`, `Shortcuts`, and `Settings` pages by moving existing `SettingsWindowController` controls/actions behind the new page model.
8. Change `MenuBarController.openSettings()` to call `showAppWindow(focus:)` instead of `settingsWindowController.showWindow(nil)`.
9. Change popover/dashboard labels and routing so settings-related entry points land on the correct unified page.
10. Migrate `SettingsWindowShortcutCustomizationTests` to the new app-window controller.
11. Delete `SettingsWindowController.swift` only after compile and migrated tests pass.
12. Remove the `settingsWindowController` property and any obsolete settings-window-only tests.

Routing inventory for the plan:

| Entry point | Current route | Unified target route | Notes |
| --- | --- | --- | --- |
| Menu bar popover `Open Control Window` | `.openAppWindow` -> `showAppWindow()` | `.openAppWindow` -> unified app window `.home` | Keep command identity unless label changes require tests. |
| Menu bar popover `Edit schedule` | `.openScheduleEditor` -> `showAppWindow(focus: .schedule)` | `.openScheduleEditor` -> unified app window `.schedule` | Current behavior already avoids separate schedule window for this path. |
| Menu bar popover `Edit Shortcuts` | `.openSettings` -> separate `SettingsWindowController` | `.openShortcuts` -> unified app window `.shortcuts` | Recommended split; avoids ambiguous settings routing. |
| Dashboard/Home `Settings` tile/button | `.openSettings` -> separate `SettingsWindowController` | `.openSettings` -> unified app window `.settings` | Generic settings route should not hijack shortcut editing. |
| Diagnostics tile/action | currently embedded dashboard diagnostics only | `.openDiagnostics` or tile navigation -> unified app window `.diagnostics` | Needed if diagnostics warnings should deep-link to logs. |
| Old Settings `Open app window` | `SettingsActions.openScheduleEditor` -> `showAppWindow(focus: .schedule)` | remove with settings window deletion | The Schedule page replaces this bridge. |
| Old Settings display picker | `SettingsActions.selectDisplay` -> `saveSelectedDisplay` | unified Display page -> same action | Preserve saved snapshot and display resolution behavior. |
| Old Settings shortcut save/reset | `SettingsActions.updateShortcuts` -> `saveShortcuts` | unified Shortcuts page -> same action | Preserve hotkey re-registration after save. |
| Old Settings launch-at-login checkbox | `SettingsActions.setLaunchAtLogin` -> `setLaunchAtLogin` | unified Settings page -> same action | Preserve approval/unsupported status reporting. |
| Old Settings diagnostics export | `SettingsActions.exportDiagnostics` -> `exportDiagnosticsData` | unified Diagnostics page -> same action | Preserve export JSON and record event behavior. |

Backend side-effect boundary after unification:

```text
Unified AppWindowController
  -> AppWindowActions
    -> MenuBarController.perform(_:)
    -> MenuBarController.saveSelectedDisplay(_:)
    -> MenuBarController.saveSchedule(_:)
    -> MenuBarController.saveShortcuts(_:)
    -> MenuBarController.setLaunchAtLogin(_:)
    -> MenuBarController.exportDiagnosticsData()
```

Frontend page-routing boundary after unification:

```text
Popover / status item / app-window navigation
  -> MenuBarCommand or AppWindowPage
  -> MenuBarController.showAppWindow(focus:)
  -> AppWindowController.focus(_:)
  -> AppWindowController.renderActivePage()
```

Suggested tests:

- `testAppWindowHomeRoutesNavigationTiles`
- `testAppWindowHomeButtonsRouteQuickCommands`
- `testAppWindowCurrentStatusUsesStateValues`
- `testAppWindowSchedulePageSavesEditedRows`
- `testAppWindowSchedulePageValueTrackStepperLayoutModel`
- `testAppWindowSchedulePageUsesBlueReductionVocabulary`
- `testAppWindowDisplayPageUsesSelectedDisplayAction`
- `testAppWindowShortcutsPageSavesAndResetsBindings`
- `testAppWindowShortcutsPageIncludesOpenPopoverBinding`
- `testAppWindowShortcutsPageReportsInvalidCustomizedShortcutKey`
- `testAppWindowSettingsPageTogglesLaunchAtLogin`
- `testAppWindowDiagnosticsPageExportsDiagnostics`
- `testOpenSettingsRoutesToUnifiedAppWindow`
- `testPopoverEditShortcutsRoutesToShortcutsPage`
- `testAppWindowBackButtonReturnsHome`
- `testAppWindowVisibleLabelsUseBlueReductionVocabulary`

Deletion gate for `SettingsWindowController.swift`:

- No production references to `SettingsWindowController`.
- No production references to `settingsWindowController`.
- `SettingsActions` or its replacement compiles from a neutral file.
- Shortcut editor tests pass against the new app-window controller.
- `MenuBarCommand.openSettings` or its replacement is still covered by routing tests.
- Diagnostics export remains reachable from the unified app window.
- Display selection, shortcut save/reset, launch-at-login toggle, diagnostics export, and transient status feedback are each reachable from the unified window.
- `rg -n "SettingsWindowController|settingsWindowController" InnosDimmer InnosDimmerTests` returns only intentionally deleted-file references or no matches after deletion.
- Manual QA confirms the app no longer opens two separate windows for settings vs app-window workflows.

## Source Evaluation

Local evidence quality:

- `DESIGN.md`: Adopt. Project-level product and design contract.
- `docs/design/shared-control-system/contract.md`: Adopt. Current shared popover/window design contract.
- `docs/design-components/README.md` and component contracts: Adopt with implementation verification. They define intended shared AppKit primitives, but some primitives are still scaffolded and may need extension.
- `docs/design/window-redesign/app-window-componentized-mockup.html`: Adopt as visual/IA target, not implementation truth. It is static HTML and includes mock data.
- Latest browser-reviewed mockup comments: Adopt as current design intent where they changed structure: compact Home copy, Schedule tile naming, table-like schedule editor, direct diagnostic log rows, and removal of nonessential explanatory captions.
- `docs/design/window-redesign/feedback.md`: Adopt as previous design audit and scope context.
- `SettingsWindowController.swift`: Adopt as behavior inventory for old settings form.
- `AppDashboardWindowController` in `MenuBarPopoverView.swift`: Adopt as current app-window behavior and best migration anchor.
- `MenuBarController.swift`: Adopt as runtime side-effect boundary.
- `HotkeyBindingTests.swift`: Adopt as settings-window deletion blocker. It contains tests that must migrate before `SettingsWindowController` can be removed.
- `DisplayTargetStore.swift`: Adopt as persistence boundary for unified window settings pages.
- Tests: Adopt as regression guard. Current tests cover dashboard routing, schedule save, tracks, view models, settings snapshots, and verification matrix behavior.

External evidence:

- No external sources were required. This task is a local implementation-prep research task, and the current repository docs/code are the stronger source of truth.

Adoption decision:

- Adopt local code and design contracts as the basis for `plan-first-implementation`.
- Do not treat the HTML mockup as proof of native layout feasibility until AppKit screenshot/manual QA verifies the final window.

## Evidence

Confirmed facts:

- `README.md` says InnosDimmer is a personal macOS menu bar utility for an external INNOS 27QA100M display on M1 HDMI and uses software overlay plus gamma blue reduction.
- `DESIGN.md` says the menu bar popover is the quick-control surface and the app window is the detailed diagnostics/settings surface.
- `DESIGN.md` also says popover and app-window controls must share core component language.
- `SettingsWindowController.swift` builds a single vertical `NSScrollView` form in a 500 x 620 window.
- `MenuBarController.showAppWindow(focus:)` currently creates `AppDashboardWindowController`, calls `refreshAppWindow()`, shows the window, and focuses schedule when requested.
- `MenuBarController.openSettings()` currently records `Opened settings`, configures `SettingsWindowController`, shows that separate window, activates the app, and refreshes the popover.
- `MenuBarController.perform(.openSettings)` currently calls `openSettings()`.
- The popover `Edit Shortcuts` button currently emits `.openSettings`, so settings-window removal requires a new destination decision for that entry point.
- The current app-dashboard `Settings` button also emits `.openSettings`.
- `SettingsWindowShortcutCustomizationTests` in `HotkeyBindingTests.swift` currently instantiate `SettingsWindowController` directly and test schedule navigation, Open popover shortcut presence, shortcut save, human-readable shortcut key labels, and invalid shortcut key errors.
- `DisplayTargetStore` owns durable selected display, schedule, and shortcuts persistence and validates non-empty schedules plus hotkey validation before saving.
- `AppDashboardWindowController` is currently inside `MenuBarPopoverView.swift` and builds a tall scroll dashboard.
- `InnosDesignComponents.swift` already contains shared AppKit implementations for section shell, status chip, command button, dimming track, dimming control group, action row, and summary row.
- `docs/design/window-redesign/app-window-componentized-mockup.html` maps HTML classes to those shared component names in its comment block.
- The latest static mockup schedule table puts each value cell in the order `value input -> track -> adjacent -/+ buttons`; browser layout verification showed no horizontal overflow at 1289 x 1096.
- The latest static mockup still contains residue that should not be copied directly into production: `data-page="automation"`, `<h2>Automation</h2>`, and `Warmth` table/accessibility labels.
- `MenuBarStateTests.swift` already tests app-dashboard command routing, paused resume automation state, command button height, track absolute percentage routing, and inline schedule save.
- `SettingsSnapshotTests.swift` protects snapshot persistence and legacy migration.
- `VerificationMatrixTests.swift` protects verification matrix semantics.

Insufficient evidence:

- No native AppKit screenshot of the redesigned window exists yet.
- The mockup has not been translated into an AppKit layout, so exact preferred/minimum native window sizes remain unproven.
- It is not yet proven whether `InnosDesignComponents` are complete enough for navigation tiles, ops strips, diagnostics rows, and schedule mini tracks without extension.
- The final product decision is now to delete `SettingsWindowController`, but the exact command split for `openSettings` vs `openShortcuts` remains unproven until planning.
- Native AppKit row layout for the Schedule page has not been screenshot-verified; the HTML proves the intended layout, not the native result.

Recommended next step:

- Use this research as the evidence basis for a `plan-first-implementation` document focused on replacing the split settings/dashboard windows with one componentized app window.
