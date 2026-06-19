# 2026-06-19 Schedule Editing Plan First

## Goal

Apply the approved `docs/design/schedule-editing/mockup.html` structure to the native Swift/AppKit app.

User-approved direction:

- Popover remains the compact quick-control surface.
- Popover Schedule section removes the separate `Current` row label.
- Popover Schedule title removes the ambiguous `Next` chip; next-boundary information moves into the status block if it stays visible.
- Popover schedule rows appear directly left-aligned under status.
- Popover Shortcuts display as aligned, table-like rows instead of a multiline text block.
- `Edit schedule` opens the app window/dashboard schedule area, not a separate schedule editor window.
- App window is the full editing hub: current dimming controls, automation state, schedule rows, shortcuts, diagnostics, and save feedback.
- Settings remains general preferences and routes schedule work to the app window.

후행 실행: `구현커밋`

## Plan Lock Status

Status: Implementation-ready plan, pending Operator approval for 후행 `구현커밋`.

This plan supersedes the earlier version that treated `ScheduleEditorWindowController` as the primary schedule editor. The latest mockup and feedback retired that primary separate-window flow.

Approved basis:

- Current review artifact: `docs/design/schedule-editing/mockup.html`.
- Current research: `docs/design/schedule-editing/research.md`.
- Current app code already contains:
  - `MenuBarCommand.openScheduleEditor`
  - `ScheduleEditorView`
  - `ScheduleEditorWindowController`
  - dashboard inline schedule editing
  - Settings schedule navigation
  - dirty worktree changes for `ShortcutAction.openPopover` and default shortcut normalization

Therefore this plan is not greenfield. It is a realignment plan.

## Review-All-In-One Audit Log

### Pass 1 Findings

- Important: the working tree is not a clean plan-only baseline. Current dirty Swift files already include `ShortcutAction.openPopover`, default shortcut count changes from 6 to 7, storage normalization in `DisplayTargetStore`, and popover dismissal changes. The plan must explicitly protect these changes from being overwritten during schedule UI implementation.
- Important: the plan says the popover Shortcuts section should show four focused rows, while the Settings shortcut editor now needs to manage all shortcut actions, including `openPopover`. The plan must state that this is an intentional surface split, not a data mismatch.
- Important: `.openScheduleEditor` is now a semantic compatibility command. The plan must define route behavior clearly enough that implementation can change the destination without renaming all tests and APIs in the same pass.
- Minor: code snippets should show the expected AppKit boundary more concretely: schedule status view, shortcut rows view, dashboard focus route, and tests.

### Pass 1 Remediation

- Added dirty-worktree guardrails, shortcut surface contract, route semantics, and concrete implementation/test snippets.
- Kept the implementation scope focused on document consistency and plan detail; no Swift files should be modified by this review pass.

### Pass 2 Result

- Minor: the new test snippet references `scheduleStatusForTesting()`; the plan must explicitly require adding that test helper if it does not exist.
- Remediation: Commit 1 now includes the helper requirement.
- No blocker or important issue remained after Pass 2.

### Pass 3 Result

- Rechecked required plan-first sections, stale separate-window wording, dirty-worktree guardrails, shortcut surface split, route snippets, test-helper references, and whitespace.
- No remaining blocker, important, or minor issue found in the reviewed plan surface.

## 검토용 결과물

- [Research](design/schedule-editing/research.md)
- [HTML mockup](design/schedule-editing/mockup.html)
- [Dark capture](design/schedule-editing/captures/schedule-editing-dark.png)
- [Light capture](design/schedule-editing/captures/schedule-editing-light.png)

테스트 링크:

- Static local file: `/Users/moonsoo/projects/InnosDimmer/docs/design/schedule-editing/mockup.html`
- No localhost server is required because the mockup is a self-contained HTML artifact.

HTML 생략 사유: 해당 없음. HTML 검토물이 이미 있고, 이번 계획은 그 승인된 목업을 Swift/AppKit에 적용하기 위한 계획이다.

## Research Brief

- Goal: apply the approved schedule-editing mockup direction to the native app without duplicating schedule logic.
- Trigger mode: Pre-Plan Research Gate.
- research.md: `docs/design/schedule-editing/research.md`
- Current project context:
  - The native app already has much of the schedule editing infrastructure.
  - The current mismatch is mostly routing and presentation, not missing schedule persistence.
- Confirmed facts:
  - `MenuBarCommand.openScheduleEditor` exists and currently routes to `MenuBarController.showScheduleEditor()`.
  - `showScheduleEditor()` opens `ScheduleEditorWindowController`.
  - `AppDashboardWindowController` already contains `ScheduleEditorView` and can save via `ScheduleEditorActions`.
  - `MenuBarPopoverView` still renders a Schedule title-row next chip and a `Current` summary label.
  - `MenuBarPopoverView` still renders shortcuts through one multiline `shortcutSummaryLabel`.
  - `SettingsWindowController` uses `SettingsActions.openScheduleEditor`, currently routed by the controller to `showScheduleEditor()`.
  - Schedule saves must continue through `MenuBarController.saveSchedule(_:)`.
- Repeated observations:
  - AppKit view tests already cover command routing, minimum button height, slider drag routing, schedule editor validation, dashboard schedule save, and snapshot capture paths.
- Inference:
  - The safest implementation changes the primary route and popover presentation first, then updates dashboard/settings copy and tests.
  - Removing the schedule window file immediately is optional and riskier than leaving it unused as fallback.
- Recommendation:
  - Keep `MenuBarCommand.openScheduleEditor` as the command name for now, but route it to the app window/dashboard.
  - Add popover-specific schedule status and shortcut-row views instead of adding more multiline labels.
  - Update Settings copy to route to app window schedule editing.
  - Update tests and snapshots after layout changes.
- Source quality:
  - Strongest source: local code and approved mockup.
  - External sources: not used; local evidence is sufficient.
- Open questions:
  - Whether to delete `ScheduleEditorWindowController` now or leave it as an unused fallback. Default: leave it for now, remove primary route.

## Operator 결정 필요 사항

### 결정 1: 별도 스케줄 창 처리

- 상태: 보류됨.
- 맥락: 현재 코드에는 `ScheduleEditorWindowController`가 있지만 최신 목업은 `Edit schedule`이 앱 윈도우로 가는 구조다.
- 선택지:
  - A. 이번 계획에서는 별도 스케줄 창을 primary route에서만 제거하고 파일은 남긴다.
  - B. 이번 계획에서 별도 스케줄 창 파일과 테스트까지 제거한다.
  - C. 별도 스케줄 창을 fallback 메뉴로 남기고 secondary route를 만든다.
- 추천안: A.
- 기본값: A.
- 보류 시 영향: 파일이 남아 있어도 사용자 primary flow는 앱 윈도우로 정리된다. 삭제는 후속 cleanup에서 안전하게 처리할 수 있다.

### 결정 2: 앱 윈도우 schedule focus

- 상태: 없음.
- 맥락: `Edit schedule`이 앱 윈도우를 열 때 사용자가 schedule area를 바로 봐야 한다.
- 선택지:
  - A. 가능하면 `showAppWindow(focus: .schedule)` 형태로 스크롤/초점 이동을 구현한다.
  - B. 스크롤 구현 없이 앱 윈도우를 열고 schedule 섹션을 위쪽으로 배치한다.
  - C. 단순히 기존 앱 윈도우만 연다.
- 추천안: A, 구현이 커지면 B.
- 기본값: A, 단 중단 조건에 걸리면 B.
- 보류 시 영향: 초점 이동이 없으면 사용자가 "Edit schedule"을 눌렀는데 schedule 편집 위치를 찾아야 할 수 있다.

## Design Direction

### Surface Roles

| Surface | Role | Required change |
| --- | --- | --- |
| Popover | Compact quick controls and glanceable summaries | Remove `Current` label, remove title-row `Next` chip, show schedule rows directly, show shortcut rows aligned like a table. |
| App dashboard | Full editing hub | Existing current-state controls and inline schedule editor stay; `Edit schedule` opens this surface. |
| Settings | General preferences | Display target, shortcuts, login item, diagnostics; schedule navigation points to app window. |
| Schedule window | Non-primary fallback or future cleanup target | Do not open from popover/settings primary path in this plan. |

### Mockup-To-App Mapping

| Mockup element | Current Swift/AppKit element | Planned mapping |
| --- | --- | --- |
| `.schedule-summary` | `makeSummaryRow(title: "Status", ...)` + `makeSummaryRow(title: "Current", ...)` | Replace with status container + direct `ScheduleSummaryRowsView`. |
| `Next boundary 19:00` inside status | `MenuBarViewModel.scheduleNextLabel` shown in title chip | Move into status detail; no title-row chip. |
| `.shortcut-table` | `shortcutSummaryLabel` multiline string | Add row-based shortcut summary view or row model. |
| `Edit schedule opens app window schedule area` | `.openScheduleEditor -> showScheduleEditor()` | Change to `.openScheduleEditor -> showAppWindow(focus: .schedule)` or `showAppWindow()`. |
| App window hub | `AppDashboardWindowController` | Keep current controls and inline schedule editing; tune ordering/copy to match route. |
| Settings route | `Open schedule editor` | Change copy and action behavior to app window schedule route. |

### Terminology And Data Mapping

| UI copy | Code field/API | Keep or change |
| --- | --- | --- |
| Blue reduction | `ScheduleEntry.blueReduction` | Keep. |
| Blue reduction | `BrightnessState.targetBlueReduction` | Keep. |
| Schedule rows | `ScheduleEditorView(rowCount: 3)` | Keep fixed 3 rows; add/remove remains out of scope. |
| Edit schedule | `MenuBarCommand.openScheduleEditor` | Keep command name temporarily, change route. |
| Next boundary | `MenuBarViewModel.scheduleNextLabel` | Replace with status detail or rename internally. |

## Current Code Contracts

- `MenuBarCommand.buttonCommands` is test-covered; changing buttons requires updating `MenuBarStateTests`.
- `ProgressTrackView` already supports drag-based percentage changes and must be preserved.
- `PopoverCommandButton.minimumHeight` is 30 and must not regress.
- `ScheduleSummaryRowsView.plainSummary` supports tests; visual changes should preserve or intentionally update this test surface.
- `MenuBarViewModel.shortcutSummary` currently returns multiline text; a row-based shortcut view should either keep a plain testing summary or expose row data for tests.
- `AppDashboardWindowController.saveScheduleFromEditor()` already routes through injected `ScheduleEditorActions`.
- `MenuBarController.saveSchedule(_:)` is the only schedule save path that updates runtime state, diagnostics, active schedule decision, and timers.
- `SettingsActions.openScheduleEditor` already exists, so Settings routing can change without adding a new action shape unless copy clarity demands a rename.
- `ShortcutAction.openPopover` may already exist in the dirty worktree. If present, implementation must preserve it and treat it as a Settings/full-shortcut concern, not a reason to expand the compact popover shortcut summary beyond four focused adjustment rows.

## Dirty Worktree Guard

Before any 후행 `구현커밋` execution, the implementer must re-read current dirty diffs for these files and work with them instead of overwriting them:

- `InnosDimmer/Domain/ShortcutBinding.swift`
- `InnosDimmer/Services/DisplayTargetStore.swift`
- `InnosDimmer/UI/MenuBarController.swift`
- `InnosDimmer/UI/MenuBarPopoverView.swift`
- `InnosDimmer/UI/SettingsWindowController.swift`
- `InnosDimmerTests/DisplayTargetStoreTests.swift`
- `InnosDimmerTests/HotkeyBindingTests.swift`
- `InnosDimmerTests/MenuBarStateTests.swift`

Current dirty-code implications observed during review:

| Existing dirty change | Plan implication |
| --- | --- |
| `ShortcutAction.openPopover` added | Settings/full shortcut editor should include it; popover shortcut summary should still show only four focused adjustment shortcuts. |
| `ShortcutBinding.defaultBindings` may have 7 entries | Tests that assert full shortcut counts must expect 7 where they are testing the full binding set. |
| `normalizedForStorage()` backfills missing shortcut bindings | Schedule UI changes must not remove or bypass shortcut normalization. |
| `MenuBarCommand.openPopover` and popover dismissal helpers may exist | Route changes for `.openScheduleEditor` must not regress popover open/dismiss behavior. |
| Snapshot PNGs are dirty | Capture refresh should be a deliberate verification step, not accidental churn mixed into logic commits. |

## Shortcut Surface Contract

The app has two different shortcut surfaces:

| Surface | Shows | Why |
| --- | --- | --- |
| Popover Shortcuts summary | Four focused adjustment shortcuts: brightness up/down, blue up/down | The popover is a compact quick-control surface. This matches the approved mockup and avoids adding shortcut-management density. |
| Settings shortcut editor | All `ShortcutAction.allCases`, including `quickDisableOverlay`, `restorePreviousDimming`, and `openPopover` if present | Settings is the full preference surface and must keep shortcut persistence complete. |
| App dashboard shortcut summary | May show focused hints or a concise status, but should not become a full shortcut editor | The dashboard is the editing hub for dimming/schedule; shortcut editing remains Settings-owned. |

This distinction is intentional. Do not "fix" the popover by adding every shortcut action there.

## Architecture Plan

### Existing flow to preserve

```text
ScheduleEditorView.editedSchedule()
  -> ScheduleEditorActions.updateSchedule([ScheduleEntry])
  -> MenuBarController.saveSchedule(_:)
  -> DisplayTargetStore.saveSchedule(_:)
  -> SettingsSnapshot.replacingSchedule(_:)
  -> MenuBarController.scheduleEntries = snapshot.schedule
  -> record(.schedule, ...)
  -> applyScheduleDecision()
  -> scheduleNextBoundaryTimerIfRunning()
```

### Proposed popover schedule status

Illustrative only:

```swift
struct MenuBarViewModel: Equatable {
    var scheduleStatusTitle: String
    var scheduleStatusDetail: String
    var scheduleSummary: String
    var shortcutRows: [ShortcutSummaryRow]
}

struct ShortcutSummaryRow: Equatable {
    var title: String
    var keyLabel: String
}
```

More concrete AppKit boundary:

```swift
private final class ScheduleStatusSummaryView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")

    func update(title: String, detail: String?) {
        titleLabel.stringValue = title
        detailLabel.stringValue = detail ?? ""
        detailLabel.isHidden = detail == nil
    }
}
```

Expected view model labels:

```swift
// Paused with known resume boundary
scheduleStatusTitle = "Automation paused until 19:00"
scheduleStatusDetail = "Next boundary 19:00"

// Active with known next boundary
scheduleStatusTitle = "Automation active"
scheduleStatusDetail = "Next boundary 19:00"

// No schedule
scheduleStatusTitle = "Automation active"
scheduleStatusDetail = "No schedule configured"
```

### Proposed route change

Illustrative only:

```swift
private func perform(_ command: MenuBarCommand, source: BrightnessCommandSource) {
    switch command {
    case .openScheduleEditor:
        showAppWindow(focus: .schedule)
    ...
    }
}
```

If focus support is too broad in the implementation pass:

```swift
case .openScheduleEditor:
    showAppWindow()
```

Preferred narrow focus API:

```swift
enum AppDashboardFocusTarget {
    case schedule
}

private func showAppWindow(focus: AppDashboardFocusTarget? = nil) {
    let controller = dashboardWindowController ?? AppDashboardWindowController(
        actions: MenuBarActions { [weak self] command in
            self?.perform(command)
        },
        scheduleActions: makeScheduleEditorActions()
    )
    dashboardWindowController = controller
    refreshAppWindow()
    controller.showWindow(nil)
    controller.focus(focus)
    NSApp.activate(ignoringOtherApps: true)
}
```

If `focus(_:)` requires invasive scroll-view changes, use `showAppWindow()` in Commit 2 and move visible schedule placement/focus polish to Commit 3.

### Proposed shortcut table view

Illustrative only:

```swift
private final class ShortcutSummaryRowsView: NSView {
    private let stack = NSStackView()
    private(set) var plainSummary = ""

    func update(shortcuts: [ShortcutBinding]) {
        // brightness up/down and blue up/down only
        // left column hugs low, right keycap column fixed/aligned
    }
}
```

Implementation detail:

- Keep the popover shortcut list focused on four direct adjustment shortcuts.
- Leave Quick disable / Restore previous shortcut editing visible in Settings, not in the compact popover.
- If `ShortcutAction.openPopover` exists, it belongs to Settings and hotkey registration tests, not the compact popover summary.

Test-facing row model snippet:

```swift
struct ShortcutSummaryRow: Equatable {
    let action: ShortcutAction
    let title: String
    let keyLabel: String
}

private static let popoverShortcutActions: [ShortcutAction] = [
    .brightnessUp,
    .brightnessDown,
    .blueReductionUp,
    .blueReductionDown
]
```

The implementation may keep `shortcutSummaryForTesting()` for plain text compatibility, but it should derive from row data so visual and test representations cannot drift.

## Skill Routing Manifest

| Phase | Required skills | Optional skills | Evidence |
| --- | --- | --- | --- |
| Commit 1: Align popover Schedule and Shortcuts with approved mockup | `구현커밋` | `디자인올인원` | Directly implements `docs/design/schedule-editing/mockup.html` popover feedback in `MenuBarPopoverView.swift`. |
| Commit 2: Route schedule editing to app dashboard instead of separate window | `구현커밋` | `review-all-in-one` | Changes `.openScheduleEditor` primary path in `MenuBarController.swift` while preserving save side effects. |
| Commit 3: Tune app dashboard as the schedule editing hub | `구현커밋` | `디자인올인원`, `테스트` | Dashboard already has inline schedule editing; needs copy/layout/focus alignment with mockup. |
| Commit 4: Update Settings schedule navigation and tests | `구현커밋` | `review-all-in-one` | Settings must remain general preferences and route schedule work to app window. |
| Commit 5: Refresh verification artifacts and focused tests | `구현커밋`, `테스트` | `qa-gate` | Updates tests/captures after native UI changes and checks dark/light layout. |
| Final Gate | `review-all-in-one`, `테스트` | `review-swarm`, `qa-gate` | Review for duplicated schedule parsing, route drift, layout clipping, and regression risk. |

## Implementation Plan

### Commit 1: Align popover Schedule and Shortcuts with approved mockup

- 대상 파일:
  - `InnosDimmer/UI/MenuBarPopoverView.swift`
  - `InnosDimmerTests/MenuBarStateTests.swift`
- 변경:
  - Replace popover Schedule title trailing `scheduleNextChip` with no trailing chip.
  - Replace `makeSummaryRow(title: "Current", value: scheduleSummaryRowsView)` with direct left-aligned schedule rows under a status block.
  - Convert automation status into a compact status container:
    - title: `Automation paused until 19:00` or `Automation active`
    - detail: `Next boundary 19:00` or equivalent when available.
  - Add a row-based shortcut summary view for four focused shortcuts:
    - Brightness up
    - Brightness down
    - Blue up
    - Blue down
  - Preserve `Quick disable` and `Restore previous` under Quick controls.
  - Preserve `Settings` + `Open app window` under Shortcuts.
- 검증:
  - Update `testMenuBarViewModelUsesStateValues`.
  - Update `testMenuBarPopoverUpdateRefreshesVisibleStateAndDiagnostics`.
  - Keep `testMenuBarPopoverCommandButtonsKeepMinimumActionHeight`.
  - Add `scheduleStatusForTesting()` or an equivalent test helper if schedule status moves into a dedicated view.
  - Add or update a focused assertion for row-based shortcuts:

    ```swift
    XCTAssertEqual(
        view.shortcutSummaryForTesting(),
        "Brightness up  ⌥⇧↑\nBrightness down  ⌥⇧↓\nBlue up  ⌥⇧→\nBlue down  ⌥⇧←"
    )
    ```

  - Add or update a focused assertion for schedule status:

    ```swift
    XCTAssertEqual(view.scheduleSummaryForTesting(), "10:15 · ☀ 66% · ◐ 21%")
    XCTAssertFalse(view.scheduleStatusForTesting().contains("Current"))
    ```

  - Run:
    - `xcodebuild test -scheme InnosDimmer -only-testing:InnosDimmerTests/MenuBarStateTests`
- 성공 기준:
  - No visible `Current` row label in popover Schedule section.
  - No title-row `Next` chip in popover Schedule section.
  - Shortcut rows have stable left/right alignment and do not rely on a single multiline label.
  - Drag/step controls and command buttons still route.
- 중단 조건:
  - Stop if replacing `shortcutSummaryLabel` requires broad dashboard/settings rewrites. Scope it to popover-only first.

### Commit 2: Route schedule editing to app dashboard instead of separate window

- 대상 파일:
  - `InnosDimmer/UI/MenuBarController.swift`
  - `InnosDimmer/UI/MenuBarPopoverView.swift`
  - `InnosDimmerTests/MenuBarStateTests.swift`
- 변경:
  - Change `.openScheduleEditor` handling from `showScheduleEditor()` to `showAppWindow(focus: .schedule)` if implemented, otherwise `showAppWindow()`.
  - Add a dashboard focus mechanism only if it stays narrow:
    - a small enum such as `AppDashboardFocusTarget.schedule`;
    - a method on `AppDashboardWindowController` to scroll or make the schedule editor visible.
  - Update diagnostics/copy so primary route does not say it opened the separate schedule editor.
  - Keep `ScheduleEditorWindowController` in the codebase for now unless implementation proves removal is smaller.
- 코드 스니펫:

  ```swift
  case .openScheduleEditor:
      showAppWindow(focus: .schedule)
  ```

  If the focus enum is deferred:

  ```swift
  case .openScheduleEditor:
      showAppWindow()
  ```

- 검증:
  - Replace or rename `testMenuBarControllerRoutesOpenScheduleEditorWithoutApplyingDimmingCommand`.
  - Add/adjust a test proving `.openScheduleEditor` routes to app window without applying dimming.
  - Preserve any `openPopover` tests if they exist in the dirty worktree:

    ```swift
    menuBarController.perform(.openPopover)
    XCTAssertTrue(menuBarController.popoverIsShownForTesting())
    ```

  - Keep dashboard route tests.
  - Run:
    - `xcodebuild test -scheme InnosDimmer -only-testing:InnosDimmerTests/MenuBarStateTests`
- 성공 기준:
  - Popover `Edit schedule` opens the app window/dashboard.
  - No separate schedule editor window opens from the primary path.
  - No dimming command is applied merely by opening schedule editing.
- 중단 조건:
  - If focus/scroll support causes fragile AppKit layout work, fall back to `showAppWindow()` and place schedule editing visibly in the dashboard.

### Commit 3: Tune app dashboard as the schedule editing hub

- 대상 파일:
  - `InnosDimmer/UI/MenuBarPopoverView.swift`
  - `InnosDimmerTests/MenuBarStateTests.swift`
  - dashboard capture outputs under `docs/design/popover-redesign/captures/`
- 변경:
  - Keep current-state controls editable:
    - brightness value, drag track, `-`, `+`
    - blue reduction value, drag track, `-`, `+`
  - Keep manual actions visible:
    - Quick disable
    - Restore previous
    - Pause/Resume automation
    - Settings
  - Keep inline `ScheduleEditorView` as the schedule editing surface.
  - Remove or soften the dashboard schedule `Current` label if it conflicts with the approved hub structure.
  - Add/keep shortcut summary in the dashboard using aligned rows where practical.
  - Keep diagnostics visible in the dashboard, not in the popover.
- 코드 스니펫:

  ```swift
  let scheduleEditor = makeSection(
      title: "Automation schedule",
      views: [
          scheduleEditorView,
          scheduleSaveButton,
          scheduleStatusLabel
      ]
  )
  ```

  The dashboard may show a concise schedule status above the editor, but it should not reintroduce the popover's old `Current` label as the primary schedule affordance.
- 검증:
  - `testAppDashboardButtonsRouteEditableCommands`
  - `testAppDashboardCommandButtonsKeepMinimumActionHeight`
  - `testAppDashboardTracksRouteAbsolutePercentageCommands`
  - `testAppDashboardSavesInlineScheduleThroughInjectedAction`
  - dashboard snapshot capture when requested.
  - Run:
    - `xcodebuild test -scheme InnosDimmer -only-testing:InnosDimmerTests/MenuBarStateTests`
- 성공 기준:
  - Dashboard remains more capable than the popover.
  - Schedule editing is available inline without opening another window.
  - Existing schedule save path remains unchanged.
  - Dashboard layout is scrollable or fits without clipping in dark/light.
- 중단 조건:
  - Stop if adding shortcut rows makes the dashboard too tall without scroll support.

### Commit 4: Update Settings schedule navigation and tests

- 대상 파일:
  - `InnosDimmer/UI/SettingsWindowController.swift`
  - `InnosDimmer/UI/MenuBarController.swift`
  - `InnosDimmerTests/HotkeyBindingTests.swift`
- 변경:
  - Change Settings schedule button copy from `Open schedule editor` to app-window route language, such as `Open app window schedule`.
  - Route `SettingsActions.openScheduleEditor` to the same app window schedule path used by the popover.
  - Keep Settings focused on:
    - target display;
    - startup/login;
    - shortcut bindings;
    - diagnostics export;
    - schedule summary/navigation only.
  - Do not reintroduce schedule row editing into Settings.
- 코드 스니펫:

  ```swift
  let openScheduleButton = NSButton(
      title: "Open app window schedule",
      target: self,
      action: #selector(openScheduleEditorPressed)
  )
  ```

  Controller wiring should reuse the existing callback unless a rename is done in the same commit:

  ```swift
  openScheduleEditor: { [weak self] in
      self?.showAppWindow(focus: .schedule)
  }
  ```

- 검증:
  - Update `testSettingsWindowRoutesScheduleEditorNavigation` naming/expectations.
  - Keep shortcut customization tests passing.
  - Run:
    - `xcodebuild test -scheme InnosDimmer -only-testing:InnosDimmerTests/SettingsWindowShortcutCustomizationTests`
    - `xcodebuild test -scheme InnosDimmer -only-testing:InnosDimmerTests/HotkeyBindingTests`
- 성공 기준:
  - Settings still saves shortcut changes.
  - Settings schedule navigation reaches app window route.
  - Settings copy no longer implies a separate schedule editor window.
- 중단 조건:
  - Stop if route reuse requires changing the `SettingsActions` public shape broadly; prefer keeping the existing callback name and only changing behavior/copy.

### Commit 5: Refresh verification artifacts and focused tests

- 대상 파일:
  - `InnosDimmerTests/MenuBarStateTests.swift`
  - `docs/design/popover-redesign/captures/actual-dark.png`
  - `docs/design/popover-redesign/captures/actual-light.png`
  - `docs/design/popover-redesign/captures/dashboard-dark.png`
  - `docs/design/popover-redesign/captures/dashboard-light.png`
  - `docs/design/popover-redesign/captures/comparison-report.md` if updated manually
- 변경:
  - Run focused tests after implementation.
  - Refresh design snapshots only after UI changes are stable.
  - Keep generated capture changes separated from code changes if the implementation workflow wants separate commits.
- 검증:
  - Focused:
    - `xcodebuild test -scheme InnosDimmer -only-testing:InnosDimmerTests/MenuBarStateTests`
    - `xcodebuild test -scheme InnosDimmer -only-testing:InnosDimmerTests/HotkeyBindingTests`
    - `xcodebuild test -scheme InnosDimmer -only-testing:InnosDimmerTests/ScheduleEngineTests`
    - `xcodebuild test -scheme InnosDimmer -only-testing:InnosDimmerTests/DisplayTargetStoreTests`
  - Build:
    - `xcodebuild -scheme InnosDimmer -configuration Release build CODE_SIGNING_ALLOWED=NO`
  - Full suite:
    - `xcodebuild test -scheme InnosDimmer`
- 성공 기준:
  - Focused tests pass.
  - Release build passes.
  - If full suite still fails due to previously known isolation issues, document exact failures and confirm no new failures in touched surfaces.
- 중단 조건:
  - Stop if snapshot generation changes unrelated assets beyond the expected four popover/dashboard captures.

## Plan Quality Check

- Alternative considered: keep `Edit schedule` opening `ScheduleEditorWindowController`.
  - Rejected because the latest approved mockup says too many windows reduce readability and schedule editing should happen in the app window.
- Alternative considered: delete `ScheduleEditorWindowController` immediately.
  - Deferred because removing the file is cleanup, not required to satisfy the primary user flow, and may create unnecessary project/test churn.
- Alternative considered: keep shortcut display as a multiline label.
  - Rejected because the user specifically asked for table-like alignment.
- Why this plan:
  - It follows the approved mockup while preserving existing schedule save infrastructure and tests.
- Tradeoff:
  - Keeping `MenuBarCommand.openScheduleEditor` as the internal name is semantically imperfect, but it avoids broad command churn in the first implementation. Revisit after route behavior is stable.
- What this plan may still miss:
  - Exact dashboard scroll/focus behavior in AppKit.
  - Whether `ScheduleEditorWindowController` should be removed in a later cleanup.
  - Whether shortcut row view should be shared between popover/dashboard/settings or kept popover-specific.
- When to stop and revise:
  - Stop if the app-window route cannot make schedule editing discoverable.
  - Stop if schedule save routing bypasses `MenuBarController.saveSchedule(_:)`.
  - Stop if popover no longer fits within `preferredContentSize`.

## 구현 후 검토 리스트

- 회귀 확인:
  - Popover brightness/blue controls still support button and drag changes.
  - Quick disable and Restore previous remain visible and route commands.
  - Pause/Resume automation behavior unchanged.
  - Settings still saves display/shortcut/login/diagnostics behavior.
  - Schedule saves still apply current decision and boundary timer side effects.
- 검증 확인:
  - `xcodebuild test -scheme InnosDimmer -only-testing:InnosDimmerTests/MenuBarStateTests`
  - `xcodebuild test -scheme InnosDimmer -only-testing:InnosDimmerTests/HotkeyBindingTests`
  - `xcodebuild test -scheme InnosDimmer -only-testing:InnosDimmerTests/ScheduleEngineTests`
  - `xcodebuild test -scheme InnosDimmer -only-testing:InnosDimmerTests/DisplayTargetStoreTests`
  - `xcodebuild -scheme InnosDimmer -configuration Release build CODE_SIGNING_ALLOWED=NO`
- 리뷰 관점:
  - No duplicate schedule persistence.
  - No direct `UserDefaults` write from UI.
  - No reintroduced diagnostics block in popover.
  - No separate schedule window opens from primary route.
  - No layout clipping in dark/light popover/dashboard captures.
- Operator 재확인:
  - Confirm native popover visually matches the approved HTML direction.
  - Confirm app window route feels readable enough without a separate schedule window.

## Handoff To 구현커밋

- Source plan: `docs/2026-06-19-schedule-editing-plan-first.md`
- Research: `docs/design/schedule-editing/research.md`
- Review artifact: `docs/design/schedule-editing/mockup.html`
- Test link: static local file `/Users/moonsoo/projects/InnosDimmer/docs/design/schedule-editing/mockup.html`
- Execution rule: implement Commit 1 through Commit 5 in order.
- Scope guard: do not implement dynamic add/remove schedule rows in this plan.
- UI guard: popover must stay compact and dashboard must stay the full editing hub.
- Route guard: `.openScheduleEditor` primary path opens app window/dashboard, not `ScheduleEditorWindowController`.
- Save-path guard: schedule UI must call a controller-supplied action that reaches `MenuBarController.saveSchedule(_:)`.
- Cleanup guard: deleting `ScheduleEditorWindowController` is not required for this plan unless it becomes the smallest safe implementation.

## Next Plan Backlog

### Dynamic schedule rows: add/remove actual implementation

- Goal:
  - Let the user add and remove schedule rows for real, not just adjust existing rows.
- Needs research:
  - Minimum/maximum row count.
  - Empty schedule handling versus current `SettingsPersistenceError.emptySchedule`.
  - Duplicate time behavior.
  - Sort order and focus behavior after add/remove.
- Likely files:
  - `ScheduleEditorView`
  - `SettingsSnapshot`
  - `DisplayTargetStore`
  - `ScheduleEngineTests`
  - `DisplayTargetStoreTests`
  - UI snapshot tests
- Verification:
  - Add row creates a valid default row.
  - Remove row cannot create invalid empty schedule.
  - Save sorts rows and preserves runtime schedule side effects.

### Schedule editor window cleanup

- Goal:
  - Decide whether to delete `ScheduleEditorWindowController` after app-window route is proven.
- Trigger:
  - Use only after the app window schedule route passes native UI review.
