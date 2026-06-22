# Research

## 2026-06-22 Current Implementation Vs Mockup Gap Audit

Trigger mode: `research` Purpose Research with local `codebase`, `design`, `empirical`, and `reasoning` lanes.

### Goal

Compare the current native AppKit implementation against `docs/design/window-redesign/app-window-componentized-mockup.html` and identify what must change for the real app to reflect the useful parts of the refined mockup more closely.

This pass treats the mockup as an information-architecture and interaction contract, not a pixel-perfect visual target. The operator's latest direction favors the concise old settings feel over verbose dashboard explanations.

### Evidence Read In This Pass

Files read:

- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/UnifiedAppWindowController.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/ScheduleEditorView.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/DesignSystem/InnosDesignComponents.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmerTests/MenuBarStateTests.swift`
- `/Users/moonsoo/projects/InnosDimmer/docs/design/window-redesign/app-window-componentized-mockup.html`
- `/Users/moonsoo/projects/InnosDimmer/docs/design/window-redesign/research.md`

Commands used:

- `git status --short`
- `rg -n "makeSidebar|makeCurrentPage|makeDisplayPage|makeSchedulePage|makeSettingsPage|makeDiagnosticsPage|tileDescription|Refresh displays|Use automatic|Settings\"|Recent diagnostics log|Launch at login|makeSummaryTable|diagnostics-code-log" ...`
- `rg -n "SettingsWindowController|openSettings|openAppWindow|openScheduleEditor|refreshDisplaysPressed|useAutomaticDisplayPressed|saveDisplayPressed" InnosDimmer/UI InnosDimmerTests`
- `rg -n "Quick controls and status\.|State and commands\.|Target monitor\.|Rows and pause state\.|Global hotkeys\.|Startup and persistence\.|Failures and export\." ...`
- targeted `sed -n ...` reads of the files above

### Comparison Matrix

| Surface | Mockup direction | Current implementation | Gap | Priority |
| --- | --- | --- | --- | --- |
| Sidebar navigation | icon + page title, no small descriptive copy | `AppWindowSidebarButton` renders `titleLabel` and `descriptionLabel`; descriptions come from `UnifiedAppWindowPage.tileDescription` | Visible nav is still too verbose and not aligned with the simplified mockup | P0 |
| Sidebar accessibility | concise page navigation | `setAccessibilityLabel("\(page.navigationTitle). \(page.tileDescription)")` repeats removed descriptions | If visible descriptions are removed, accessibility label should be intentionally reset instead of accidentally stale | P1 |
| Current status commands | `Open popover` + automation action only | `makeCurrentPage()` still includes `Settings` command | Redundant because Settings is already a sidebar destination | P0 |
| Display page header actions | no top-level display refresh button | `makeDisplayPage()` still adds `Refresh displays` as a page-level primary action | Operator marked this unclear/unnecessary; mockup removed it | P0 |
| Display saved selection | `Save display` only | `Saved selection` still shows `Save display` and `Use automatic` | `Use automatic` remains a confusing visible command | P0 |
| Display current state | only changing/useful values: display, brightness, blue | Current implementation already has Display/Brightness/Blue and no Mode row | aligned | Done |
| Display target facts | useful target details instead of generic mode | Current implementation has `Selection rule`, `Active target`, `Safety scope`, `Blue reduction` | mostly aligned; actual `Active target` lacks HDMI because `DisplayIdentity` does not expose transport | P2 |
| Schedule summary | summary table above schedule rows | `makeSchedulePage()` uses `makeSummaryTable(identifier: "Schedule", ...)` | aligned | Done |
| Schedule rows | fixed 3 rows, Time/Bright/Blue headers, editable numbers, track, adjacent `-`/`+` | `ScheduleEditorView` implements `rowCount = 3`, `Time`, `Bright`, `Blue`, value field + track + adjacent stepper | aligned | Done |
| Settings page | only real global settings | `makeSettingsPage()` has `Launch at login` only | aligned | Done |
| Diagnostics matrix | checkmark-style matrix | `makeDiagnosticsPage()` uses `verificationCheckmark()` for Overlay/Gamma/Hotkeys/Login item | aligned | Done |
| Diagnostics log | scrollable code-style log with copy/export | `makeDiagnosticsCodeLogView()` uses `NSTextView` in `NSScrollView`; page has `Copy log` and `Export diagnostics` | aligned | Done |
| Acceptance tests | should protect simplified UI | `MenuBarStateTests` still expects `Settings`, `Refresh displays`, and `Use automatic` in relevant pages | Tests currently lock in stale UI and must be updated before/with implementation | P0 |

### Highest-Value Implementation Moves

1. Update `MenuBarStateTests` first so stale UI is rejected rather than expected:
   - remove `Settings` from current-status expected command labels
   - remove `Refresh displays` and `Use automatic` from display expected labels
   - add negative assertions for sidebar descriptions such as `Target monitor.` and `Startup and persistence.`
2. Simplify `AppWindowSidebarButton`:
   - remove `descriptionLabel`
   - make the text stack title-only
   - change `setAccessibilityLabel(...)` to `page.navigationTitle` or intentionally add a hidden accessibility help string
3. Simplify `makeCurrentPage()`:
   - keep `Open popover`
   - keep `automationActionTitle()`
   - remove the visible `Settings` command
4. Simplify `makeDisplayPage()`:
   - remove top-level `Refresh displays`
   - remove visible `Use automatic`
   - keep `Save display`
   - preserve `refreshDisplaysPressed()` and `useAutomaticDisplayPressed()` temporarily until dead-code review proves they can be deleted safely
5. Leave schedule, settings, and diagnostics mostly alone:
   - these pages already reflect the best parts of the mockup
   - unnecessary churn here risks breaking working behavior without improving the requested alignment

### Current Test Contract Problem

The biggest blocker is not that AppKit cannot express the mockup. The problem is that the current test suite still codifies older UI:

- `testUnifiedAppWindowCurrentStatusPageDefinesReadOnlyDetailContract()` expects `Settings`.
- `testUnifiedAppWindowDisplayPageDefinesTargetSelectionContract()` expects `Refresh displays` and `Use automatic`.
- Existing tests verify good newer pieces too, such as diagnostics code log identifiers and schedule summary-table identifiers.

Implementation should therefore change tests and UI together. A UI-only change will fail current tests; a test-only change will document the failure clearly before the code cleanup.

### Do Not Change Yet

- Do not rewrite `ScheduleEditorView`; it already matches the latest table requirement.
- Do not expand `Settings` again with saved schema/status details; the operator explicitly wanted settings to contain only values that are actually changed there.
- Do not re-add verbose captions/subtitles to detail pages.
- Do not remove display-selection recovery methods in the same step as removing their visible buttons; first verify no internal or future-safe path needs them.
- Do not fake HDMI/transport information in the native display page unless `DisplayIdentity` or a display service actually provides it.

### Recommended Next Plan Shape

Next `plan-first-implementation` should be a smaller follow-up than the previous full redesign plans:

1. **Commit 1: Test contract cleanup**
   - update `MenuBarStateTests` for simplified sidebar/current/display contracts
2. **Commit 2: Native UI cleanup**
   - simplify sidebar, current commands, display actions
3. **Commit 3: Mockup/doc sync**
   - remove stale mockup icon rules for labels no longer present
   - record any retained hidden action methods as intentional
4. **Final gate**
   - run focused `MenuBarStateTests`
   - manually inspect native app window or capture a screenshot if possible

### Source Evaluation

- Strongest source: local AppKit code and test contracts, because they define actual current implementation.
- Strong design source: current HTML mockup, because it reflects the operator's latest commented decisions.
- Weak/unused source: external UI references. They were not needed because this is a local implementation-vs-mockup comparison.
- Insufficient evidence:
  - native app screenshot was not captured in this pass
  - no `xcodebuild test` was run in this pass
  - visual spacing quality still needs a manual/native screenshot check after implementation

### Research Brief

- Confirmed facts: sidebar descriptions, current-page `Settings`, display `Refresh displays`, display `Use automatic`, and stale test expectations remain in the current implementation.
- Repeated observations: the same stale labels are found in native code and in tests, while the refined mockup omits them from visible UI.
- Inference: implementation should focus on removing stale UI and updating tests, not on rewriting already-aligned schedule/settings/diagnostics pages.
- Recommendation: use a small plan and implementation pass centered on test contract cleanup plus native UI simplification.
- Open questions: whether display recovery actions should remain hidden/internal or be reintroduced later with clearer labels.

## 2026-06-22 Mockup-To-App Alignment Update

Trigger mode: `research` Pre-Plan Research Gate.

### Goal

Prepare the implementation basis for carrying the latest, simplified `app-window-componentized-mockup.html` decisions into the native AppKit app window.

The important distinction is that the app should not chase the mockup pixel-for-pixel. The target is to preserve the concise behavior of the older settings flow while adopting the mockup decisions that survived operator review:

- persistent sidebar navigation instead of back-button page stacks
- settings page limited to actual global controls, currently `Launch at login`
- display page focused on meaningful target-display facts and saved selection
- schedule page using the table pattern, fixed three rows, editable numeric values, track controls, and adjacent `-` / `+`
- diagnostics page using a vertical structure, a checkmark-based matrix, and a scrollable code-style log with copy/export actions
- reduced subtitles/captions and removal of explanatory filler

### Scope And Entry Points

Files read or re-read for this update:

- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/UnifiedAppWindowController.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/ScheduleEditorView.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/DesignSystem/InnosDesignComponents.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmerTests/MenuBarStateTests.swift`
- `/Users/moonsoo/projects/InnosDimmer/docs/design/window-redesign/app-window-componentized-mockup.html`
- `/Users/moonsoo/projects/InnosDimmer/docs/design/window-redesign/2026-06-22-unimplemented-followup-plan-first.md`

Commands used:

- `git status --short`
- `git diff --name-only`
- `rg -n "makeDisplayPage|makeSettingsPage|makeDiagnosticsPage|makeSchedulePage|makeCurrentPage|makeSidebar|Refresh displays|Use automatic|Settings" InnosDimmer/UI/UnifiedAppWindowController.swift`
- `rg -n "data-page=\"current|data-page=\"display|data-page=\"automation|data-page=\"settings|data-page=\"diagnostics|Selection rule|Recent diagnostics log|Launch at login|summary-row-list|token-code-log|Refresh displays|Use automatic|Target monitor|Controls and status" docs/design/window-redesign/app-window-componentized-mockup.html`
- `rg -n "testUnifiedAppWindow.*(Current|Display|Schedule|Settings|Diagnostics)|summary-table|diagnostics-code-log|Selection rule|Launch at login|Refresh displays|Use automatic|Target monitor" InnosDimmerTests/MenuBarStateTests.swift`
- `sed -n ...` targeted reads on the files above

### Confirmed Current State

- The native app window is now owned by `UnifiedAppWindowController`, not the removed standalone settings window path.
- `UnifiedAppWindowController.makeSidebar()` still renders each sidebar item with both `page.navigationTitle` and `page.tileDescription`.
- `UnifiedAppWindowPage.tileDescription` still contains the sidebar helper copy that the operator marked unnecessary, such as `Target monitor.`, `Rows and pause state.`, and `Startup and persistence.`
- `makeCurrentPage()` still exposes a `Settings` command in the `Commands` section, while the current mockup keeps only `Open popover` and the automation action there.
- `makeDisplayPage()` still exposes `Refresh displays` as a page-level action and `Use automatic` inside `Saved selection`; the current mockup keeps only `Save display` in that section.
- `makeDisplayPage()` already removed the `Mode` row from the display page's `Current state`, matching the operator's comment that static, non-configurable mode text is not useful there.
- `makeDisplayPage()` already uses the more meaningful target-display rows: `Selection rule`, `Active target`, `Safety scope`, and `Blue reduction`.
- `makeSettingsPage()` is already reduced to `Launch at login`, which matches the operator's request to keep settings limited to values that can actually be changed there.
- `makeDiagnosticsPage()` already uses a vertical stack, a checkmark matrix, `Recent diagnostics log`, `Copy log`, and a scrollable `NSTextView` inside `NSScrollView`.
- `makeSchedulePage()` already uses `InnosSummaryTableView` through `makeSummaryTable(...)` for the summary section and embeds `ScheduleEditorView` plus bottom actions in `Schedule rows`.
- `ScheduleEditorView` already has `Time`, `Bright`, and `Blue` columns, percent fields, tracks, and adjacent `-` / `+` step controls.
- `MenuBarStateTests` currently encode both the desired newer contracts and some stale contracts. In particular, current tests still expect `Settings` on the current-status page and `Refresh displays` / `Use automatic` on the display page.

### Mockup-To-App Gap Classification

Implemented or mostly implemented:

- persistent sidebar navigation
- no back button on detail pages
- settings page is single-purpose
- display page no longer shows static `Mode`
- target display rows are more meaningful
- schedule summary is table-like and componentized
- schedule editor uses fixed three rows and percent editing controls
- diagnostics matrix is simplified to checkmarks
- diagnostics log is scrollable code-style text with copy support

Still missing or stale:

- sidebar helper descriptions should be removed from the actual native sidebar, not only from the HTML mockup
- current-status page should drop the redundant `Settings` command
- display page should drop or demote `Refresh displays` and `Use automatic`, because the operator repeatedly flagged them as unclear and unnecessary in this simplified flow
- acceptance tests should assert absence of these stale UI elements so they do not drift back
- accessibility labels should remain understandable after sidebar descriptions are removed; use page title-only labels unless a hidden accessibility hint is intentionally kept

### Data Flow And Control Flow

Native app window routing:

1. `MenuBarController` opens or focuses the app window.
2. `UnifiedAppWindowController` maps `AppDashboardFocusTarget` to `UnifiedAppWindowPage`.
3. `renderActivePage()` chooses `makeHomePage`, `makeCurrentPage`, `makeDisplayPage`, `makeSchedulePage`, `makeShortcutsPage`, `makeSettingsPage`, or `makeDiagnosticsPage`.
4. Page actions are `PopoverCommandButton` instances or local selectors that ultimately route through injected `SettingsActions` / `MenuBarCommand` handling.
5. Tests inspect the rendered native view tree with `pageStructureForTesting(focus:)` and text extraction helpers.

Mockup flow:

1. `app-window-componentized-mockup.html` has `data-page` sections matching the native page enum.
2. The mockup is the review surface for information architecture, not the executable production implementation.
3. The native AppKit implementation should share labels, section names, command placement, and structural identifiers where they define a durable contract.

### Existing Abstractions And Boundaries

Do not bypass:

- `UnifiedAppWindowController` page factory methods for app-window layout
- `AppWindowSidebarButton` for sidebar navigation visuals
- `InnosComponentFactory.summaryTable` and `InnosSummaryTableView` for summary-table rows
- `ScheduleEditorView` for schedule row editing and validation
- `MenuBarCommand` and `SettingsActions` routing for actual command side effects
- `MenuBarStateTests` as the native UI contract boundary

Do not reintroduce:

- standalone `SettingsWindowController`
- duplicated schedule editor controls inside the app window
- one-off display or diagnostics components when an existing helper or component already owns the pattern
- verbose captions whose only purpose is explaining the UI to the user inside the app

### Risk To Surrounding Systems

- Removing visible buttons can silently remove test-covered behavior if the underlying command is not preserved elsewhere. For `Refresh displays`, verify whether the display list is refreshed automatically through existing render/open flows before deleting the visible action.
- Removing `Use automatic` changes display-selection recovery. The safer implementation is to keep the underlying `useAutomaticDisplayPressed` capability available internally or through a clearer future control, while removing the confusing visible button from the simplified page.
- Removing sidebar descriptions changes accessibility labels if the current label concatenates title and description. Tests should cover the visible-text change and the implementation should choose whether accessibility keeps a concise hidden hint or title-only labeling.
- Current tests still assert some stale UI; updating app code before updating the contract tests will produce expected failures.

### Plan Implications

The plan should prioritize contract cleanup before visual polish:

1. Update `MenuBarStateTests` so stale UI elements are explicitly rejected.
2. Remove sidebar descriptions from `AppWindowSidebarButton` and simplify `UnifiedAppWindowPage.tileDescription` usage.
3. Remove `Settings` from current-status commands.
4. Remove visible `Refresh displays` and `Use automatic` from display page, unless implementation evidence shows one is the only way to recover a necessary state.
5. Keep the existing settings, schedule, and diagnostics implementations largely intact because they already match the latest mockup direction.
6. Re-run the focused native UI regression suite after implementation.

### Source Evaluation

- Local code and tests: high quality, adopted. They define actual production behavior and executable contracts.
- HTML mockup: high quality for UX intent, adopted as review artifact but not as pixel-perfect source of truth.
- Prior plan documents: medium quality, used as historical context only because the user has since changed direction toward more concise settings-like UI.
- External sources: not used. This task is local UI contract alignment, and current external UI guidance would be weaker than the operator's direct review comments plus local code evidence.

### Open Questions

- Should the display page expose an explicit "automatic display" recovery control later under a clearer label, or is automatic selection implicit enough for the personal-use app?
- Should sidebar accessibility keep hidden descriptive hints, or should it be strictly title-only to match visible simplification?

Default for planning: title-only visible sidebar labels, remove unclear display actions from the primary UI, keep underlying action methods unless they become provably dead after tests.

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

## 2026-06-21 Actual App Window Gap Research

### Goal

Implement the reviewed `app-window-componentized-mockup.html` in the actual macOS app window. The user verified that the current native full window does not reflect the target mockup or the required settings-window integration.

### Mode

Pre-Plan Research Gate.

### Confirmed Facts

- `MenuBarController.showAppWindow(focus:)` still instantiates `AppDashboardWindowController` from `InnosDimmer/UI/MenuBarPopoverView.swift`.
- `AppDashboardWindowController.installContent()` still builds a tall vertical scroll dashboard with sections:
  - `Current state`
  - `Automation schedule`
  - `Configuration`
  - `Diagnostics`
- `AppDashboardWindowController.focus(_:)` only scrolls to existing sections. It does not switch real pages.
- `AppDashboardFocusTarget.shortcuts` and `.settings` both map to `configurationSectionView`, so Shortcuts and Settings are not distinct surfaces.
- `SettingsWindowController` still owns the working implementations for display picker, shortcut controls/validation, shortcut save/reset, launch-at-login toggle, and diagnostics export.
- `MenuBarController.openSettings()` currently routes to `showAppWindow(focus: .settings)`, but the target app window does not expose the old settings functions yet.
- `ScheduleEditorView` still uses visible `Warmth` copy and reports invalid blue-reduction values with `field: "warmth"`.
- Existing tests verify that the app window opens, buttons route, tracks send commands, and schedule can save, but they do not yet prove all old settings features are reachable in the unified window.

### Repeated Observations

- The HTML mockup and native window have drifted:
  - mockup has page tiles and detail pages;
  - native app window has a single scroll stack.
- The current native implementation uses the old dashboard name and test surface:
  - `AppDashboardWindowController`
  - `testAppDashboard...`
- The product vocabulary drift remains:
  - target: `Blue reduction`
  - old surfaces: `Warmth`

### Inference

The actual implementation stopped after partial routing and dashboard polish. The real window shell was not replaced with the page-based mockup architecture. The safest implementation is not to add a second app window. It is to turn the currently routed `AppDashboardWindowController` into the unified app window, because that is already what `Open Control Window`, app launch, and schedule/shortcuts/settings commands reach.

### Recommendation

Implement a single native app-window controller in the current route:

1. Keep `MenuBarController.showAppWindow(focus:)` as the runtime entry point.
2. Convert `AppDashboardWindowController` into a page-based window with Home, Current status, Display, Schedule, Shortcuts, Settings, and Diagnostics.
3. Inject `SettingsActions` into the app window so display, shortcut, login item, and diagnostics export side effects stay behind `MenuBarController`.
4. Pass `SettingsSnapshot`, active display candidates, and `LoginItemStatus` from `MenuBarController.refreshAppWindow()`.
5. Add test hooks for page navigation and settings reachability.
6. Only after the app window has feature parity, stop using the old `SettingsWindowController`. Physical file deletion can be a final cleanup once tests no longer instantiate it.

### First-Priority Implementation Hypothesis

Use the existing `AppDashboardWindowController` route and replace its content builder with a native page shell.

Why this is first priority:

- It directly changes the real app window that opens from the app.
- It avoids a second hidden window/controller path.
- It preserves existing quick-control behavior and tests.
- It keeps side effects behind `MenuBarController`.
- It makes the old settings-window deletion gate explicit instead of prematurely hiding features.

Proposed shape:

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

func focus(_ target: AppDashboardFocusTarget?) {
    activePage = AppWindowPage(target)
    renderActivePage()
    window?.makeKeyAndOrderFront(nil)
}
```

```swift
func update(
    state: BrightnessState,
    schedule: [ScheduleEntry],
    shortcuts: [ShortcutBinding],
    events: [DiagnosticsEvent],
    snapshot: SettingsSnapshot,
    displayCandidates: [DisplayIdentity],
    loginItemStatus: LoginItemStatus
) {
    self.state = state
    self.schedule = schedule
    self.shortcuts = shortcuts
    self.events = events
    self.snapshot = snapshot
    self.displayCandidates = displayCandidates
    self.loginItemStatus = loginItemStatus
    renderActivePage()
}
```

### Fallback Hypotheses

1. If page-shell replacement is too large for one safe patch, keep the class name but implement Home, Schedule, Display, Shortcuts, Settings, Diagnostics as vertically stacked sections with navigation buttons that scroll to each section. This improves reachability but does not satisfy the latest page mockup as well.
2. If shortcut editor extraction is too risky, duplicate the small shortcut-control logic into the app window first, then extract a shared component in a cleanup commit.
3. If full deletion of `SettingsWindowController` breaks too many tests, stop opening it from runtime first and leave physical deletion for a cleanup commit with migrated tests.

### System Integrity Checks

- Do not let UI pages call `DisplayTargetStore`, `LoginItemController`, or `DiagnosticsExporter` directly.
- Keep `MenuBarController` as the side-effect boundary.
- Preserve schedule save and hotkey registration behavior.
- Preserve quick-disable/restore behavior.
- Preserve diagnostics JSON export path through `DiagnosticsExporter`.
- Preserve old settings features until the app window can perform them.

### Open Questions

- Exact final native dimensions may need screenshot/manual QA after implementation.
- The physical deletion of `SettingsWindowController.swift` may require migrating `SettingsWindowShortcutCustomizationTests` and extracting `ShortcutKeyField`; this can be done in the same implementation if compilation remains manageable, but should stop if it creates broad unrelated churn.

---

## 2026-06-22 Sidebar Navigation Structure Research

### Goal

Investigate how to change the real native app window to match the latest approved mockup navigation model:

- persistent left sidebar navigation
- right-side content pane
- no Back button
- one active page at a time
- page routing through the existing unified app-window command surface

This is a Pre-Plan Research Gate for a later `plan-first-implementation` document. It is not an implementation patch.

### Scope And Entry Points

Primary implementation entry point:

- `InnosDimmer/UI/UnifiedAppWindowController.swift`

Runtime routing entry point:

- `InnosDimmer/UI/MenuBarController.swift`

Design baseline:

- `docs/design/window-redesign/app-window-componentized-mockup.html`
- `DESIGN.md`
- `docs/design-decisions.md`

Reusable supporting views:

- `InnosDimmer/UI/ScheduleEditorView.swift`
- `InnosDimmer/UI/DesignSystem/InnosDesignTokens.swift`
- `InnosDimmer/UI/DesignSystem/InnosDesignComponents.swift`
- popover-private primitives currently reused by the app window, especially `PopoverCommandButton`, `PopoverContainerView`, `ProgressTrackView`, and `AppWindowPageTileButton` from `InnosDimmer/UI/MenuBarPopoverView.swift`

Test entry points:

- `InnosDimmerTests/MenuBarStateTests.swift`
- `InnosDimmerTests/HotkeyBindingTests.swift`

External reference lane:

- Apple AppKit `NSSplitViewController`
- Apple AppKit `NSSplitViewItem.init(sidebarWithViewController:)`
- Apple HIG `Sidebars`

### Relevant Files

Files read for this addendum:

- `/Users/moonsoo/projects/InnosDimmer/DESIGN.md`
- `/Users/moonsoo/projects/InnosDimmer/docs/design-decisions.md`
- `/Users/moonsoo/projects/InnosDimmer/docs/design/window-redesign/research.md`
- `/Users/moonsoo/projects/InnosDimmer/docs/design/window-redesign/app-window-componentized-mockup.html`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/UnifiedAppWindowController.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/MenuBarController.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/MenuBarPopoverView.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/ScheduleEditorView.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/SettingsActions.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/DesignSystem/InnosDesignTokens.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/DesignSystem/InnosDesignComponents.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmerTests/MenuBarStateTests.swift`

Commands used:

- `rg --files`
- `rg -n "app-body|sidebar|content-pane|Back|data-go|page-head|Schedule rows|Quick actions|Status" docs/design/window-redesign/app-window-componentized-mockup.html`
- `rg -n "Back|Navigation|pageStructure|homeLayout|Mockup|sidebar|tile|Schedule rows|Current status|Next actions|Status|InnosDimmer Control Center" InnosDimmerTests/MenuBarStateTests.swift InnosDimmer/UI/UnifiedAppWindowController.swift`
- `nl -ba ...`
- `sed -n ...`

### Current Behavior

The latest static mockup now defines a two-region app shell:

- `.app-body` is a grid with `250px` sidebar and one content pane.
- `.sidebar` owns the persistent Settings navigation list.
- `.content-pane` owns active page rendering.
- Sidebar buttons use `data-go` values for `home`, `current`, `display`, `automation`, `shortcuts`, `settings`, and `diagnostics`.
- JavaScript updates both active page and active sidebar tile.
- Back buttons and `icon-arrow-left` were removed from the mockup.

The real native app window already has a unified controller, but it still uses the previous navigation model:

- `UnifiedAppWindowPage` already enumerates the target pages: `home`, `current`, `display`, `schedule`, `shortcuts`, `settings`, and `diagnostics`.
- `UnifiedAppWindowController.installContent()` currently builds one vertical root stack: header, transient status label, and `bodyView`.
- `renderActivePage()` removes all `bodyView` subviews and inserts a page-specific view.
- `makeHomePage()` still creates the old home layout with a left quick-actions column and a right navigation grid.
- `makeNavigationGrid()` still creates 2-column navigation tiles only for the home page.
- `makeDetailPage()` still creates a visible `← Back` button and places it in every detail page header.
- Tests currently assert the Back identifier exists: `app-window-header-action:Back`.

Routing is more mature than the layout:

- `MenuBarController.perform(_:)` already routes `.openScheduleEditor` to `.schedule`, `.openShortcuts` to `.shortcuts`, `.openDiagnostics` to `.diagnostics`, and `.openSettings` to `.settings`.
- `MenuBarController.showAppWindow(focus:)` already creates/reuses `UnifiedAppWindowController`, refreshes it, shows the window, and calls `controller.focus(focus)`.
- The old standalone `ScheduleEditorWindowController` still exists, but `openScheduleEditor` no longer uses it from the primary menu-bar command path.

Schedule editing is not the main blocker for this navigation task:

- `ScheduleEditorView` already has `Time`, `Bright`, and `Blue` headers.
- It already supports percent text fields, draggable tracks, and adjacent `-`/`+` step buttons.
- It already exposes test hooks for row values, track fractions, and step behavior.

### Data Flow And Control Flow

Current native page flow:

1. Runtime command enters `MenuBarController.perform(_:)`.
2. Page-opening commands call `showAppWindow(focus:)`.
3. `showAppWindow(focus:)` refreshes the `UnifiedAppWindowController` and calls `focus`.
4. `UnifiedAppWindowController.focus(_:)` maps `AppDashboardFocusTarget?` into `UnifiedAppWindowPage`.
5. `renderActivePage()` rebuilds the current page inside `bodyView`.
6. Page-local controls still route side effects through injected `MenuBarActions`, `ScheduleEditorActions`, and `SettingsActions`.

Target navigation flow:

1. `installContent()` should build a persistent shell:
   - optional top titlebar/header region
   - sidebar navigation region
   - content pane region
2. Sidebar buttons should be built from `UnifiedAppWindowPage.allCases`, including `.home`.
3. Clicking a sidebar row should set `activePage`, call `renderActivePage()`, and refresh sidebar selection state.
4. Detail pages should no longer render Back buttons.
5. Home should no longer render its separate right-side navigation grid.
6. `renderActivePage()` should only replace the content pane, not recreate the whole shell.
7. Side effects should continue to flow through the existing action structs.

Recommended control-flow shape:

```swift
private let sidebarStack = NSStackView()
private let contentPane = NSView()
private var sidebarButtons: [UnifiedAppWindowPage: NSButton] = [:]

private func installContent() {
    configureReusableControls()

    let sidebar = makeSidebar()
    let content = makeContentPane()
    let appBody = NSStackView(views: [sidebar, content])
    appBody.orientation = .horizontal
    appBody.alignment = .height
    appBody.spacing = 0

    let contentView = DashboardRootView()
    window?.contentView = contentView
    contentView.addSubview(appBody)
    // constrain appBody to contentView edges
    renderActivePage()
}
```

```swift
private func setActivePage(_ page: UnifiedAppWindowPage) {
    activePage = page
    renderActivePage()
    updateSidebarSelection()
}
```

```swift
private func renderActivePage() {
    titleLabel.stringValue = activePage == .home ? "InnosDimmer" : activePage.title
    commandButtons.removeAll(keepingCapacity: true)
    contentPane.subviews.forEach { $0.removeFromSuperview() }

    let content = makePageContent(for: activePage)
    contentPane.addSubview(content)
    // constrain content to contentPane edges
    updateSidebarSelection()
    updateLiveControls()
}
```

### Existing Abstractions And Boundaries

Keep:

- `UnifiedAppWindowPage` as the canonical native page enum.
- `AppDashboardFocusTarget` as the external focus API for now, because `MenuBarController` and tests already use it.
- `MenuBarController.perform(_:)` as the command router.
- `MenuBarActions`, `ScheduleEditorActions`, and `SettingsActions` as side-effect boundaries.
- `ScheduleEditorView` as the schedule row editor.
- `InnosDesignTokens` and existing `Popover*` controls as visual primitives until a later component cleanup.

Change:

- Replace home-only navigation with persistent sidebar navigation.
- Replace `pageButtons` with a clearer `sidebarButtons` map, or keep `pageButtons` only if its semantics are updated to include the always-visible sidebar.
- Replace `homeLayoutMetricsForTesting()` with sidebar/content metrics or active navigation tests.
- Remove `backPressed()` and the Back button identifier from the app-window structure tests.
- Rename the visible Home title from `InnosDimmer Control Center` to `InnosDimmer` if following the latest mockup exactly.
- Rename `Next actions` to `Status` if following the latest mockup exactly.

### Side Effects And Integration Points

Navigation changes must not alter:

- brightness/blue reduction command behavior
- quick disable/restore behavior
- pause/resume automation behavior
- schedule save behavior
- display selection persistence
- shortcut validation and save behavior
- launch-at-login behavior
- diagnostics export behavior
- `MenuBarController.refreshAppWindow()` data injection
- hotkey routing

The implementation should be mostly layout/control-shell work inside `UnifiedAppWindowController`. Any change that directly edits `BrightnessController`, `DisplayTargetStore`, `LoginItemController`, `DiagnosticsExporter`, `ScheduleEngine`, or `HotkeyManager` is probably outside this navigation task.

### Risk To Surrounding Systems

High-risk areas:

- `commandButtons.removeAll(keepingCapacity:)` currently runs on every page render. If sidebar buttons are stored in the same dictionary or created through the same `button(...)` helper, the sidebar could disappear from test lookup or lose command mappings. Sidebar page buttons should use a separate map from command buttons.
- `pageButtons` currently stores both navigation tiles and status-list rows. Reusing it blindly for persistent sidebar selection can overwrite entries and make active state inconsistent.
- `makeDetailPage()` currently owns page header creation and Back button creation. Removing Back requires changing tests that assert `app-window-header-action:Back`.
- The old home navigation grid is still produced by `makeHomePage()`. If it is left in place after adding a sidebar, the app will have duplicate navigation.
- `content.bottomAnchor.constraint(lessThanOrEqualTo:)` may produce pages that do not fill the content pane. A sidebar shell should use a scroll container per content pane or a stable content-pane constraint strategy.
- `MenuBarPopoverView.swift` still contains old `AppDashboardWindowController` code. It is not the active route, but it can confuse future implementation if copied from. Prefer editing `UnifiedAppWindowController.swift`.

Medium-risk areas:

- The official AppKit split-view route is more native, but switching the controller to `NSSplitViewController` would be a larger architectural change than the current request requires.
- Test screenshots may change significantly because the window shell changes even when page content stays the same.
- The current window size is `880x560`; the mockup uses `900x640`. Changing size is visible but low behavioral risk.

### Do Not Duplicate Or Bypass

Do not duplicate:

- `ScheduleEditorView` for schedule row editing.
- `SettingsActions` side-effect closures.
- `MenuBarController.showAppWindow(focus:)` routing.
- `MenuBarController.perform(_:)` command routing.
- `ShortcutKeyField` and shortcut validation.
- `DiagnosticsExporter` export path.
- `DisplayTargetStore` save/load behavior.

Do not bypass:

- `MenuBarActions.perform` for live dimming commands.
- `ScheduleEditorActions.updateSchedule` for schedule saves.
- `SettingsActions.updateShortcuts`, `.selectDisplay`, `.setLaunchAtLogin`, and `.exportDiagnostics` for durable settings behavior.

### Open Questions

- Should the native window adopt `NSSplitViewController` now, or should it keep the existing custom `NSStackView` shell? Recommendation below: keep custom shell for this iteration.
- Should the sidebar show subtitles like the mockup (`Controls and status.`) or only page titles? The current mockup keeps concise subtitles; native implementation can keep them if text does not crowd the 250px sidebar.
- Should the app window exact size change to `900x640` now? It is visual alignment, not a functional dependency.
- Should the old `AppDashboardWindowController` inside `MenuBarPopoverView.swift` be deleted in the same plan? Recommendation: only after active `UnifiedAppWindowController` tests pass, because deletion is cleanup and can create broad diff noise.

### Plan Implications

First-priority hypothesis:

Use a custom `NSStackView` sidebar shell inside `UnifiedAppWindowController`.

Why:

- The current controller is already manually composed with `NSStackView`.
- The existing action injection and test hooks are all inside `UnifiedAppWindowController`.
- A custom shell can preserve the current runtime route and reduce blast radius.
- It directly matches the HTML mockup's `app-body/sidebar/content-pane` structure.

Implementation plan implications:

1. Add persistent shell state to `UnifiedAppWindowController`:
   - `sidebarStack`
   - `contentPane`
   - `sidebarButtons`
2. Refactor `installContent()` so it installs the persistent shell once.
3. Add `makeSidebar()` and `makeSidebarButton(_:)`.
4. Change `renderActivePage()` to replace only `contentPane`.
5. Remove Back button creation from `makeDetailPage()`.
6. Remove home-only navigation grid from `makeHomePage()`.
7. Update active selection on `focus(_:)` and sidebar button click.
8. Update tests:
   - assert no Back button
   - assert all sidebar pages exist
   - assert clicking/focusing page updates active page
   - replace `homeLayoutMetricsForTesting()` expectations
   - keep existing behavior tests for settings/display/shortcuts/schedule/diagnostics
9. Run focused tests around `UnifiedAppWindowController`, `MenuBarController` page routing, and schedule editor behavior.
10. Run snapshot/smoke rendering for all pages if available.

Fallback hypothesis A:

If the persistent shell creates constraint issues, build the sidebar and content pane as siblings inside the existing `rootStack` body area first, while preserving the current top header. This is less elegant but preserves the same controller lifecycle.

Fallback hypothesis B:

If custom sidebar selection becomes fragile, use `NSSplitViewController` and two child view controllers:

- `SidebarViewController`
- `ContentPageViewController`

This is more AppKit-native, but it requires a larger refactor of test hooks and the current `NSWindowController` composition.

Fallback hypothesis C:

If active page rebuilding breaks existing controls, keep page content functions intact and only move the navigation surface first:

- persistent sidebar added
- Home navigation grid removed
- Back removed
- detail page content unchanged

Then later refine page internals.

### Source Evaluation

Local code is the strongest evidence and should be adopted:

- `UnifiedAppWindowController` already owns active page state, page rendering, actions, and settings integration.
- `MenuBarController` already routes page-specific commands into the unified app window.
- Tests already cover many page contents and routing side effects.

Official Apple evidence is supportive, not controlling:

- Apple `NSSplitViewController` documentation describes a controller that manages child views side-by-side.
- Apple `NSSplitViewItem.init(sidebarWithViewController:)` documents a formal sidebar split item.
- Apple HIG Sidebars guidance frames sidebars as leading-side navigation between app areas or top-level content collections.

Adoption decision:

- Adopt the sidebar information architecture from the mockup and HIG.
- Pilot the implementation with the current custom AppKit `NSStackView` architecture instead of immediately migrating to `NSSplitViewController`.
- Watch `NSSplitViewController` as a later cleanup if manual constraints become brittle or the app needs a more native collapsible sidebar.

### Evidence

Local evidence:

- `docs/design/window-redesign/app-window-componentized-mockup.html`
  - `.app-body`, `.sidebar`, `.content-pane`: lines found by `rg` at 218, 225, 243, 1204, 1205, 1239.
  - sidebar `data-go` entries: lines found by `rg` at 1208-1232.
  - active sidebar update script: lines found by `rg` at 1671 and 1676.
- `InnosDimmer/UI/UnifiedAppWindowController.swift`
  - `UnifiedAppWindowPage`: lines 17-24.
  - page titles/descriptions/symbols: lines 45-100.
  - current layout constants still include home navigation sizing: lines 110-114.
  - persistent controller state: lines 139-169.
  - `installContent()` currently builds `header/statusLabel/bodyView`: lines 319-370.
  - `renderActivePage()` currently replaces `bodyView`: lines 386-418.
  - home-only navigation grid: lines 421-470.
  - Back button creation in `makeDetailPage()`: lines 643-672.
  - `Next actions` home section: lines 780-785.
- `InnosDimmer/UI/MenuBarController.swift`
  - page command routing: lines 203-215.
  - `showAppWindow(focus:)`: lines 295-307.
  - `openSettings()` now routes to app window settings page: lines 322-325.
- `InnosDimmer/UI/ScheduleEditorView.swift`
  - schedule table headers and three-column row structure: lines 280-341.
  - row testing hooks and step/track hooks: lines 230-277.
- `InnosDimmerTests/MenuBarStateTests.swift`
  - current home layout test still expects home navigation metrics: lines 600-615.
  - current detail structure test still expects Back identifier: lines 766-773.
  - existing page content contracts: lines 617-763.

Official sources:

- Apple Developer Documentation, `NSSplitViewController`: https://developer.apple.com/documentation/appkit/nssplitviewcontroller
- Apple Developer Documentation, `NSSplitViewItem.init(sidebarWithViewController:)`: https://developer.apple.com/documentation/appkit/nssplitviewitem/init%28sidebarwithviewcontroller%3A%29
- Apple Human Interface Guidelines, Sidebars: https://developer.apple.com/design/Human-Interface-Guidelines/sidebars

## 2026-06-22 Implementation Result

The remaining simplified-window gaps from this research pass were implemented in the native app window.

Completed:

- The app-window sidebar now renders icon + title only. The shared `UnifiedAppWindowPage.tileDescription` remains for other surfaces that still use it, but the full app window no longer shows those descriptions or repeats them in the sidebar accessibility label.
- The Current status page no longer exposes a duplicate `Settings` command. It keeps `Open popover` and the current pause/resume automation action.
- The Display page no longer exposes `Refresh displays` as a primary header action or `Use automatic` in the saved-selection action row. The underlying selector methods remain available internally so this pass removes confusing visible controls without prematurely deleting recovery behavior.
- The componentized mockup no longer carries stale command-icon rules for removed labels.
- `MenuBarStateTests` now protects this contract with rendered app-window assertions for removed sidebar descriptions, removed display actions, and removed current-page `Settings` command identifier.

Verification:

```bash
xcodebuild test -scheme InnosDimmer -only-testing:InnosDimmerTests/MenuBarStateTests CODE_SIGNING_ALLOWED=NO
```

Result: passed, 60 tests, 0 failures.
