# Review All In One

## 짧은 구현 설명

이번 작업은 앱 코드를 고친 것이 아니라, 목업과 실제 네이티브 앱 창 사이의 남은 차이를 더 구체적으로 조사하고 해결전략을 검토한 문서 작업이다.

핵심 결론은 세부 페이지의 문제를 기능 부족으로 보면 안 된다는 것이다. 실제로는 page header, split layout, token row, matrix card, log feed 같은 네이티브 레이아웃 문법이 부족해서 목업과 다르게 보인다.

## 상세 검토 결과

### Blocker

발견된 blocker 없음.

현재 문서들은 다음 계획으로 넘어갈 수 있을 정도의 원인과 방향을 담고 있다. 다만 구현 승인을 받기 전까지는 코드 변경으로 넘어가면 안 된다.

### Important

1. `Schedule` remove-column 여부가 아직 결정되지 않았다.

   - 근거: 목업은 remove 버튼을 포함하지만, 현재 `ScheduleEditorView`는 fixed 3-row editor다.
   - 영향: remove column을 구현하면 schedule model과 테스트가 바뀔 수 있다.
   - 다음 task: 계획 수립 전에 "3행 고정 유지 vs 행 삭제 UI 도입"을 결정한다.

2. Diagnostics copy/select 동작이 전략에서 unresolved다.

   - 근거: 현재 앱은 `NSTextView`라 로그 선택/복사가 쉽고, 목업은 token log row feed다.
   - 영향: 시각적으로 좋아져도 디버깅 편의가 줄 수 있다.
   - 다음 task: row feed로 바꾸되 `Copy latest` 또는 raw export/copy 경로를 유지할지 결정한다.

3. 테스트가 아직 레이아웃 실패를 막기에 약하다.

   - 근거: 현재 acceptance tests는 텍스트/명령 존재를 주로 본다.
   - 영향: full-width Back 버튼, vertical-only layout 같은 문제를 테스트가 놓칠 수 있다.
   - 다음 task: page header, split layout, token row, log row count를 확인하는 구조 테스트를 먼저 추가한다.

4. 바로 전체 파일 추출부터 하면 diff가 과도해질 수 있다.

   - 근거: `UnifiedAppWindowController`가 `MenuBarPopoverView.swift` 안에 있고 분리 필요성은 있지만, visible layout repair와 move-only diff가 섞이면 검토가 어려워진다.
   - 다음 task: 우선 app-window layout primitive를 작게 만들고, 1-2개 페이지 변환 후 추출한다.

### Minor

1. 현재 safe smoke snapshot은 nonblank 구조 확인용이지 pixel-perfect 비교는 아니다.

   - 다음 task: 목업 대비 수동 QA 체크리스트를 계획 문서에 포함한다.

2. 목업의 일부 설명성 subtitle/caption은 이전 사용자 피드백상 줄여야 할 수 있다.

   - 다음 task: header subtitle 유지 여부를 계획에서 명시한다.

## 다음 task

1. `plan-first-implementation`으로 다음 구현 계획을 세운다.
2. 계획에서 먼저 결정한다:
   - Schedule remove-column 여부
   - Diagnostics raw copy/select 유지 방식
   - detail header subtitle 유지 여부
   - component extraction 시점
3. 구현 순서는 다음이 안전하다:
   - 구조 테스트 추가
   - page header + compact action row
   - Display split layout
   - Diagnostics matrix/log rows
   - Schedule width/action polish
   - Settings/Shortcuts polish
4. 구현 후 검증:
   - `git diff --check`
   - focused app-window tests
   - `scripts/smoke_app_window_snapshot.sh`
   - 목업 HTML과 실제 PNG 수동 비교

## 반복 재검토 결과 - 2026-06-22

### Pass 1: 계획 문서와 코드베이스 정합성

- 판정: 보강 필요.
- 발견:
  - 계획 문서가 `SettingsWindowController` 관련 과거 상태를 대부분 정정했지만, 기존 app-window mockup acceptance tests가 이미 있다는 사실을 충분히 반영하지 못했다.
  - `MenuBarStateTests.swift`에는 이미 `testUnifiedAppWindowCurrentStatusPageDefinesReadOnlyDetailContract`, `testUnifiedAppWindowSchedulePageDefinesTableEditorContract`, `testUnifiedAppWindowDiagnosticsPageDefinesMatrixAndLogContract`, `testUnifiedAppWindowSafeVisualSmokeRendersNonblankPages`가 있다.
  - 따라서 다음 구현의 첫 단계는 "테스트를 처음 만든다"가 아니라 "기존 visible-text tests가 못 잡는 structural layout facts를 추가한다"가 맞다.
- 반영:
  - plan-first 문서의 Commit 1을 `Strengthen existing app-window acceptance tests with structural layout assertions`로 수정했다.

### Pass 2: 실제 파일/타입/API 정합성

- 판정: 보강 필요.
- 발견:
  - `DiagnosticsEvent`의 시간 필드는 `date`가 아니라 `timestamp`다.
  - `scripts/smoke_app_window_snapshot.sh`는 페이지 인자를 받지 않고 항상 7개 파일을 `/tmp/InnosDimmerSafeSmoke/safe-app-window-*.png`로 생성한다.
  - `InnosDimmer.xcodeproj/project.pbxproj`는 Swift source file을 수동 등록하는 구조라, 새 `AppWindowLayoutComponents.swift`를 만들면 project file 수정이 필요하다.
  - 계획의 `AppWindowTokenRowView` 스니펫은 controller-local `spacer()`를 component file에서 호출하는 형태라 그대로는 컴파일되지 않는다.
- 반영:
  - Diagnostics snippet을 `$0.timestamp`로 수정했다.
  - smoke verification 문구를 전체 7-page capture 방식으로 통일했다.
  - 새 Swift 파일 생성 시 `project.pbxproj` 등록을 required로 명시했다.
  - component snippet에서 local `NSView()` spacer를 만들도록 수정했다.

### Pass 3: 구조 테스트 가능성

- 판정: 추가 보강 후 blocker 없음.
- 발견:
  - 텍스트 테스트만으로는 body-width Back button, split layout, token rows, matrix/log feed region을 증명하기 어렵다.
  - 구조 테스트가 무엇을 찾을지 명확하지 않으면 또 "텍스트는 있는데 화면이 다름" 문제가 반복될 수 있다.
- 반영:
  - plan-first 문서에 `AppWindowPageStructure.structuralRegions`와 `identifier` 기반 native view markers 예시를 추가했다.
  - `AppWindowPageHeaderView`, `AppWindowDetailSplitView`, `AppWindowTokenRowView` 스니펫에 `NSUserInterfaceItemIdentifier` 예시를 넣었다.

### 현재 남은 문제

- Blocker: 없음.
- Important:
  - 구현 단계에서 실제 AppKit constraint가 스니펫과 달라질 수 있으므로 Commit 2-3 후 smoke screenshot을 반드시 확인해야 한다.
  - 새 Swift 파일로 분리할지 `InnosDesignComponents.swift`에 임시로 붙일지는 구현자가 diff 크기를 보고 결정해야 한다. 기본값은 새 파일 + project 등록이지만, project churn이 커지면 fallback을 써야 한다.
- Minor:
  - HTML 검토물은 계획 이해용이라 실제 native constraint 결과를 보장하지 않는다. 최종 판단은 smoke PNG와 실제 앱 창으로 해야 한다.

### Pass 4: 보강 후 최종 재검토

- 판정: 추가 blocker 없음.
- 확인:
  - plan-first 문서의 Manifest와 `### Commit N:` heading이 같은 Commit 1-8 구조를 가리킨다.
  - stale snippet인 `$0.date`는 `$0.timestamp`로 수정됐다.
  - smoke command는 개별 페이지 인자 방식이 아니라 전체 7-page capture 방식으로 통일됐다.
  - 새 Swift 파일 생성 시 `project.pbxproj` 등록 필요성이 계획에 반영됐다.
  - 구조 테스트는 visible text가 아니라 native view `identifier` / structural region을 검사하는 방향으로 명시됐다.
- 결론:
  - 현재 계획 문서는 후행 `구현커밋`으로 넘길 수 있는 수준이다.
  - 남은 리스크는 계획 문서 문제가 아니라 실제 AppKit constraint 구현과 smoke screenshot 결과에서 확인해야 할 구현 리스크다.
