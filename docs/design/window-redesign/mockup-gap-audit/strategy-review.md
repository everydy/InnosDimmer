# Strategy Review

## 판정

조건부 적절.

가장 타당한 해결전략은 **기능을 더 붙이는 것**이 아니라, `UnifiedAppWindowController`에 부족한 네이티브 레이아웃 어휘를 먼저 만드는 것이다. 구체적으로는 page header, split detail layout, token row, matrix card, log row, compact action row를 만들고, 그 위에 Display, Diagnostics, Schedule, Settings, Current, Shortcuts를 순서대로 옮기는 전략이 root cause fit이 가장 높다.

단, 구현 전에 두 조건이 필요하다.

1. `ScheduleEditorView`의 remove-column 여부를 결정해야 한다.
2. 구조 테스트를 먼저 보강해야 한다. 지금 테스트는 텍스트 존재 중심이라 레이아웃 실패를 놓칠 수 있다.

## 범위

검토 대상 문제:

- 실제 앱의 세부 페이지가 목업의 구조, 밀도, 헤더, 액션 배치, token-list 표현을 충분히 반영하지 못함.

검토 대상 전략:

- 목업을 그대로 덧붙이는 대신, 현재 네이티브 앱 창에 부족한 레이아웃 프리미티브를 만들고 페이지별로 적용한다.

구현 금지 상태:

- 이 문서는 구현 전 전략 검토다. 코드 변경은 하지 않는다.

## 핵심 근거

- `UnifiedAppWindowController`는 모든 페이지를 `renderActivePage()`에서 분기하고, 대부분의 세부 페이지를 `makeDetailPage(_:)`에 세로 배열로 넣는다. 이 구조가 full-width Back 버튼과 full-width section stack을 만든다.
- 목업은 세부 페이지마다 `<header class="page-head">`와 `detail-layout`, `token-list`, `matrix-card`, `log-feed`를 반복적으로 쓴다.
- Schedule 기능은 이미 많이 구현되어 있다. `ScheduleEditorView`는 `Time`, `Bright`, `Blue`, numeric field, slider, `-`/`+`를 갖는다. 남은 문제는 기능보다 폭/배치/행 스타일이다.
- Diagnostics는 가장 큰 gap이다. 실제는 `NSTextView` 중심이고, 목업은 matrix card + log feed row 구조다.
- `SettingsWindowController`는 더 이상 남아 있지 않다. 따라서 다음 문제는 "설정창 통합"이 아니라 "통합된 창의 세부 페이지 레이아웃 완성"이다.

## 주요 리스크

- `makeDetailPage(_:)`를 한 번에 크게 바꾸면 모든 세부 페이지가 동시에 깨질 수 있다.
- `MenuBarPopoverView.swift` 안에 popover와 full app window가 같이 있어, 페이지별 UI를 계속 추가하면 파일 크기와 리뷰 난도가 더 올라간다.
- Diagnostics를 row feed로 바꾸면 지금의 `NSTextView` 복사/선택 편의성이 줄어들 수 있다.
- Schedule에 remove column을 추가하면 기존 3-row 고정 schedule model과 충돌할 수 있다.
- 테스트가 현재처럼 문자열 중심이면 "목업처럼 보이지 않는 UI"가 다시 통과할 수 있다.

## 후보 비교

| 후보 | root-cause fit | 회귀 표면 | 구현 비용 | 검증 비용 | 판정 |
| --- | --- | --- | --- | --- | --- |
| A. 문자열/버튼만 더 추가 | 낮음 | 낮음 | 낮음 | 낮음 | 부적절 |
| B. 각 페이지를 현재 파일 안에서 즉시 목업처럼 직접 수정 | 중간 | 높음 | 중간 | 중간 | 조건부 부적절 |
| C. 네이티브 레이아웃 프리미티브를 먼저 만들고 페이지별로 적용 | 높음 | 중간 | 중간 | 중간 | 추천 |
| D. `UnifiedAppWindowController`를 별도 파일/컴포넌트로 먼저 추출 후 적용 | 높음 | 중간-높음 | 높음 | 높음 | 2단계로 적절 |
| E. 목업 HTML을 WebView로 띄우기 | 낮음 | 높음 | 중간 | 높음 | 부적절 |

## 후보 A: 문자열/버튼만 더 추가

판정: 부적절.

이 전략은 테스트를 통과시키기 쉬우나 root cause를 해결하지 않는다. 현재 문제는 내용 부족이 아니라 페이지 구조 mismatch다. 예를 들어 `Display`는 이미 current state, target display, saved selection 내용을 갖고 있지만, mockup의 split layout과 header action 위치를 반영하지 못한다.

## 후보 B: 현재 파일 안에서 페이지별 직접 수정

판정: 조건부 부적절.

빠르게 보이는 결과는 낼 수 있지만 `MenuBarPopoverView.swift`가 이미 popover, legacy dashboard-like controller, unified app window를 모두 담고 있어 장기 유지보수성이 나빠진다. 다만 아주 작은 page-header 도입 정도는 이 후보로 시작할 수 있다.

사용 가능한 범위:

- `makeDetailPage`를 `makeDetailPage(header:content:)` 형태로 작게 바꾸는 수준.
- Display 한 페이지에 split helper를 시험 적용하는 수준.

피해야 할 범위:

- 모든 페이지에 각각 임의 stack/layout을 직접 하드코딩.
- Diagnostics row, matrix card, shortcut row를 페이지 내부 local code로 반복 작성.

## 후보 C: 레이아웃 프리미티브 우선

판정: 추천.

root cause fit이 가장 높다. 목업과 실제 앱의 차이는 반복되는 UI 문법의 부재다.

필요한 프리미티브:

- `AppWindowPageHeader`
  - Back control
  - page title
  - optional subtitle only if 유지하기로 결정
  - trailing primary/secondary actions
  - optional status chip
- `AppWindowDetailSplit`
  - left fixed/compact panel
  - right flexible detail stack
- `AppWindowTokenRow`
  - title/value row
  - optional control area
- `AppWindowMatrixCard`
  - summary score
  - blocked/handled chips
  - row list
- `AppWindowLogRow`
  - time/category/message/severity
- `AppWindowCompactActionRow`
  - right-aligned or footer-aligned actions

Why this is safer:

- The same helper can serve Display, Settings, Diagnostics, and Schedule.
- Tests can target helper-level structure.
- It reduces repeated arbitrary AppKit stack decisions.

조건:

- Start with one page, preferably Display or Diagnostics.
- Keep command/action closures unchanged.
- Run focused tests and safe smoke after each page group.

## 후보 D: 파일 추출 먼저

판정: 2단계로 적절.

`UnifiedAppWindowController` should eventually move out of `MenuBarPopoverView.swift`, but doing extraction before visible layout repair can expand the diff too early. The safer sequence is:

1. Introduce app-window layout primitives, either local-private or in a new design-system file.
2. Convert 1-2 high-gap pages.
3. Once shape stabilizes, extract `UnifiedAppWindowController` and reusable components.

This avoids a large move-only diff mixed with behavior changes.

## 후보 E: WebView로 목업 HTML 사용

판정: 부적절.

It would visually match quickly, but it bypasses the AppKit controls, existing `SettingsActions`, `ScheduleEditorActions`, shortcut fields, accessibility behavior, and current test surface. It creates a second UI runtime rather than fixing the native one.

## 더 나은 대안 또는 축소 가능한 수정 범위

Recommended phased strategy:

### Phase 1: Structure gates

- Add test hooks for:
  - Back control placement
  - header action labels
  - body split layout presence
  - diagnostics log row count
  - schedule table useful width
- Keep text acceptance tests.
- Keep safe smoke snapshot script.

### Phase 2: Page header and compact actions

- Replace body-width Back button with a page-header Back button.
- Move `Refresh displays`, `Apply settings`, `Export diagnostics`, `Save shortcuts`, and automation/save schedule actions into header or compact section actions.
- Preserve existing command selectors.

### Phase 3: Split layout pages

- Convert Display first.
- Convert Settings second.
- Convert Diagnostics third because it needs row rendering as well.

### Phase 4: High-gap content polish

- Diagnostics matrix card + log feed.
- Schedule width distribution and action row.
- Shortcuts token row wrapper.

### Phase 5: Optional extraction

- Move app-window-only components out of `MenuBarPopoverView.swift`.
- Keep popover behavior untouched.

## 구현 전 확인

- Confirm whether Schedule row removal is actually desired. The mockup has remove buttons, but the app currently behaves like a fixed 3-row schedule editor.
- Confirm whether visible Diagnostics logs must remain selectable/copyable. If yes, row feed should include a `Copy latest` or hidden/export raw path.
- Confirm whether subtitles in mockup detail headers should remain or be removed. Earlier feedback often removed explanatory copy from the mockup.
- Confirm minimum window size target. Current app uses `minSize = 780x520`, but safe smoke snapshots show scaled pages at 1760x1120 or taller.

## 검증 계획

Required after implementation:

- `git diff --check`
- Focused page structure tests in `InnosDimmerTests/MenuBarStateTests.swift`
- Shortcut customization tests in `InnosDimmerTests/HotkeyBindingTests.swift`
- `scripts/smoke_app_window_snapshot.sh`
- Manual comparison against:
  - `docs/design/window-redesign/app-window-componentized-mockup.html`
  - `/tmp/InnosDimmerSafeSmoke/safe-app-window-display.png`
  - `/tmp/InnosDimmerSafeSmoke/safe-app-window-schedule.png`
  - `/tmp/InnosDimmerSafeSmoke/safe-app-window-diagnostics.png`

## 외부 근거

External sources were not used. This is a local codebase and local mockup parity problem. Local code, mockup HTML, tests, and safe smoke snapshots are stronger evidence than generic AppKit design advice for this decision.

## 구현 진행 조건

Proceed only after a `plan-first-implementation` document locks:

- exact page order
- component names and destination files
- Schedule remove-column decision
- Diagnostics copy/select behavior
- structural test additions
- smoke verification command

