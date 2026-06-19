# 2026-06-19 Resume Automation Toggle Plan

## Summary

`Pause automation` is currently one-way from the user's point of view. After a manual override pauses the schedule until the next boundary, the app shows the paused state but the same visible control still says `Pause automation`. This plan changes that control into an explicit state-aware action:

- Automation active: `Pause automation`
- Automation paused: `Resume automation`

`Resume automation` should clear the paused/manual override state and immediately apply the schedule entry for the current time. It should not wait for the next schedule boundary.

## Skill Routing Manifest

| Phase | Required skills | Optional skills | Evidence |
| --- | --- | --- | --- |
| Commit 1: Add resume automation command and state-aware UI | `구현커밋` | `review-all-in-one` | `MenuBarCommand`, `MenuBarController.perform`, `MenuBarViewModel`, `AppDashboardViewModel`, and menu/dashboard button tests define the command surface. |
| Final Gate | `review-all-in-one`, `qa-gate` | `테스트` | `xcodebuild test -scheme InnosDimmer -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO` must pass and the button copy must be covered by tests. |

## 검토용 결과물

- 계획 MD: `docs/2026-06-19-resume-automation-toggle-plan-first.md`
- 앱 검토 표면: native macOS popover and app dashboard.
- 테스트 표면: `MenuBarStateTests`, `ScheduleRuntimeTests`, and full `xcodebuild test`.

## HTML 생략 보고서

HTML artifact is omitted because this is not a new visual direction or standalone UX concept. The requested behavior depends on native AppKit controls, controller state, schedule runtime, and XCTest coverage. The useful review surface is the actual menu bar popover/app window plus unit tests.

## Operator 결정 필요 사항

상태: 없음. 적용한 기본값: English text labels are kept because the user chose direct English labels over icon-only controls.

- 결정 제목: Resume label copy
- 맥락: paused state needs a clear inverse of `Pause automation`.
- A/B/C 선택지:
  - A: `Resume automation`
  - B: `Cancel pause`
  - C: icon-only state button
- 추천안: A
- 기본값: A
- 보류 시 영향: None for this unit. The copy can be changed later without altering the runtime model.

## Current Code Findings

- `MenuBarCommand` currently has `pauseAutomation` but no resume command.
- `MenuBarController.perform(_:)` routes `.pauseAutomation` to `pauseAutomationUntilNextBoundary(...)`.
- `ScheduleEngine.stateAfterApplying(_:, to:)` already knows how to clear manual override only when an `.apply(..., clearsManualOverride: true)` decision is produced at a boundary.
- A manual resume needs its own state transition because the schedule boundary has not necessarily been reached.
- `MenuBarViewModel` and `AppDashboardViewModel` already compute whether automation is paused from `BrightnessState.automationPausedUntilNextBoundary`.
- The popover and dashboard each have a `Pause automation` button hard-coded in the layout.

## Implementation Plan

### Commit 1: Add resume automation command and state-aware UI

대상 파일:

- `InnosDimmer/UI/MenuBarPopoverView.swift`
- `InnosDimmer/UI/MenuBarController.swift`
- `InnosDimmer/Services/ScheduleEngine.swift`
- `InnosDimmerTests/MenuBarStateTests.swift`
- `InnosDimmerTests/ScheduleEngineTests.swift`

변경 내용:

- Add `MenuBarCommand.resumeAutomation`.
- Add `automationActionTitle` and `automationActionCommand` to `MenuBarViewModel`.
- Add the same action metadata to `AppDashboardViewModel`.
- In the popover schedule section and dashboard configuration section, create the automation control as one state-aware button.
- When paused, the button title should be `Resume automation` and route `.resumeAutomation`.
- When active, the button title should be `Pause automation` and route `.pauseAutomation`.
- Add `MenuBarController.resumeAutomation(...)`.
- Resume behavior:
  - if there is no active schedule entry, clear paused fields and refresh without applying dimming.
  - if there is an active schedule entry, apply it with source `.schedule`.
  - clear `automationPausedUntilNextBoundary`, `automationPausedAtMinuteOfDay`, and `automationResumeMinuteOfDay`.
  - record a diagnostic message that automation resumed.
  - reschedule the next boundary timer when the controller is running.
  - refresh popover and app dashboard.

Proposed code sketch:

```swift
case .resumeAutomation:
    resumeAutomation()
```

```swift
static func stateAfterResumingAutomation(from state: BrightnessState) -> BrightnessState {
    var updated = state
    updated.automationPausedUntilNextBoundary = false
    updated.automationPausedAtMinuteOfDay = nil
    updated.automationResumeMinuteOfDay = nil
    return updated
}
```

```swift
if state.automationPausedUntilNextBoundary {
    automationActionTitle = "Resume automation"
    automationActionCommand = .resumeAutomation
} else {
    automationActionTitle = "Pause automation"
    automationActionCommand = .pauseAutomation
}
```

검증:

- Add a `ScheduleEngine` unit test proving resume clears paused fields without changing brightness values.
- Add a runtime test:
  - start with display selected and schedule active
  - perform `.brightnessUp` to pause automation
  - perform `.resumeAutomation`
  - assert the latest software command source is `.schedule`
  - assert paused fields are cleared
  - assert current schedule brightness/blue reduction are applied immediately
- Add view-model/UI routing tests:
  - paused popover exposes `Resume automation` for `.resumeAutomation`
  - active popover exposes `Pause automation` for `.pauseAutomation`
  - dashboard mirrors the same behavior
- Run:

```bash
xcodebuild test -scheme InnosDimmer -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO
```

성공 기준:

- User sees `Resume automation` after automation is paused.
- Pressing `Resume automation` immediately returns to the current schedule value.
- Existing pause behavior remains unchanged when automation is active.
- Full test suite passes.

중단 조건:

- If existing schedule editor dirty changes conflict with the button location, preserve the dirty changes and adapt the patch locally rather than reverting them.
- If applying the current schedule on resume fails because no display is selected, do not clear diagnostics silently; record the existing software/display failure path and refresh UI.

트레이드오프:

- 채택안: add a distinct `.resumeAutomation` command but render it through the same visual button slot.
- 대안: make `.pauseAutomation` toggle internally.
- 비용/리스크: a new command expands the command enum and button tests.
- 감수 이유: tests and diagnostics can distinguish pause from resume, which is safer for future hotkeys or app-window actions.
- 재검토 조건: if future UI becomes icon-only, keep the command split but change the rendered control only.

## Plan Quality Check

- Alternative considered: icon-only toggle. Rejected for this unit because the user chose English labels as more direct.
- Why this plan: it matches the current AppKit architecture where UI buttons route explicit `MenuBarCommand` cases.
- Tradeoff: one new command is slightly more code but avoids ambiguous toggle behavior in diagnostics and tests.
- What this plan may still miss: manual QA still needs to confirm the popover button text after a real pause on the user's monitor setup.
- When to stop and revise: if full test fails because current uncommitted schedule-editor work changes the same UI layout in a larger way, re-scope the patch around the current dirty layout rather than overwriting it.

## 구현 후 검토 리스트

- 회귀 확인: `Pause automation` still appears and works when automation is active.
- 회귀 확인: manual brightness/blue reduction changes still pause automation until the next boundary.
- 검증 확인: resume clears paused fields and immediately applies the current schedule entry.
- 검증 확인: popover and app dashboard show the same state-aware button label and command.
- 리뷰 관점: confirm no legacy schedule persistence keys are changed.
- Operator 재확인: user should manually check the menu bar popover after pressing `Pause automation` once.

## 후행 실행

후행 실행: 구현커밋

