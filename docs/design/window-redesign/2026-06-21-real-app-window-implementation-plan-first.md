# 2026-06-21 Real App Window Implementation Plan First

후행 실행: `구현커밋`

## Goal

Replace the actual native app window that opens from `InnosDimmer.app` with the reviewed page-based window design from `docs/design/window-redesign/app-window-componentized-mockup.html`.

This plan is specifically about the runtime app window, not the static HTML mockup. The user verified that the actual full window currently has not absorbed the target layout or settings-window functionality.

## 검토용 결과물

- 목표 목업: [app-window-componentized-mockup.html](app-window-componentized-mockup.html)
- 쉬운 설명: [mini-slide.html](../../explainers/window-settings-unification/mini-slide.html)
- 실제 검증 대상: built `InnosDimmer.app` native window after implementation.

HTML 생략 사유: 새 HTML은 만들지 않는다. 이미 reviewed target mockup exists and the current task is to implement that mockup in the native AppKit window.

테스트 링크 후보:

- Local/native app: `/Users/moonsoo/Library/Developer/Xcode/DerivedData/InnosDimmer-fbztptqynwfjrqcesypgzraazcye/Build/Products/Debug/InnosDimmer.app`
- Native GUI smoke check requires manual app launch or Computer Use after build.

## Scope

In scope:

- Convert the actual `AppDashboardWindowController` route into a page-based app window.
- Keep popover as the quick-control surface.
- Add native pages:
  - Home
  - Current status
  - Display
  - Schedule
  - Shortcuts
  - Settings
  - Diagnostics
- Move real settings actions into the app window route:
  - display selection
  - shortcut save/reset
  - launch-at-login toggle
  - diagnostics export
- Normalize newly touched visible copy from `Warmth` to `Blue` or `Blue reduction`.
- Add tests proving settings features are reachable from the app window.

Out of scope unless compilation/test migration stays narrow:

- Force-deleting `SettingsWindowController.swift` before replacement tests cover all old behaviors.
- Redesigning the menu bar popover beyond labels needed for vocabulary consistency.
- Shipping an installer or distribution artifact.

## Codebase Evidence

Confirmed current state:

- `InnosDimmer/UI/MenuBarController.swift`
  - `showAppWindow(focus:)` creates `AppDashboardWindowController`.
  - `openSettings()` currently routes to `showAppWindow(focus: .settings)`.
  - `makeSettingsActions()` already owns the right side-effect closures.
- `InnosDimmer/UI/MenuBarPopoverView.swift`
  - `AppDashboardFocusTarget` exists but maps pages to scroll sections.
  - `AppDashboardWindowController.installContent()` builds a single scroll dashboard.
  - `.shortcuts` and `.settings` focus the same `configurationSectionView`.
- `InnosDimmer/UI/SettingsWindowController.swift`
  - still owns display picker, shortcut editor, login item, diagnostics export.
- `InnosDimmer/UI/ScheduleEditorView.swift`
  - still uses `Warmth` copy for blue reduction.
- `InnosDimmerTests/MenuBarStateTests.swift`
  - tests dashboard buttons, track commands, schedule save, and routing.
- `InnosDimmerTests/HotkeyBindingTests.swift`
  - tests shortcut settings through `SettingsWindowController`.

## Operator 결정 필요 사항

없음. 적용한 기본값:

- 기존 `showAppWindow()` route를 직접 바꾼다. 이유: 실제 앱 전체창을 바꾸는 가장 직접적인 경로다.
- `SettingsWindowController.swift`의 물리 삭제는 feature parity가 테스트로 증명된 뒤로 둔다. 이유: 현재 shortcut tests and helper types still depend on it.
- 새 UI vocabulary는 `Blue reduction` 기준으로 맞춘다. 이유: 사용자가 warm overlay가 아니라 gamma-style blue reduction을 제품 방향으로 확정했다.

## Skill Routing Manifest

| Phase | Required skills | Optional skills | Evidence |
| --- | --- | --- | --- |
| Phase 1: Research and plan lock | `research`, `plan-first-implementation` | `해결전략검토`, `review-all-in-one` | `research.md` 2026-06-21 section and this plan document. |
| Phase 2: Strategy review | `해결전략검토` | `review-swarm` | Checks whether modifying the existing routed app window is safer than adding a second controller. |
| Commit 1: App window page shell and Home | `구현커밋` | `review-all-in-one` | `AppDashboardWindowController` is the actual runtime route. |
| Commit 2: Settings capability migration | `구현커밋` | `review-all-in-one` | Old settings features currently live in `SettingsWindowController`. |
| Commit 3: Tests, vocabulary, and deletion gate | `구현커밋` | `테스트`, `review-all-in-one` | Tests must prove app-window reachability and blue-reduction copy. |
| Final Gate | `review-all-in-one`, `테스트` | `computer-use-operator` | Build/test plus native app manual smoke. |

## 해결전략검토

### 판정

조건부 적절.

### 핵심 근거

- Root-cause fit: the real app window is not mockup-shaped because `AppDashboardWindowController` still builds a vertical scroll dashboard. Replacing its content with a page shell directly targets the cause.
- Blast radius: editing `AppDashboardWindowController` touches the real route, but can preserve `MenuBarController.perform(_:)`, `MenuBarActions`, and schedule/settings action boundaries.
- Contract compatibility: display, shortcut, login, diagnostics side effects can continue through existing `SettingsActions`.
- Regression surface: shortcut editor and diagnostics export are highest-risk because their working UI is still in `SettingsWindowController`.

### 후보 비교

| 후보 | root-cause fit | 회귀 표면 | 구현 비용 | 검증 비용 | 판정 |
| --- | --- | --- | --- | --- | --- |
| A. Existing `AppDashboardWindowController` becomes page app window | High | Medium | Medium | Medium | Adopt |
| B. New `AppWindowController` alongside old dashboard | Medium | High, duplicate routes | High | High | Reject for now |
| C. Convert `SettingsWindowController` into app window | Low, wrong runtime route | High | High | High | Reject |
| D. Only update mockup/docs | None | Low | Low | Low | Reject; user needs real app |

### 구현 진행 조건

- Keep side effects behind `MenuBarController`.
- Do not delete old settings file until app-window tests cover equivalent functions.
- If native layout compile breaks broadly, fall back to feature-reachability pages before cosmetic fidelity.

## review-all-in-one Plan Review Pass

### 짧은 구현 설명

이 계획은 “목업 문서를 더 만드는 작업”이 아니라 실제 `InnosDimmer.app`에서 열리는 전체 창을 바꾸는 작업이다. 실제 route는 `MenuBarController.showAppWindow(focus:) -> AppDashboardWindowController`이므로 이 컨트롤러를 목업형 페이지 창으로 바꾸는 것이 핵심이다.

### 상세 검토 결과

Blocker:

- `SettingsWindowController` 물리 삭제를 Commit 2에서 같이 시도하면 shortcut tests and private `ShortcutKeyField` dependencies 때문에 구현 폭이 커진다. 계획은 deletion gate를 Commit 3로 미뤘으므로 blocker는 완화됐다.

Important:

- `openSettings` and `openShortcuts` already route into the app window, but current page content is missing. Implementation must add feature reachability tests, not only "window is shown" tests.
- New visible labels must use `Blue reduction`; otherwise the new app window will preserve the old artificial-warmth mental model.
- Diagnostics export cannot be represented as a fake log-only page. It must call `SettingsActions.exportDiagnostics`.

Minor:

- Keeping the class name `AppDashboardWindowController` after redesign is semantically stale. Acceptable for this implementation unit, but a later rename to `AppWindowController` would improve clarity.

### 다음 task

1. Implement page shell first.
2. Migrate settings capabilities into pages.
3. Add reachability tests.
4. Run build/test.
5. Perform final `review-all-in-one` and `테스트` gate.

## Implementation Plan

### Phase 1: Research and plan lock

- 대상 파일:
  - `docs/design/window-redesign/research.md`
  - `docs/design/window-redesign/2026-06-21-real-app-window-implementation-plan-first.md`
- 변경:
  - Record actual app-window gap.
  - Lock existing routed window as implementation target.
- 검증:
  - `rg -n "2026-06-21 Actual App Window Gap Research" docs/design/window-redesign/research.md`
  - `rg -n "Commit 1: App window page shell" docs/design/window-redesign/2026-06-21-real-app-window-implementation-plan-first.md`
- 성공 기준:
  - Plan has `Skill Routing Manifest`.
  - Plan has Commit/Phase headings.
- 중단 조건:
  - If code evidence shows actual window is elsewhere, rewrite plan before implementation.
- 코드 스니펫: 필요 없음. Documentation-only lock.

### Phase 2: Strategy review

- 대상 파일:
  - this plan
- 변경:
  - Verify that the selected implementation route addresses the cause.
- 검증:
  - Read-only review of `MenuBarController.showAppWindow(focus:)` and `AppDashboardWindowController.installContent()`.
- 성공 기준:
  - Strategy review says `조건부 적절` or better.
- 중단 조건:
  - If review finds the route does not open actual app window.
- 코드 스니펫:

```swift
private func showAppWindow(focus: AppDashboardFocusTarget? = nil) {
    let controller = dashboardWindowController ?? AppDashboardWindowController(...)
    dashboardWindowController = controller
    refreshAppWindow()
    controller.showWindow(nil)
    controller.focus(focus)
}
```

### Commit 1: App window page shell and Home

- 대상 파일:
  - `InnosDimmer/UI/MenuBarPopoverView.swift`
  - `InnosDimmer/UI/MenuBarController.swift`
- 변경:
  - Add native page state to `AppDashboardWindowController`.
  - Replace single scroll dashboard with a page shell:
    - window header
    - status chips
    - left quick-actions/home column
    - right navigation tile grid
    - detail pages with Back/Home controls
  - Map `AppDashboardFocusTarget` to real pages, not scroll targets.
  - Preserve existing command buttons and test hooks.
- 검증:
  - `xcodebuild -scheme InnosDimmer -configuration Debug build-for-testing CODE_SIGNING_ALLOWED=NO`
  - Existing `MenuBarStateTests` should still pass or be updated for page behavior.
- 성공 기준:
  - `perform(.openAppWindow)`, `.openScheduleEditor`, `.openShortcuts`, `.openDiagnostics`, `.openSettings` all open the same native app window and focus distinct pages.
- 중단 조건:
  - If the app window cannot preserve quick controls and schedule save through existing injected actions.
- 코드 스니펫:

```swift
private enum AppWindowPage: CaseIterable {
    case home, current, display, schedule, shortcuts, settings, diagnostics
}

func focus(_ target: AppDashboardFocusTarget?) {
    activePage = AppWindowPage(target)
    renderActivePage()
    window?.makeKeyAndOrderFront(nil)
}
```

### Commit 2: Settings capability migration

- 대상 파일:
  - `InnosDimmer/UI/MenuBarPopoverView.swift`
  - `InnosDimmer/UI/MenuBarController.swift`
  - `InnosDimmer/UI/SettingsWindowController.swift`
- 변경:
  - Inject `SettingsActions` into the app window.
  - Pass `SettingsSnapshot`, display candidates, and `LoginItemStatus` into `AppDashboardWindowController.update(...)`.
  - Add Display page with picker.
  - Add Shortcuts page with editable bindings, save, and reset.
  - Add Settings page with launch-at-login toggle and saved-state summary.
  - Add Diagnostics page with visible logs, verification matrix, and export button.
- 검증:
  - Add/update tests:
    - `testAppWindowDisplayPageUsesSelectedDisplayAction`
    - `testAppWindowShortcutsPageSavesAndResetsBindings`
    - `testAppWindowSettingsPageTogglesLaunchAtLogin`
    - `testAppWindowDiagnosticsPageExportsDiagnostics`
- 성공 기준:
  - Old settings capabilities are usable without opening `SettingsWindowController`.
- 중단 조건:
  - If shortcut editor extraction broadens into unrelated keyboard handling changes.
- 코드 스니펫:

```swift
let controller = dashboardWindowController ?? AppDashboardWindowController(
    actions: MenuBarActions { [weak self] command in self?.perform(command) },
    scheduleActions: makeScheduleEditorActions(),
    settingsActions: makeSettingsActions()
)
```

### Commit 3: Tests, vocabulary, and deletion gate

- 대상 파일:
  - `InnosDimmer/UI/ScheduleEditorView.swift`
  - `InnosDimmer/UI/MenuBarPopoverView.swift`
  - `InnosDimmerTests/MenuBarStateTests.swift`
  - `InnosDimmerTests/HotkeyBindingTests.swift`
- 변경:
  - Change newly touched `Warmth` labels to `Blue` or `Blue reduction`.
  - Keep old `SettingsWindowController` compiling if tests still depend on it, but stop relying on it for runtime app-window paths.
  - Add a deletion-gate note in this plan if full file deletion is deferred.
- 검증:
  - `xcodebuild -scheme InnosDimmer -configuration Debug test CODE_SIGNING_ALLOWED=NO`
  - `rg -n "Warmth|warmth" InnosDimmer/UI/MenuBarPopoverView.swift InnosDimmer/UI/ScheduleEditorView.swift`
- 성공 기준:
  - Tests pass.
  - Real app window has distinct page content.
  - Any remaining `Warmth` occurrence is intentionally legacy or test fixture.
- 중단 조건:
  - If deleting `SettingsWindowController` requires unrelated project-file surgery beyond this unit.
- 코드 스니펫:

```swift
case .invalidPercent(let row, let field):
    return "Schedule row \(row) needs \(field) from 0 to 100."
// field should be "blue reduction", not "warmth"
```

## Plan Quality Check

- Alternative considered: create a new `AppWindowController`. Rejected for this pass because it leaves the current `showAppWindow()` route split and increases duplicate UI.
- Alternative considered: delete `SettingsWindowController` first. Rejected because shortcut/settings tests still rely on it and feature parity is not yet proven.
- Why this plan: it changes the actual native window the user opens, not just docs or mockups.
- Tradeoff: keeping the old class name `AppDashboardWindowController` is less semantically clean, but it keeps the patch smaller and preserves test anchors. Rename can happen after behavior lands.
- What this plan may still miss: exact native screenshot fidelity. AppKit layout must be visually QA'd after build.
- When to stop and revise: if build errors show old `SettingsWindowController` private helpers must be deeply extracted before shortcut page can compile.

## 구현 후 검토 리스트

- 회귀 확인:
  - quick disable, restore, pause/resume still route through `MenuBarCommand`.
  - schedule save still persists through `DisplayTargetStore.saveSchedule`.
  - shortcut save still re-registers hotkeys through `MenuBarController.saveShortcuts`.
  - diagnostics export still uses `DiagnosticsExporter`.
- 검증 확인:
  - Debug build.
  - Unit tests.
  - Manual/native smoke: open app, confirm target page window.
- 리뷰 관점:
  - settings feature reachability.
  - page focus routing.
  - blue-reduction vocabulary.
  - no direct UI-to-service side effects.
- Operator 재확인:
  - visually compare actual native window with `app-window-componentized-mockup.html`.
