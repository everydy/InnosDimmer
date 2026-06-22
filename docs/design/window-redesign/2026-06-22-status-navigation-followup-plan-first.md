# Status Navigation Follow-Up Plan

## Goal

Finish the latest unified app-window cleanup by hardening the parts that were just changed:

- `Current status` and `Display` must keep sharing one current-state representation.
- `Open popover` must be a persistent sidebar action, not a `Current status` command.
- Page-specific header actions must remain scoped to their page.
- Tests must catch route drift, not just text/identifier presence.

## Skill Routing Manifest

| Phase | Required skills | Optional skills | Evidence |
| --- | --- | --- | --- |
| Commit 1: Sidebar action zone and route test | `review-all-in-one`, `research`, `plan-first-implementation`, `구현커밋` | `review-swarm` | Review found the sidebar button has identifier coverage but no click-route coverage; research maps the path to `MenuBarActions.perform(.openPopover)`. |
| Final Gate | `review-all-in-one` | `테스트` | Run focused native unit tests and inspect final diff/status. |

## 검토용 결과물

- 계획 MD: `docs/design/window-redesign/2026-06-22-status-navigation-followup-plan-first.md`
- 리서치: `docs/design/window-redesign/status-navigation-followup/research.md`
- 검토 결과: `docs/design/window-redesign/status-navigation-followup/review-all-in-one.md`
- HTML 생략 보고서: 이번 작업은 새 레이아웃 시안이 아니라 이미 구현된 네이티브 AppKit 구조의 라우팅/레이아웃 안정화다. 검토 표면은 AppKit 단위 테스트와 native view 구조 식별자다.

## Operator 결정 필요 사항

없음.

적용한 기본값:

- `Current status` 페이지는 유지한다. 이유: 현재 네비게이션 정보구조에 포함되어 있고, 제거는 더 큰 UX 결정이다.
- `Open popover`는 사이드바 하단의 별도 action zone으로 둔다. 이유: 사용자가 요청한 “네비게이션과 다르지만 강조색이 들어간 버튼” 방향과 맞고, `Current status`의 command 중복을 줄인다.

## Scope And Structure

In scope:

- `UnifiedAppWindowController.makeSidebar()` 구조 보강
- sidebar `Open popover` test hook 추가
- `MenuBarStateTests`에 route-level test 추가
- review/research/plan 문서 기록

Out of scope:

- `Current status` 페이지 삭제
- 별도 settings window 재도입
- Display/Schedule/Diagnostics 대규모 레이아웃 재설계
- 패키지 설치 또는 외부 의존성 변경

## Implementation Plan

### Commit 1: Sidebar action zone and route test

대상 파일:

- `InnosDimmer/UI/UnifiedAppWindowController.swift`
- `InnosDimmerTests/MenuBarStateTests.swift`
- `docs/design/window-redesign/status-navigation-followup/review-all-in-one.md`
- `docs/design/window-redesign/status-navigation-followup/research.md`
- `docs/design/window-redesign/2026-06-22-status-navigation-followup-plan-first.md`

변경:

- `makeSidebar()`에서 navigation stack과 action zone을 분리한다.
- sidebar action zone에 `app-window-sidebar-action-zone` identifier를 부여한다.
- vertical sidebar spacer는 세로 hugging을 낮춘 전용 helper를 사용한다.
- `Open popover` sidebar button을 weak reference로 보관하고 테스트 hook을 추가한다.
- 테스트에서 sidebar action zone identifier와 `Open popover` 클릭 route를 검증한다.

Proposed code snippet:

```swift
let navigationStack = NSStackView(views: buttonViews)
let actionZone = NSStackView(views: [openPopoverButton])
let stack = NSStackView(views: [navigationStack, verticalSpacer(), actionZone])
```

검증:

```bash
xcodebuild test -scheme InnosDimmer -only-testing:InnosDimmerTests/MenuBarStateTests CODE_SIGNING_ALLOWED=NO
```

성공 기준:

- sidebar text remains `Overview`, `Current status`, `Display`, `Schedule`, `Shortcuts`, `Settings`, `Diagnostics`.
- every page exposes `app-window-sidebar-action-zone`.
- sidebar `Open popover` click emits `.openPopover`.
- current page does not regain body `Commands`, `Settings`, or automation commands.
- focused tests pass.

중단 조건:

- If `NSStackView` action-zone split clips sidebar buttons at the fixed `900 x 640` content size, stop and rework the spacer/action constraints before committing.

트레이드오프:

- 채택안: persistent sidebar action zone.
- 대안: keep the button in page command rows. This repeats actions inside detail pages and contradicts the user's simplification direction.
- 비용/리스크: one extra test hook.
- 감수 이유: route-level test coverage is more valuable than keeping the button completely private.
- 재검토 조건: if future UI removes the sidebar action entirely, delete the test hook with that feature.

## Plan Quality Check

- Alternative considered: remove `Current status` entirely. Rejected because it changes navigation scope beyond the current request.
- Why this plan: it addresses the remaining concrete risks from the post-implementation review without reopening the whole window redesign.
- Tradeoff: it adds a small testing hook, but prevents a visible button from becoming a nonfunctional dead control.
- What this plan may still miss: pixel-level visual placement. This pass relies on native structure/unit tests, not screenshot approval.
- When to stop and revise: if the action-zone split changes the fixed window size or clips sidebar items.

## 구현 후 검토 리스트

- 회귀 확인: `Current status` has no body command row.
- 검증 확인: focused `MenuBarStateTests` passes.
- 리뷰 관점: route-level coverage for persistent sidebar actions; no duplication of current-state rows.
- Operator 재확인: visually confirm the sidebar bottom action placement in the running app if desired.

## 후행 실행

후행 실행: `구현커밋`

이 계획은 단일 commit unit으로 실행한다.
