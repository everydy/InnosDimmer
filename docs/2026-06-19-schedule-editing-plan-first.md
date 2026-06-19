# 2026-06-19 Schedule Editing Plan First

## Goal

Make schedule editing easier by splitting it into the right UI surfaces:

- Popover: show schedule state and open a focused schedule editor.
- Schedule window: edit only schedule rows.
- App dashboard: edit schedule inline without opening another window.
- Settings window: remain general settings and stop being the primary schedule editor.
- Schedule add/remove rows: defer to the next plan; this plan implements editing existing schedule values and the correct save/routing surfaces first.

후행 실행: `구현커밋`

## Plan Lock Status

Status: Approved for 후행 `구현커밋`.

Approved basis:

- Current review artifact: `docs/design/schedule-editing/mockup.html`.
- Current code default schedule is:
  - `09:00` · `80%` brightness / `12%` blue reduction
  - `19:00` · `45%` brightness / `32%` blue reduction
  - `23:00` · `25%` brightness / `58%` blue reduction
- Popover action layout is fixed as:
  - Row 1: `Edit schedule` + `Pause automation`
  - Row 2: `Quick disable` + `Restore previous`
- Schedule window edits existing schedule rows only in this plan.
- App dashboard must be an expanded popover: keep current-state brightness/blue controls and add inline schedule editing.
- Dynamic add/remove schedule rows are explicitly deferred to `Next Plan Backlog`.

## 검토용 결과물

- [Research](design/schedule-editing/research.md)
- [HTML mockup](design/schedule-editing/mockup.html)
- [Dark capture](design/schedule-editing/captures/schedule-editing-dark.png)
- [Light capture](design/schedule-editing/captures/schedule-editing-light.png)

테스트 링크:

- Static local file: `/Users/moonsoo/projects/InnosDimmer/docs/design/schedule-editing/mockup.html`
- No localhost server is required because the mockup is a self-contained HTML artifact.

HTML 생략 사유: 해당 없음. HTML 검토물이 `docs/design/schedule-editing/mockup.html`에 이미 존재한다.

## Research Brief

- Trigger mode: Pre-Plan Research Gate.
- research.md: `docs/design/schedule-editing/research.md`
- Confirmed facts:
  - `SettingsWindowController` currently owns schedule UI inside a broader settings form.
  - `ScheduleEntry` is the persisted row model: `minuteOfDay`, `brightness`, `warmth`.
  - `DisplayTargetStore.saveSchedule(_:)` validates and persists schedule entries.
  - `MenuBarController.saveSchedule(_:)` applies runtime side effects after saving, including diagnostics, current schedule decision, and boundary timer rescheduling.
  - `ScheduleEngine` owns active entry, next boundary, and manual override logic.
- Inference:
  - New UI should not introduce a new persistence path.
  - A shared schedule editor view/helper is safer than duplicating row parsing in Settings, Schedule window, and Dashboard.
- Recommendation:
  - Add a schedule-specific command/action and shared schedule editor component.
  - Route popover `Edit schedule` to a focused schedule window.
  - Embed the same editor behavior inline in the dashboard.
  - Keep current-state controls in the dashboard; the dashboard is an expanded popover, not an automation-only screen.
  - Demote schedule editing in Settings to a summary + open schedule editor after the focused schedule window save path is available.

## Review-All-In-One Audit Log

### Pass 1 Findings

- Important: `blue reduction` is user-facing copy, but the persisted/runtime field is still named `warmth` in `ScheduleEntry.warmth` and `BrightnessState.targetWarmth`. The plan must preserve this mapping until a separate data-model rename plan exists.
- Important: `MenuBarCommand.buttonCommands` is test-covered as the popover command inventory. Adding `openScheduleEditor` requires updating that list and the routing tests together.
- Important: schedule saving must keep routing through `MenuBarController.saveSchedule(_:)`; view/controller code must not call `DisplayTargetStore.saveSchedule(_:)` directly.
- Minor: the manifest used optional skill names that should be normalized to locally available skill names.

### Pass 2 Result

- The plan now includes codebase contracts, terminology mapping, implementation snippets, and per-commit test expectations.
- No remaining plan-blocking inconsistency found in the reviewed surface.

### Pass 3 Result

- Rechecked required plan-first sections, stale skill names, `SettingsActions` bridge, `openScheduleEditor` command routing, `warmth` data guard, and whitespace.
- No additional plan-blocking issue found.

## Operator 결정 필요 사항

### 결정 1: v1 스케줄 행 개수

- 상태: 결정됨.
- 맥락: 현재 `SettingsWindowController.Layout.scheduleEntryCount = 3`이고 기본 스케줄도 3개다.
- 선택지:
  - A. 이번 plan은 3행 값 편집과 저장 흐름만 구현하고, add/remove 실제 구현은 다음 plan으로 넘긴다.
  - B. 이번 plan에서 add/remove까지 실제 구현한다.
  - C. add/remove UI도 목업에서 제거하고 3행 고정만 보여준다.
- 적용값: A.
- 구현 영향: 이번 구현 범위는 기존 row 값 편집, validation, 저장 흐름으로 제한한다. 다음 plan에서 `ScheduleEntry` 동적 행 추가/삭제 UX, validation, 테스트를 별도 단위로 다룬다.

### 결정 2: Settings 창의 schedule 섹션 처리

- 상태: 결정됨.
- 맥락: 사용자는 settings에서 schedule을 조절하는 방식보다 별도 schedule 버튼/창을 선호한다고 말했다.
- 선택지:
  - A. Settings에서 schedule form을 제거하고 `Open schedule editor` 요약만 둔다.
  - B. Settings 안에도 같은 schedule editor를 계속 둔다.
  - C. 이번 구현에서는 Settings는 유지하고 popover/dashboard만 추가한다.
- 적용값: A.
- 구현 영향: Settings는 general preferences 역할로 정리한다. schedule editing은 focused schedule window와 dashboard inline editor가 맡는다.

현재 추가 질문 없음. 후행 구현은 위 적용값으로 진행한다.

## Design Direction

### Surface Roles

| Surface | New role | What changes |
| --- | --- | --- |
| Popover | quick controls + schedule entry point | Add `Edit schedule` beside `Pause automation`; put `Quick disable` beside `Restore previous`; keep summary; do not inline schedule table. |
| Schedule window | focused schedule editor | New window/controller for existing schedule rows only; add/remove is visible as next-plan scope, not implemented in this plan. |
| App dashboard | expanded popover/full control surface | Keep current-state brightness/blue controls and add inline editable schedule rows next to diagnostics. |
| Settings | general preferences | Display, shortcuts, login item, diagnostics; schedule becomes secondary navigation. |

### Review Artifact Notes

The HTML mockup shows three states together:

1. Popover with `Edit schedule` + `Pause automation`, then `Quick disable` + `Restore previous`.
2. Dedicated `InnosDimmer Schedule` window for existing schedule rows.
3. Dashboard with current-state controls and inline `Inline automation schedule`.

It uses the existing dark-first visual language from the popover/dashboard redesign and includes a light-theme preview.

### Terminology And Data Mapping

| UI / copy | Current code field | Keep or change in this plan | Reason |
| --- | --- | --- | --- |
| Blue reduction | `ScheduleEntry.warmth` | Keep field name; change UI copy only | Avoid schema churn while the visual language moves away from "warmth". |
| Blue reduction | `BrightnessState.targetWarmth` | Keep field name; route through `.setWarmth(Int)` | Existing dimming commands and tests already use this runtime field. |
| Schedule row count | `SettingsWindowController.Layout.scheduleEntryCount = 3` | Keep fixed 3 rows | Add/remove rows are next-plan scope. |
| Current default rows | `ScheduleEntry.defaultSchedule` | Preserve values | Mockup and tests use `09:00/19:00/23:00` with `12/32/58` blue values. |
| Schedule save side effects | `MenuBarController.saveSchedule(_:)` | Preserve route | Applies current schedule decision, diagnostics, and boundary timer refresh. |

### Current Code Contracts

- `MenuBarCommand` currently has no `.openScheduleEditor`; it lives in `InnosDimmer/UI/MenuBarPopoverView.swift`.
- `MenuBarController.perform(_:)` currently handles brightness, blue reduction, quick disable, restore, settings, dashboard, and pause commands.
- `SettingsActions.updateSchedule` already has the right closure shape for saving schedule rows without exposing `DisplayTargetStore` to view code.
- `SettingsActions` currently has no `openScheduleEditor` callback; Settings demotion needs one or an equivalent controller-supplied command bridge.
- `SettingsWindowController.scheduleFromFields()` currently owns `HH:mm` and `0...100` validation; this logic must move into the shared schedule editor boundary or be wrapped by it.
- `AppDashboardWindowController` currently lives in `MenuBarPopoverView.swift`, not a separate dashboard file.
- `MenuBarStateTests.testMenuBarPopoverButtonsRouteEveryCommand()` iterates over `MenuBarCommand.buttonCommands`; this must include any new popover command.

## Architecture Plan

### Existing flow to preserve

```text
Schedule UI
  -> updateSchedule([ScheduleEntry])
  -> MenuBarController.saveSchedule(_:)
  -> DisplayTargetStore.saveSchedule(_:)
  -> SettingsSnapshot.replacingSchedule(_:)
  -> applyScheduleDecision()
  -> scheduleNextBoundaryTimerIfRunning()
  -> refresh popover/dashboard
```

### Proposed command shape

Illustrative only. Use this shape unless the implementation finds a narrower existing project pattern:

```swift
enum MenuBarCommand: Equatable, Hashable {
    case brightnessDown
    case brightnessUp
    case setBrightness(Int)
    case warmthDown
    case warmthUp
    case setWarmth(Int)
    case openScheduleEditor
    case pauseAutomation
    case quickDisable
    case restorePrevious
    case openAppWindow
    case openSettings
}
```

`buttonCommands` must be updated with `.openScheduleEditor` in the same commit that adds the popover button:

```swift
static let buttonCommands: [MenuBarCommand] = [
    .brightnessDown,
    .brightnessUp,
    .warmthDown,
    .warmthUp,
    .openScheduleEditor,
    .pauseAutomation,
    .quickDisable,
    .restorePrevious,
    .openAppWindow,
    .openSettings
]
```

### Proposed shared editor boundary

Illustrative only:

```swift
@MainActor
final class ScheduleEditorView: NSView {
    func update(schedule: [ScheduleEntry])
    func editedSchedule() throws -> [ScheduleEntry]
}
```

The actual implementation may choose an `NSView` helper or a small controller, but the parsing, rendering, and validation should be shared.

### Proposed schedule action boundary

Illustrative only. The schedule window and dashboard can use this smaller wrapper instead of receiving full `SettingsActions`.

```swift
struct ScheduleEditorActions {
    var updateSchedule: @MainActor ([ScheduleEntry]) -> Result<SettingsSnapshot, Error>
}
```

Construct it from `MenuBarController` so the save path stays centralized:

```swift
private func makeScheduleEditorActions() -> ScheduleEditorActions {
    ScheduleEditorActions(
        updateSchedule: { [weak self] schedule in
            self?.saveSchedule(schedule) ?? .failure(SettingsRuntimeError.unavailable)
        }
    )
}
```

### Proposed editor validation contract

Illustrative only. This contract should preserve the current `SettingsWindowController` validation behavior while making it reusable.

```swift
enum ScheduleEditorError: LocalizedError, Equatable {
    case invalidTime(row: Int)
    case invalidPercent(row: Int, field: String)

    var errorDescription: String? {
        switch self {
        case .invalidTime(let row):
            return "Schedule row \(row) needs a time in HH:mm format."
        case .invalidPercent(let row, let field):
            return "Schedule row \(row) needs \(field) from 0 to 100."
        }
    }
}
```

Parsing should return `ScheduleEntry(minuteOfDay:brightness:warmth:)` and should keep `field: "blue reduction"` for the third column.

### Proposed save-result handling

Illustrative only. The schedule window and dashboard should follow this state update shape:

```swift
do {
    switch actions.updateSchedule(try scheduleEditor.editedSchedule()) {
    case .success(let snapshot):
        scheduleEditor.update(schedule: snapshot.schedule)
        report("Schedule saved.")
    case .failure(let error):
        report(error.localizedDescription, isError: true)
    }
} catch {
    report(error.localizedDescription, isError: true)
}
```

Do not call `DisplayTargetStore.saveSchedule(_:)` from `ScheduleEditorView`, `ScheduleEditorWindowController`, or `AppDashboardWindowController`.

### Proposed settings bridge

Illustrative only. When Settings is demoted to summary/navigation, add a narrow open callback instead of making Settings own schedule saving again.

```swift
struct SettingsActions {
    var selectDisplay: @MainActor (DisplayIdentity?) -> Result<SettingsSnapshot, Error>
    var updateShortcuts: @MainActor ([ShortcutBinding]) -> Result<SettingsSnapshot, Error>
    var setLaunchAtLogin: @MainActor (Bool) -> Result<LoginItemStatus, Error>
    var exportDiagnostics: @MainActor () -> Result<Data, Error>
    var openScheduleEditor: @MainActor () -> Void
}
```

If `updateSchedule` remains temporarily for compatibility during Commit 2, remove it from Settings usage in Commit 5.

## Skill Routing Manifest

| Phase | Required skills | Optional skills | Evidence |
| --- | --- | --- | --- |
| Commit 1: Add schedule command and focused editor shell | `구현커밋` | `디자인올인원` | Needs new command routing and AppKit shell based on `docs/design/schedule-editing/mockup.html`. |
| Commit 2: Extract fixed-row shared schedule editor component | `구현커밋` | `review-all-in-one` | Prevents duplicate parsing across Settings, Schedule window, and Dashboard while deferring add/remove rows. |
| Commit 3: Wire popover and schedule window save flow | `구현커밋` | `테스트` | Must preserve `MenuBarController.saveSchedule(_:)` side effects from research. |
| Commit 4: Add dashboard current-state plus inline schedule editing | `구현커밋` | `디자인올인원`, `테스트` | Dashboard must remain an expanded popover with current controls plus schedule editing, and needs layout/overflow checks. |
| Commit 5: Demote schedule from Settings and update tests | `구현커밋` | `review-all-in-one` | Settings role changes and existing settings tests must be updated. |
| Final Gate | `테스트`, `review-all-in-one` | `qa-gate` | Run focused UI tests, full `xcodebuild test`, Release build, and visual snapshot review. |

## Implementation Plan

### Commit 1: Add schedule command and focused editor shell

- 대상 파일:
  - `InnosDimmer/UI/MenuBarPopoverView.swift`
  - `InnosDimmer/UI/MenuBarController.swift`
  - new `InnosDimmer/UI/ScheduleEditorWindowController.swift` or equivalent
  - `InnosDimmerTests/MenuBarStateTests.swift`
- 변경:
  - Add `MenuBarCommand.openScheduleEditor`.
  - Add `.openScheduleEditor` to `MenuBarCommand.buttonCommands`.
  - Add a `case .openScheduleEditor` branch in `MenuBarController.perform(_:)`.
  - Add a popover `Edit schedule` button in the Schedule section.
  - Re-layout Schedule actions as:
    - Row 1: `Edit schedule` + `Pause automation`
    - Row 2: `Quick disable` + `Restore previous`
  - Add `MenuBarController.showScheduleEditor()` that configures a schedule-only window.
  - The shell can initially render current schedule summary and disabled controls if shared editor extraction happens in Commit 2.
- 검증:
  - Focused tests for button command routing.
  - Update `testMenuBarPopoverButtonsRouteEveryCommand()` and `testMenuBarPopoverCommandButtonsKeepMinimumActionHeight()` expectations through `buttonCommands`.
  - Add a controller routing test that proves `.openScheduleEditor` does not call `openSettings`.
  - `xcodebuild test -scheme InnosDimmer -only-testing:InnosDimmerTests/MenuBarStateTests`
- 성공 기준:
  - Popover routes `Edit schedule` to `.openScheduleEditor`.
  - Controller can instantiate and show the schedule editor without touching settings shortcuts/display/login.
- 중단 조건:
  - If current dirty working tree changes already modify `MenuBarCommand`, re-read and integrate rather than overwrite.

### Commit 2: Extract fixed-row shared schedule editor component

- 대상 파일:
  - new `InnosDimmer/UI/ScheduleEditorView.swift` or local nested view if project style prefers it
  - `InnosDimmer/UI/SettingsWindowController.swift`
  - `InnosDimmerTests/SettingsSnapshotTests.swift`
  - schedule-related UI tests
- 변경:
  - Move schedule row rendering/parsing out of `SettingsWindowController`.
  - Keep this implementation scoped to the existing schedule rows.
  - Do not implement add/remove rows in this plan; leave extension points or disabled affordance only if useful.
  - Keep `HH:mm` validation and percent validation equivalent to existing behavior.
  - Render time, brightness, and blue reduction controls with stable dimensions.
  - Preserve `warmth` as the backing field name while using `Blue reduction` as the visible label.
  - Preserve default schedule values from `ScheduleEntry.defaultSchedule`.
- 검증:
  - Tests for valid rows, invalid time, invalid brightness, invalid blue reduction.
  - Existing settings snapshot and display target tests.
  - Add tests that duplicate minutes are sorted deterministically by `SettingsSnapshot.sortedSchedule(_:)`, not by the editor.
- 성공 기준:
  - One schedule editor helper feeds every active schedule-editing surface; during transition this may include Settings until Commit 5 demotes it.
  - Validation messages remain specific enough for row-level correction.
  - No add/remove persistence behavior is introduced in this plan.
- 중단 조건:
  - If extracting the component requires a broad Settings rewrite, split the extraction into a smaller compatibility wrapper first.

### Commit 3: Wire popover and schedule window save flow

- 대상 파일:
  - `InnosDimmer/UI/ScheduleEditorWindowController.swift`
  - `InnosDimmer/UI/MenuBarController.swift`
  - `InnosDimmerTests/ScheduleEngineTests.swift`
  - possibly `InnosDimmerTests/MenuBarStateTests.swift`
- 변경:
  - Schedule window receives current `SettingsSnapshot.schedule`.
  - Save calls existing schedule update closure.
  - Success refreshes visible schedule summaries and records status.
  - Failure reports validation/persistence error without discarding current rows.
  - Window title should be `InnosDimmer Schedule`.
  - Window should expose only schedule rows, save/cancel or close behavior, and schedule status; it must not include display target, shortcuts, login item, or diagnostics export.
- 검증:
  - Save path test confirms `DisplayTargetStore.saveSchedule` sorting and `MenuBarController.saveSchedule` runtime side effects.
  - Focused schedule tests.
  - Add failure-path test for invalid `HH:mm` and out-of-range percent values.
- 성공 기준:
  - Saving from schedule window has the same runtime behavior as saving from Settings today.
  - Failed save leaves the user's edited row values visible for correction.
- 중단 조건:
  - If save flow bypasses `applyScheduleDecision()` or timer rescheduling, stop and revise.

### Commit 4: Add dashboard current-state plus inline schedule editing

- 대상 파일:
  - `InnosDimmer/UI/MenuBarPopoverView.swift` or new dashboard file if split first
  - `InnosDimmerTests/MenuBarStateTests.swift`
  - dashboard snapshot capture files
- 변경:
  - Preserve dashboard current-state editing controls for brightness and blue reduction.
  - Preserve current-state action access, including `Quick disable`, `Restore previous`, `Pause automation`, and `Settings`.
  - Replace dashboard schedule summary-only row with inline schedule editor section below/alongside current-state controls.
  - Add dashboard `Save schedule` action.
  - Keep current state, action buttons, diagnostics visible and unclipped.
  - Prefer a scrollable dashboard content container before increasing the minimum window height beyond current usability.
  - Reuse the same schedule editor helper and save action boundary as the schedule window.
- 검증:
  - Dashboard button/action tests.
  - Dashboard schedule edit/save routing tests.
  - Dashboard light/dark snapshots.
  - `xcodebuild test -scheme InnosDimmer -only-testing:InnosDimmerTests/MenuBarStateTests`
- 성공 기준:
  - Dashboard can edit schedule without opening the schedule window.
  - Dashboard can still edit current brightness and blue reduction without losing the current-state component.
  - Dashboard still exposes the same manual action family as the popover, not just automation controls.
  - The schedule editor uses same validation and save path.
- 중단 조건:
  - If dashboard height grows beyond usable desktop size, switch to a scrollable content view before adding more controls.

### Commit 5: Demote schedule from Settings and update tests

- 대상 파일:
  - `InnosDimmer/UI/SettingsWindowController.swift`
  - `InnosDimmerTests/HotkeyBindingTests.swift`
  - `InnosDimmerTests/SettingsSnapshotTests.swift`
  - settings snapshot/capture docs if present
- 변경:
  - Remove or collapse the schedule table from Settings.
  - Add schedule summary and `Open schedule editor`.
  - Keep display target, shortcuts, login item, diagnostics export.
  - Extend `SettingsActions` with `openScheduleEditor` or an equivalent narrow callback.
  - If the shared editor component is still temporarily embedded in Settings after Commit 2, this commit removes that primary editing role.
- 검증:
  - Existing settings tests updated for new role.
  - Tests prove settings still saves display, shortcuts, login item, and diagnostics export.
  - Tests prove `Open schedule editor` routes to the same schedule window command/action path as popover.
  - Full `xcodebuild test -scheme InnosDimmer`.
- 성공 기준:
  - Settings is no longer the primary schedule editing surface.
  - Schedule data remains editable through popover schedule window and dashboard.
- 중단 조건:
  - If tests reveal Settings is the only automation save path, finish Schedule window first and defer Settings demotion.

## Plan Quality Check

- Alternative considered: Inline schedule editing directly inside the popover.
  - Rejected because it conflicts with the active design decision that popover is compact quick control.
- Alternative considered: Implement add/remove schedule rows in this plan.
  - Deferred because it deserves a separate plan covering dynamic row UX, validation, persistence edge cases, and tests.
- Alternative considered: Leave schedule editing only in Settings.
  - Rejected because it does not satisfy the user’s requested flow.
- Why this plan:
  - It preserves existing schedule runtime side effects while improving the UI surface split.
- Tradeoff:
  - More UI surfaces need synchronization, but a shared schedule editor view reduces duplication.
- What this plan may still miss:
  - Exact native AppKit choice for time input: text field, stepper, date picker, or combo.
  - Dynamic add/remove row behavior, intentionally moved to the next plan.
  - Whether `warmth` should eventually be renamed to `blueReduction`; this is intentionally not part of this implementation plan.
- When to stop and revise:
  - Stop if the shared editor component cannot be extracted without breaking existing settings tests.
  - Stop if schedule save flow does not trigger current runtime apply/timer behavior.
  - Stop if implementing the dashboard inline editor requires hiding diagnostics or current-state controls.

## 구현 후 검토 리스트

- 회귀 확인:
  - Popover brightness/blue controls still route commands.
  - Pause automation and manual override behavior unchanged.
  - Settings still saves display, shortcuts, login item, and diagnostics export.
- 검증 확인:
  - `xcodebuild test -scheme InnosDimmer -only-testing:InnosDimmerTests/MenuBarStateTests`
  - `xcodebuild test -scheme InnosDimmer -only-testing:InnosDimmerTests/ScheduleEngineTests`
  - `xcodebuild test -scheme InnosDimmer`
  - `xcodebuild -scheme InnosDimmer -configuration Release build CODE_SIGNING_ALLOWED=NO`
- 리뷰 관점:
  - Check for duplicate schedule parsing.
  - Check that no view writes `UserDefaults` directly.
  - Check dashboard/window layout under dark and light appearances.
  - Check that `blue reduction` copy still maps to `warmth` data without accidental schema migration.
  - Check that the schedule editor handles unsorted input, duplicate times, invalid times, invalid percents, and save failures.
- Operator 재확인:
  - Add/remove schedule rows remains next-plan scope.
  - Settings schedule form demotion proceeds in this plan after Schedule window save flow is working.

## Handoff To 구현커밋

- Source plan: `docs/2026-06-19-schedule-editing-plan-first.md`
- Review artifact: `docs/design/schedule-editing/mockup.html`
- Test link: static local file `/Users/moonsoo/projects/InnosDimmer/docs/design/schedule-editing/mockup.html`
- Execution rule: implement Commit 1 through Commit 5 in order.
- Scope guard: do not implement dynamic add/remove schedule rows in this plan.
- UI guard: the dashboard must retain current-state controls while adding inline schedule editing.
- Settings guard: demote schedule editing to summary/navigation after the schedule window save path is available.
- Data guard: do not rename persisted `warmth` fields in this plan.
- Save-path guard: schedule UI must call a controller-supplied action that reaches `MenuBarController.saveSchedule(_:)`.

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
