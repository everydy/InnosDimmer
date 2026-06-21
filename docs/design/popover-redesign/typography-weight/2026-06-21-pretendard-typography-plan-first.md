# 2026-06-21 Pretendard Typography Plan First

후행 실행: `구현커밋`

## Goal

Stabilize InnosDimmer's Pretendard typography system after the initial font-family switch. The goal is not to redesign the popover again; it is to make the current native AppKit UI use Pretendard through clear role-based typography tokens, reduce shortcut keycap dominance, preserve numeric readability, and keep the popover within its preferred width.

## 검토용 결과물

- 문제 리서치: [research.md](research.md)
- 해결 전략 리서치: [solution-research/research.md](solution-research/research.md)
- 기존 목표 목업: [../mockup.html](../mockup.html)
- 기존 목표 목업 PNG: [../mockup-preview.png](../mockup-preview.png)
- 현재 AppKit dark capture: [../captures/actual-dark.png](../captures/actual-dark.png)
- 현재 AppKit light capture: [../captures/actual-light.png](../captures/actual-light.png)
- 후속 구현 검토 대상:
  - regenerated `docs/design/popover-redesign/captures/actual-dark.png`
  - regenerated `docs/design/popover-redesign/captures/actual-light.png`

테스트 링크 후보:

- Native snapshot files:
  - `/Users/moonsoo/projects/InnosDimmer/docs/design/popover-redesign/captures/actual-dark.png`
  - `/Users/moonsoo/projects/InnosDimmer/docs/design/popover-redesign/captures/actual-light.png`
- Native app build output after implementation:
  - `/Users/moonsoo/Library/Developer/Xcode/DerivedData/InnosDimmer-fbztptqynwfjrqcesypgzraazcye/Build/Products/Debug/InnosDimmer.app`
- Native GUI smoke check requires manual app launch or Computer Use after build.

## HTML 생략 보고서

- 판정: HTML 생략 가능.
- 이유: 이번 작업은 새 화면, 새 흐름, 새 인터랙션, 새 색상 팔레트가 아니라 이미 확정된 native AppKit popover의 typography token/weight 정합성 수정이다.
- 대체 검토물:
  - `docs/design/popover-redesign/mockup.html`
  - `docs/design/popover-redesign/mockup-preview.png`
  - `docs/design/popover-redesign/captures/actual-dark.png`
  - `docs/design/popover-redesign/captures/actual-light.png`
- 후속 검토 표면: 구현 후 regenerated native snapshots를 기준으로 판단한다.
- 중단 조건: 구현 중 간격, 카드 구조, 색상 팔레트, shortcut row 구조가 typography/weight 조정 범위를 넘어 바뀌면 새 HTML specimen 또는 기존 `mockup.html` 갱신을 먼저 수행한다.

## Scope

In scope:

- Update design documentation so Pretendard is the official app typography target.
- Keep AppKit/system font only as fallback when Pretendard is unavailable.
- Add role-specific typography tokens without deleting existing token names immediately.
- Migrate the native popover typography to semantic font tokens first.
- Reduce shortcut key symbol dominance while preserving the user's requirement that `⌥ / ⇧ / ↑` remain clearer and larger than `+`.
- Preserve preferred popover width and existing command behavior.
- Add a numeric typography path that keeps Pretendard while acknowledging digit-width stability.
- Regenerate native popover captures and run targeted tests.

Out of scope:

- Bundling Pretendard font files into the app.
- Downloading, installing, or package-managing fonts.
- Expanding `MenuBarPopoverView.preferredContentSize.width` unless all safer typography/spacing paths fail.
- Reintroducing SF Mono or system monospace for shortcut chips.
- Redesigning the popover layout, schedule rows, command routing, dimming behavior, or app window.
- Broad app-window typography migration beyond compatibility aliases unless needed to compile.

## Codebase Evidence

Confirmed current state:

- `DESIGN.md`
  - Lines 13-16 currently prefer system typography and San Francisco.
- `docs/design-decisions.md`
  - Contains popover and shared control-system decisions.
  - Does not contain an active Pretendard typography decision.
- `InnosDimmer/UI/DesignSystem/InnosDesignTokens.swift`
  - `Font.app(ofSize:weight:)` already tries Pretendard PostScript names first.
  - Existing shared tokens are coarse: `sectionTitle`, `body`, `bodyEmphasis`, `value`, `chip`, `button`.
- `InnosDimmer/UI/MenuBarPopoverView.swift`
  - The popover still assigns several local fonts directly through `Font.app(...)`.
  - `ShortcutKeyChipView` currently uses `13 / bold` for symbols, `9 / semibold` for `+`, and `12 / bold` for `Off`.
  - Shortcut spacing was tightened after Pretendard increased fitting width.
- `InnosDimmerTests/MenuBarStateTests.swift`
  - Has preferred-size and snapshot-writing tests.
  - Previous font pass finished with `39 tests`, `0 failures`.
- Repository font assets:
  - No bundled Pretendard `.ttf`, `.otf`, `.woff`, or `.woff2` files were found.

## Operator 결정 필요 사항

상태: 차단 결정 없음. 아래 항목은 이미 기본값이 정해진 실행 전제이며, 사용자가 반대하지 않으면 기본값으로 진행한다.

### 결정 1: Pretendard 기준 확정 방식

- 맥락: 문서는 SF/system fonts를 말하고, 코드는 Pretendard-first다.
- A: Pretendard를 공식 app UI typography target으로 문서화한다.
- B: SF/system font로 되돌린다.
- C: 문서에는 아무 결정도 남기지 않고 코드만 유지한다.
- 추천안: A
- 기본값: A
- 보류 시 영향: 문서/코드 충돌이 계속 남아 후속 작업자가 폰트 변경을 되돌릴 수 있다.

### 결정 2: Pretendard 번들링

- 맥락: 현재 repo에는 Pretendard font files가 없다.
- A: 이번 작업에 font bundle까지 포함한다.
- B: 이번 작업에서는 fallback 구조를 유지하고, font bundle은 release-hardening task로 분리한다.
- C: fallback을 제거하고 Pretendard 미설치 환경은 실패하게 둔다.
- 추천안: B
- 기본값: B
- 보류 시 영향: visual QA는 Pretendard 설치 환경 기준이라는 전제가 남는다. 배포 안정성은 별도 작업으로 남는다.

### 결정 3: 첫 typography 적용 범위

- 맥락: 앱 전체가 명시 폰트로 바뀌었지만, 문제는 popover에서 가장 크다.
- A: popover typography부터 역할별 토큰으로 옮긴다.
- B: app window/settings/schedule까지 한 번에 모두 재토큰화한다.
- C: shortcut chip만 직접 수정한다.
- 추천안: A
- 기본값: A
- 보류 시 영향: B는 회귀 표면이 커지고, C는 원인인 token 부재를 남긴다.

## Skill Routing Manifest

| Phase | Required skills | Optional skills | Evidence |
| --- | --- | --- | --- |
| Phase 1: Plan lock | `plan-first-implementation` | `research`, `해결전략검토` | This document, prior research, and strategy review define the execution source. |
| Commit 1: Typography contract sync | `구현커밋` | `design-docs-governance` | `DESIGN.md`, `docs/design-decisions.md`, solution research Risk 1. |
| Commit 2: Role-based font tokens with compatibility aliases | `구현커밋` | `design-foundations-tokens`, `review-swarm` | `InnosDesignTokens.Font` is the font owner; strategy review says keep old tokens as aliases. |
| Commit 3: Popover shortcut typography pilot | `구현커밋` | `design-a11y-qa` | `ShortcutKeyChipView` owns `⌥ + ⇧ + ↑` token rendering and fitting width pressure. |
| Commit 4: Numeric typography and spacing stabilization | `구현커밋` | `해결전략검토` | Numeric alignment lost monospaced-digit guarantee; spacing restoration must not break preferred width. |
| Commit 5: Snapshot and regression verification | `구현커밋` | `테스트`, `review-all-in-one` | `MenuBarStateTests`, regenerated captures, raw-font `rg` check. |
| Final Gate | `review-all-in-one`, `테스트` | `computer-use-operator` | Final review should compare code, docs, tests, and native captures. |

## 해결전략검토 반영

### 판정

조건부 적절.

### 반영한 조정

- The solution is not "replace all tokens at once."
- Keep existing token names as compatibility aliases.
- Add semantic role tokens first.
- Migrate popover first.
- Defer font bundling to a separate release-hardening task.
- Treat tabular numbers as a local feature-inspection task before adding complex descriptor code.

### 후보 비교

| 후보 | root-cause fit | 회귀 표면 | 구현 비용 | 검증 비용 | 판정 |
| --- | --- | --- | --- | --- | --- |
| A. Execute solution research exactly as written | High | Medium | Medium | Medium | Conditional |
| B. Add role tokens while preserving existing aliases, then migrate popover first | High | Low-Medium | Medium | Medium | Adopt |
| C. Only change shortcut weights | Medium | Low | Low | Low | Insufficient alone |
| D. Bundle Pretendard first | Partial | Medium | Medium-High | Medium | Defer |
| E. Increase popover width | Low | Medium | Low | Low | Reject unless last resort |

## Token Migration Map

| Current code role | Current implementation evidence | New token | Initial value | Notes |
| --- | --- | --- | --- | --- |
| App title | `makeHeader()` title uses `Font.app(17, .bold)` | `appTitle` | `17 / bold` | Keeps current hierarchy. |
| Section title | `sectionLabel()` uses `Font.app(12, .semibold)` while legacy token says `sectionTitle = 12 / bold` | `sectionLabel` | `12 / semibold` | Align token with actual popover, not old alias name. |
| Default body | Existing shared `body = 13 / regular` | `body` | `13 / regular` | Preserve. |
| Small wrapped body | `configureWrappingLabel()` uses `Font.app(12)` | `bodySmall` | `12 / regular` | Needed so popover stops using raw local font calls. |
| Strong body | Existing shared `bodyEmphasis = 13 / semibold` | `bodyStrong` | `13 / semibold` | Alias target for old name. |
| Control title | `ControlTitleView` receives `Font.app(13, .semibold)` | `controlLabel` | `13 / semibold` | Brightness/Warmth labels. |
| Control value | `valueLabel` uses `Font.app(18, .semibold)` while legacy token says `value = 18 / bold` | `controlValue` | `18 / semibold` | Match current toned-down AppKit capture. |
| Schedule/numeric value | Percent and schedule row numeric labels currently depend on local values/constraints | `numericValue` | `13 / semibold` | Keep Pretendard; stability comes from fixed widths unless tabular support is proven. |
| Button label | `PopoverCommandButton` uses `Font.app(12, .semibold)` | `buttonLabel` | `12 / semibold` | Existing shared `button = 13 / semibold` becomes compatibility alias only if broad app code still needs it. |
| Badge regular | `BadgePillView` regular uses `Font.app(12, .semibold)` | `badgeLabel` | `12 / semibold` | `MANUAL` keeps current size unless separately changed. |
| Badge compact | `BadgePillView` compact uses `Font.app(9, .semibold)` | `badgeCompact` | `9 / semibold` | `ENABLED` remains separately smaller. |
| Shortcut row title | `ShortcutPairRowView.titleLabel()` uses `Font.app(13, .semibold)` | `shortcutName` | `13 / semibold` | Preserve row balance. |
| Shortcut direction | `directionLabel()` uses `Font.app(12, .semibold)` | `shortcutDirection` | `12 / semibold` | Keep quieter than shortcut name. |
| Shortcut symbol | `ShortcutKeyChipView` symbols use `Font.app(13, .bold)` | `shortcutToken` | `13 / semibold` | Weight drops one step after Pretendard-first switch. |
| Shortcut separator | `+` uses `Font.app(9, .semibold)` | `shortcutSeparator` | `9 / medium` | Must remain smaller and quieter than symbols. |
| Shortcut off | `Off` uses `Font.app(12, .bold)` | `shortcutOff` | `12 / semibold` | Keep readable but not dominant. |
| Schedule metric value | `ScheduleSummaryRowsView.metricView()` uses `Font.app(13, .bold)` | `numericValue` | `13 / semibold` | Covered by Commit 4, not Commit 3, because it is numeric stabilization. |
| Schedule metric fallback icon | `ScheduleSummaryRowsView.metricIcon()` fallback uses `Font.app(11, .semibold)` | no new token in this pass | keep local or route to an icon-label token only if needed | Icon typography is not the core problem; avoid inventing a token without reuse. |
| Automation status line | `automationLabel` overrides wrapping label with `Font.app(12, .semibold)` | `bodySmallStrong` only if added, otherwise `bodySmall` plus color/hierarchy review | `12 / semibold` or `12 / regular` after screenshot check | This is a risk point; choose by visual hierarchy in Commit 4. |

## File Surface Boundary

`InnosDimmer/UI/MenuBarPopoverView.swift` contains several surfaces in one file. The implementation must not treat every `Font.app(ofSize:)` hit in that file as part of the same commit.

| Surface | Classes/functions | This plan's handling |
| --- | --- | --- |
| Shared popover primitives | `BadgePillView`, `ControlTitleView`, `PopoverContainerView`, `ProgressTrackView`, `ShortcutPairRowView`, `ShortcutKeyChipView`, `PopoverCommandButton` | In scope for Commit 2/3 if the primitive is used by the popover. |
| Popover schedule/shortcuts rows | `ScheduleSummaryRowsView`, `ShortcutSummaryRowsView`, `ShortcutSummaryGroup` | In scope, but schedule numeric labels belong to Commit 4. |
| Menu bar popover shell | `MenuBarPopoverView` and helper methods up to the popover layout helpers | In scope for Commit 3/4. |
| App dashboard window | `AppDashboardViewModel`, `AppDashboardWindowController` | Out of scope unless compile compatibility requires aliases. Leave direct `Font.app` calls for a later app-window typography pass. |
| Unified app window | `UnifiedAppWindowController` and nested controls | Out of scope unless compile compatibility requires aliases. Leave direct `Font.app` calls for a later app-window typography pass. |

## Implementation Plan

### Phase 1: Plan lock

- 대상 파일:
  - `docs/design/popover-redesign/typography-weight/2026-06-21-pretendard-typography-plan-first.md`
- 변경:
  - Lock the implementation sequence based on prior `research`, `solution-research`, and `해결전략검토`.
  - Define HTML omission and native snapshot review path.
- 검증:
  - Run:

```bash
rg -n "Skill Routing Manifest|Commit 1: Typography contract sync|후행 실행" docs/design/popover-redesign/typography-weight/2026-06-21-pretendard-typography-plan-first.md
```

- 성공 기준:
  - Plan has `Skill Routing Manifest`.
  - Plan has Commit/Phase headings.
  - Plan states 후행 실행 as `구현커밋`.
- 중단 조건:
  - If a newer typography decision supersedes this plan before implementation, update this plan first.
- 코드 스니펫: 필요 없음. Documentation-only lock.

### Commit 1: Typography contract sync

- 대상 파일:
  - `DESIGN.md`
  - `docs/design-decisions.md`
- 변경:
  - Add an active design decision that InnosDimmer uses Pretendard as the app UI typography target.
  - Update `DESIGN.md` foundation text from "Use San Francisco via AppKit system fonts" to Pretendard-first app UI typography with AppKit/system fallback.
  - Preserve the principle of native AppKit controls and macOS interaction behavior.
- 검증:
  - `rg -n "Pretendard|San Francisco|system fonts|typography" DESIGN.md docs/design-decisions.md`
- 성공 기준:
  - `DESIGN.md` no longer states SF/system fonts as the primary typography target.
  - `docs/design-decisions.md` records the typography decision and supersedes the old SF line.
  - The decision explicitly separates typography family from native AppKit control behavior.
- 중단 조건:
  - If the user rejects Pretendard as official product direction, stop and rewrite this plan.
- 코드 스니펫:

```md
Decision: InnosDimmer uses Pretendard as the app UI typography target, with AppKit system font fallback only when Pretendard is unavailable.

Reason: The operator selected Pretendard, the current implementation loads Pretendard first, and future weight tuning depends on Pretendard metrics.

Supersedes: `DESIGN.md` foundation rule "Use San Francisco via AppKit system fonts."
```

### Commit 2: Role-based font tokens with compatibility aliases

- 대상 파일:
  - `InnosDimmer/UI/DesignSystem/InnosDesignTokens.swift`
- 변경:
  - Keep `app(ofSize:weight:)` as the primitive font helper.
  - Add semantic role tokens:
    - `appTitle`
    - `sectionLabel`
    - `body`
    - `bodySmall`
    - `bodyStrong`
    - `bodySmallStrong` only if Commit 3/4 needs to preserve the current `12 / semibold` automation hierarchy without raw local font calls
    - `controlLabel`
    - `controlValue`
    - `numericValue`
    - `buttonLabel`
    - `badgeLabel`
    - `badgeCompact`
    - `shortcutName`
    - `shortcutDirection`
    - `shortcutToken`
    - `shortcutSeparator`
    - `shortcutOff`
  - Preserve old names as compatibility aliases where they are used outside the popover:
    - `sectionTitle`
    - `bodyEmphasis`
    - `value`
    - `chip`
    - `button`
  - Do not remove old token names in this commit.
  - Do not migrate `MenuBarPopoverView.swift` in this commit except if a compile break proves unavoidable. Popover migration belongs to Commit 3.
- 검증:
  - `xcodebuild -scheme InnosDimmer -configuration Debug build-for-testing CODE_SIGNING_ALLOWED=NO`
  - `rg -n "static var (appTitle|sectionLabel|bodySmall|shortcutToken|numericValue|buttonLabel)" InnosDimmer/UI/DesignSystem/InnosDesignTokens.swift`
- 성공 기준:
  - Project builds.
  - New semantic tokens exist.
  - Existing call sites that still use old token names remain compatible.
  - `InnosDesignTokens.Font.app(ofSize:weight:)` remains the only allowed AppKit fallback owner.
- 중단 조건:
  - If adding tokens forces broad unrelated UI edits, stop and split compatibility alias work into a smaller commit.
- 코드 스니펫:

```swift
enum Font {
    static var appTitle: NSFont { app(ofSize: 17, weight: .bold) }
    static var sectionLabel: NSFont { app(ofSize: 12, weight: .semibold) }
    static var body: NSFont { app(ofSize: 13, weight: .regular) }
    static var bodySmall: NSFont { app(ofSize: 12, weight: .regular) }
    static var bodyStrong: NSFont { app(ofSize: 13, weight: .semibold) }
    static var bodySmallStrong: NSFont { app(ofSize: 12, weight: .semibold) }
    static var controlLabel: NSFont { app(ofSize: 13, weight: .semibold) }
    static var controlValue: NSFont { app(ofSize: 18, weight: .semibold) }
    static var numericValue: NSFont { app(ofSize: 13, weight: .semibold) }
    static var buttonLabel: NSFont { app(ofSize: 12, weight: .semibold) }
    static var badgeLabel: NSFont { app(ofSize: 12, weight: .semibold) }
    static var badgeCompact: NSFont { app(ofSize: 9, weight: .semibold) }
    static var shortcutName: NSFont { app(ofSize: 13, weight: .semibold) }
    static var shortcutDirection: NSFont { app(ofSize: 12, weight: .semibold) }
    static var shortcutToken: NSFont { app(ofSize: 13, weight: .semibold) }
    static var shortcutSeparator: NSFont { app(ofSize: 9, weight: .medium) }
    static var shortcutOff: NSFont { app(ofSize: 12, weight: .semibold) }

    // Compatibility aliases.
    static var sectionTitle: NSFont { sectionLabel }
    static var bodyEmphasis: NSFont { bodyStrong }
    static var value: NSFont { controlValue }
    static var chip: NSFont { badgeLabel }
    static var button: NSFont { buttonLabel }
}
```

### Commit 3: Popover shortcut typography pilot

- 대상 파일:
  - `InnosDimmer/UI/MenuBarPopoverView.swift`
  - `InnosDimmer/UI/StatusBadgeView.swift` only if badge token migration is narrow
- 변경:
  - Replace local popover font calls with semantic tokens where the mapping is clear.
  - Apply shortcut pilot:
    - `shortcutToken = 13 / semibold`
    - `shortcutSeparator = 9 / medium` with existing `.tertiaryLabelColor`
    - `shortcutOff = 12 / semibold`
  - Keep symbol size at `13` for the first pass.
  - Keep current chip padding/spacing initially.
  - Do not expand preferred popover width.
  - Migration table:
    - `BadgePillView` compact: `badgeCompact`
    - `BadgePillView` regular: `badgeLabel`
    - `ShortcutPairRowView.titleLabel`: `shortcutName`
    - `ShortcutPairRowView.directionLabel`: `shortcutDirection`
    - `ShortcutKeyChipView` symbol tokens: `shortcutToken`
    - `ShortcutKeyChipView` plus separators: `shortcutSeparator`
    - `ShortcutKeyChipView` off chip: `shortcutOff`
    - `makeHeader()` title: `appTitle`
    - `makeControlGroup()` title font: `controlLabel`
    - `makeControlGroup()` value label: `controlValue`
    - `makeSummaryRow()` title label: `sectionLabel` only if it is semantically a small section label; otherwise use `bodySmall`
    - `configureWrappingLabel()`: `bodySmall`
    - `sectionLabel()`: `sectionLabel`
    - `automationLabel` override: `bodySmallStrong` if the current emphasis must remain; otherwise remove override and use `bodySmall`
    - `PopoverCommandButton.font`: `buttonLabel`
    - `PopoverCommandButton.updateColors()` fallback font: `buttonLabel`
- 검증:
  - `xcodebuild test -project InnosDimmer.xcodeproj -scheme InnosDimmer -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -only-testing:InnosDimmerTests/MenuBarStateTests/testMenuBarPopoverLayoutFitsPreferredContentSizeInLightAndDark`
  - `xcodebuild test -project InnosDimmer.xcodeproj -scheme InnosDimmer -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -only-testing:InnosDimmerTests/MenuBarStateTests/testMenuBarPopoverWritesDesignSnapshotsWhenRequested`
  - `rg -n "Font\\.app\\(ofSize" InnosDimmer/UI/MenuBarPopoverView.swift`
- 성공 기준:
  - Preferred-width test passes.
  - Snapshot-writing test regenerates captures.
  - Shortcut symbols remain larger/clearer than `+` but no longer dominate the row.
  - No direct `Font.app(ofSize:)` calls remain in the in-scope popover surfaces for migrated typography roles.
  - Any remaining direct `Font.app(ofSize:)` hits in `MenuBarPopoverView.swift` are either dashboard/window out-of-scope calls or explicitly deferred in `File Surface Boundary`.
- 중단 조건:
  - If symbols become too faint or unclear, stop and try `13 / bold` with reduced opacity before changing size.
  - If fitting width fails again, stop and inspect which role expanded before changing layout widths.
- 코드 스니펫:

```swift
let plus = Self.label(
    "+",
    font: InnosDesignTokens.Font.shortcutSeparator
)

let tokenLabel = Self.label(
    token,
    font: isOff
        ? InnosDesignTokens.Font.shortcutOff
        : InnosDesignTokens.Font.shortcutToken
)
```

```swift
font = InnosDesignTokens.Font.buttonLabel

attributedTitle = NSAttributedString(
    string: title,
    attributes: [
        .foregroundColor: foreground,
        .font: font ?? InnosDesignTokens.Font.buttonLabel
    ]
)
```

### Commit 4: Numeric typography and spacing stabilization

- 대상 파일:
  - `InnosDimmer/UI/DesignSystem/InnosDesignTokens.swift`
  - `InnosDimmer/UI/MenuBarPopoverView.swift`
  - optionally `InnosDimmer/UI/ScheduleEditorView.swift` only for token use, not layout redesign
- 변경:
  - Route schedule row values and compact numeric text through `numericValue`.
  - Keep fixed-width constraints for high-change numeric values.
  - Migrate `ScheduleSummaryRowsView.metricView()` value labels to `numericValue`.
  - Leave `ScheduleSummaryRowsView.metricIcon()` fallback font local unless a reusable `iconLabel` token is clearly needed.
  - Inspect installed Pretendard font-feature support before adding a committed `numericApp(ofSize:weight:)` helper.
  - If tabular figures are not clearly available, document that numeric stability is handled by fixed-width layout constraints in this pass.
  - After shortcut weight reduction, visually evaluate whether shortcut chip horizontal padding can move from `5` to `6` or `7`.
- 검증:
  - `rg -n "numericValue|monospacedDigitSystemFont|monospacedSystemFont" InnosDimmer/UI -g'*.swift'`
  - `xcodebuild test -project InnosDimmer.xcodeproj -scheme InnosDimmer -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -only-testing:InnosDimmerTests/MenuBarStateTests/testMenuBarPopoverLayoutFitsPreferredContentSizeInLightAndDark`
- 성공 기준:
  - No raw monospaced/system font calls reappear outside fallback.
  - Numeric labels keep fixed layout width.
  - The plan records whether tabular-number support was verified or deferred.
  - Remaining raw `Font.app(ofSize:)` calls in dashboard/window surfaces are documented as out-of-scope, not accidentally ignored.
- 중단 조건:
  - If local font-feature inspection requires complex Core Text work, defer tabular implementation and keep fixed-width constraints.
  - If padding restoration breaks width, keep `5` and record the tradeoff.
- 코드 스니펫:

```swift
static var numericValue: NSFont { app(ofSize: 13, weight: .semibold) }

// Optional future helper only after feature inspection proves this is needed.
// Do not add descriptor complexity in this pass unless the snapshot/test evidence
// shows numeric jitter that fixed-width constraints cannot absorb.
static func numericApp(ofSize size: CGFloat, weight: NSFont.Weight = .semibold) -> NSFont {
    app(ofSize: size, weight: weight)
}
```

```swift
// Temporary diagnostic only; do not commit unless converted into a real test helper.
let font = InnosDesignTokens.Font.numericValue
let descriptor = font.fontDescriptor
print(descriptor.object(forKey: .featureSettings) ?? "No explicit numeric feature settings")
```

### Commit 5: Snapshot and regression verification

- 대상 파일:
  - `docs/design/popover-redesign/captures/actual-dark.png`
  - `docs/design/popover-redesign/captures/actual-light.png`
  - `docs/design/popover-redesign/captures/dashboard-dark.png` and `dashboard-light.png` only if snapshot tests regenerate them
  - `docs/design/popover-redesign/typography-weight/2026-06-21-pretendard-typography-plan-first.md` if implementation findings require note updates
- 변경:
  - Regenerate native captures through existing tests.
  - Compare generated captures against `mockup-preview.png`.
  - Record any deferred font-bundling or tabular-number decisions as follow-up tasks.
- 검증:
  - `rg -n "systemFont|monospacedSystemFont|monospacedDigitSystemFont|NSFont\\.systemFont|NSFont\\.monospaced" InnosDimmer -g'*.swift'`
  - `xcodebuild test -project InnosDimmer.xcodeproj -scheme InnosDimmer -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -only-testing:InnosDimmerTests/MenuBarStateTests`
  - Visual inspection of:
    - `/Users/moonsoo/projects/InnosDimmer/docs/design/popover-redesign/captures/actual-dark.png`
    - `/Users/moonsoo/projects/InnosDimmer/docs/design/popover-redesign/captures/actual-light.png`
- 성공 기준:
  - `MenuBarStateTests` pass.
  - Raw font grep shows only allowed fallback path.
  - Shortcuts row is visually less dominant than the current capture.
  - `+` separators remain smaller and quieter than shortcut symbols.
  - Popover fits preferred width and height in light/dark.
- 중단 조건:
  - If snapshots reveal the buttons, badges, or schedule rows became visually weaker than intended, stop before committing and revisit token weights.
- 코드 스니펫: 필요 없음. Verification and artifact update commit.

## Plan Quality Check

- Alternative considered: shortcut-only weight patch.
  - Rejected as insufficient because it leaves the token model and design-contract mismatch intact.
- Alternative considered: full app-wide typography retokenization in one commit.
  - Rejected for this pass because it increases regression surface across settings/app-window/schedule views.
- Alternative considered: font bundling first.
  - Deferred because it is release-hardening and may require font assets; current supply-chain rules prohibit dependency/download shortcuts.
- Why this plan:
  - It targets the root cause in the smallest safe order: docs contract, token semantics, popover pilot, numeric stability, verification.
- Tradeoff:
  - Keeping compatibility aliases means some old token names remain temporarily.
  - This is acceptable because it lowers regression risk and lets implementation move screen-by-screen.
- What this plan may still miss:
  - Local Pretendard tabular-number support may not be discoverable without deeper Core Text inspection.
  - App-window typography may still need a later pass after popover stabilization.
- When to stop and revise:
  - If preferred width fails after role-token migration.
  - If screenshots show shortcut symbols are too faint after `semibold`.
  - If docs update reveals the user does not want Pretendard as official product typography.
  - If broad app-wide token changes become necessary to compile.

## Review Iteration Log

### Pass 1: `review-all-in-one` / `review-swarm`

- Finding: `Operator 결정 필요 사항` said `상태: 없음` while also presenting three decision blocks, which could be read as unresolved choices.
  - Fix: Reworded the status as "차단 결정 없음" and clarified that each item has an executable default.
- Finding: HTML omission existed as a one-line note, but the plan-first contract expects a dedicated omission report when UI/design work does not create a new HTML artifact.
  - Fix: Added `## HTML 생략 보고서` with classification, replacement artifacts, and the condition that forces a new specimen.
- Finding: Commit 2 code snippet referenced `buttonLabel` as an alias target without defining it, and did not show enough semantic tokens to guide implementation.
  - Fix: Expanded the token snippet to include all planned roles and compatibility aliases.
- Finding: Commit 3 did not map the current raw font calls to specific semantic tokens, leaving too much interpretation to the implementation agent.
  - Fix: Added a migration table covering badge, shortcut, header, control, section, body, and button roles.
- Finding: Commit 4's numeric-font direction was too vague and could accidentally invite premature Core Text descriptor work.
  - Fix: Reframed `numericApp` as future/optional, added a temporary diagnostic snippet, and kept fixed-width constraints as the acceptance path.

### Pass 2: `review-all-in-one` / `review-swarm`

- Finding: The first patched plan still used a broad `MenuBarPopoverView.swift` `Font.app` grep without explaining that the file also contains app-dashboard and unified-window surfaces.
  - Fix: Added `## File Surface Boundary`, clarified which `Font.app` hits are in scope, and documented dashboard/window typography as a later pass.
- Finding: Schedule metric and automation label raw fonts were visible in code evidence but not mapped precisely enough in the migration table.
  - Fix: Added schedule metric, fallback icon, and automation status rows to `Token Migration Map`; assigned numeric values to Commit 4.
- Finding: Phase 1's verification command used nested backticks inside Markdown inline code, which could render incorrectly.
  - Fix: Converted the command to a fenced `bash` block and removed the nested `구현커밋` backtick dependency from the regex.

### Pass 3: `review-all-in-one` / `review-swarm`

- Finding: No remaining blocker or important plan-document issue found.
- Residual risk: implementation may still reveal visual weight problems in regenerated native snapshots, especially `bodySmallStrong` vs `bodySmall` for automation status and the deferred Pretendard tabular-number question.

## Implementation Notes

### Commit 4 numeric stabilization

- Decision: Defer a committed `numericApp(ofSize:weight:)` or Core Text feature descriptor helper.
- Reason: The schedule row can be stabilized with `numericValue` plus fixed-width layout constraints, and adding descriptor-level OpenType feature code before visual evidence would widen the implementation surface.
- Applied path:
  - `ScheduleSummaryRowsView.metricView()` value labels use `InnosDesignTokens.Font.numericValue`.
  - Schedule metric values use a fixed `38pt` width to cover values such as `100%` without reintroducing monospaced/system fonts.
  - `ShortcutKeyChipView` horizontal padding moved from `5` to `6` after the shortcut token weight dropped to `semibold`.
- Verification:
  - `testMenuBarPopoverLayoutFitsPreferredContentSizeInLightAndDark` passed after the numeric width and padding changes.

## 구현 후 검토 리스트

- 회귀 확인:
  - Popover command routing remains unchanged.
  - `Open Control Window`, `Edit Shortcuts`, `Edit schedule`, `Pause/Resume automation`, `Quick disable`, and `Restore previous` keep existing behavior.
  - Preferred popover size still fits without horizontal or vertical overflow.
- 검증 확인:
  - Run `MenuBarStateTests`.
  - Run raw font grep for system/monospace calls.
  - Inspect regenerated `actual-dark.png` and `actual-light.png`.
- 리뷰 관점:
  - `review-all-in-one` should check docs/code sync, token role consistency, and screenshot/readability risks.
  - `design-a11y-qa` should check text overflow, contrast, and keyboard/focus surfaces only if UI behavior changes.
- Operator 재확인:
  - Confirm whether shortcut key chips now feel less dominant.
  - Confirm whether `ENABLED` compact badge size is acceptable.
  - Confirm whether font bundling should become the next release-hardening task.

## 후행 실행

후행 실행은 `구현커밋`으로 진행한다. 이 계획 문서가 실행 원본이며, implementation agent should detect this plan as the active plan source before patching production files.
