# 2026-06-19 Blue Reduction Semantics Plan First

## Summary

The app already uses gamma-based blue-channel reduction for the user-facing `Blue reduction` control, but the runtime model still carries older `warmth` naming and the gamma scale is a simple linear reduction. This plan finishes the semantic cleanup without changing the product direction: software overlay remains responsible for perceived brightness, gamma remains responsible for blue reduction, and existing saved settings must continue to load.

## Scope

In scope:

- Rename current runtime/domain semantics from `warmth` to `blueReduction` where the value now means blue-light reduction.
- Preserve legacy decode compatibility for saved settings that still contain `targetWarmth`, `warmth`, `warmthUp`, or `warmthDown`.
- Replace the linear gamma scale with a gentler low-end curve so 0-20% feels less artificial while stronger ranges remain available.
- Add user-facing warning copy for high blue reduction values where color distortion is expected.
- Update focused tests and current operator docs that describe the active behavior.

Out of scope:

- Removing historical plan documents that mention warmth as an old implementation phase.
- Reintroducing hardware DDC/CI brightness control.
- Changing the brightness overlay strategy.
- Changing app icon, signing, release packaging, or Spotlight cleanup.

## Current Evidence

- `GammaDimmingController.blueScale(for:)` currently maps linearly: `1.0 - reduction * 0.45`.
- `SoftwareDimmingController.apply(_:)` already sends the second control to `GammaDimmingController.apply(display:blueReduction:)`.
- `OverlayAppearance.make(brightness:warmth:)` ignores warmth and returns `warmOpacity = 0`.
- `MenuBarPopoverView` and `AppDashboardWindowController` already show `Blue reduction` copy in the user-facing UI.
- `BrightnessState.targetWarmth`, `BrightnessCommand.warmth`, `ScheduleEntry.warmth`, `ShortcutAction.warmthUp`, and `MenuBarCommand.warmthUp` remain as compatibility-era internal names.

## 검토용 결과물

- 계획 MD: `docs/2026-06-19-blue-reduction-semantics-plan-first.md`
- HTML 생략 보고서: 이번 작업은 새 레이아웃/색상/컴포넌트 디자인이 아니라 existing native UI의 data semantics, gamma math, tests, persistence compatibility를 정리하는 작업이다. 검토 표면은 HTML mock보다 Swift tests와 앱 빌드가 더 정확하다.
- 후행 테스트 표면: `xcodebuild test` and `xcodebuild build` for the native macOS target.

## Operator 결정 필요 사항

- 없음. 적용한 기본값: persisted legacy keys are decoded for compatibility, while current encoded keys move to `blueReduction` naming. This keeps old settings readable and moves new settings toward the current product language.

## Skill Routing Manifest

| Phase | Required skills | Optional skills | Evidence |
| --- | --- | --- | --- |
| Commit 1: Plan source and scope lock | `plan-first-implementation` | `research` | This document defines scope, compatibility requirements, HTML omission, and executable commit units. |
| Commit 2: Rename runtime blue-reduction semantics with compatibility | `구현커밋` | `review-all-in-one` | Domain/runtime files and tests must preserve legacy decode while replacing active internal names. |
| Commit 3: Tune gamma curve and high-range warning | `구현커밋` | `review-all-in-one` | `GammaDimmingController`, popover/dashboard state, and tests prove the gentler low range and warning behavior. |
| Final Gate | `review-all-in-one`, `qa-gate` | `테스트` | Build/test output and git diff must show no hardware-control regression and no broken persistence compatibility. |

## Implementation Plan

### Commit 1: Plan source and scope lock

- Target files:
  - `docs/2026-06-19-blue-reduction-semantics-plan-first.md`
- Changes:
  - Add this plan as the implementation source.
  - Explicitly record HTML omission because this is logic/persistence work, not a design review artifact.
- Verification:
  - `python3 - <<'PY'` heading check for `## Skill Routing Manifest` and `### Commit N:` sections.
- Success criteria:
  - The plan contains scope, compatibility decision, executable commit units, and final gate.
- Stop condition:
  - Stop if the plan conflicts with a newer active schedule-editing plan that requires the old `warmth` internal fields to remain untouched.
- Code snippet:

```swift
// Proposed compatibility shape, not exact final code.
let blueReduction = try container.decodeIfPresent(Int.self, forKey: .blueReduction)
    ?? container.decodeIfPresent(Int.self, forKey: .targetWarmth)
    ?? defaultValue
```

### Commit 2: Rename runtime blue-reduction semantics with compatibility

- Target files:
  - `InnosDimmer/Domain/BrightnessState.swift`
  - `InnosDimmer/Domain/BrightnessCommand.swift`
  - `InnosDimmer/Domain/ScheduleEntry.swift`
  - `InnosDimmer/Domain/ShortcutBinding.swift`
  - `InnosDimmer/Services/BrightnessController.swift`
  - `InnosDimmer/Services/SoftwareDimmingController.swift`
  - `InnosDimmer/UI/MenuBarController.swift`
  - `InnosDimmer/UI/MenuBarPopoverView.swift`
  - `InnosDimmer/UI/SettingsWindowController.swift`
  - `InnosDimmerTests/*`
- Changes:
  - Replace active runtime names with `blueReduction` equivalents.
  - Decode legacy persisted keys:
    - `targetWarmth` -> `targetBlueReduction`
    - `warmth` -> `blueReduction`
    - `warmthUp` -> `blueReductionUp`
    - `warmthDown` -> `blueReductionDown`
  - Keep visible copy as `Blue reduction`.
- Verification:
  - Focused domain/settings/hotkey/menu tests.
  - Full test build if focused tests pass.
- Success criteria:
  - Existing old JSON test fixtures still decode.
  - New encoded JSON uses `targetBlueReduction` and `blueReduction`.
  - Source code no longer uses `targetWarmth` or `.warmth` for current runtime paths outside legacy decode tests/docs.
- Stop condition:
  - Stop if Codable migration requires a broader schema bump than localized compatibility decode.
- Code snippet:

```swift
enum CodingKeys: String, CodingKey {
    case targetBlueReduction
    case legacyTargetWarmth = "targetWarmth"
}
```

### Commit 3: Tune gamma curve and high-range warning

- Target files:
  - `InnosDimmer/Services/GammaDimmingController.swift`
  - `InnosDimmer/UI/MenuBarPopoverView.swift`
  - `InnosDimmerTests/SoftwareDimmingControllerTests.swift`
  - `InnosDimmerTests/MenuBarStateTests.swift`
- Changes:
  - Replace linear scale with a curve:
    - 0-20% stays gentle.
    - 20-40% becomes clearer but still controlled.
    - 50%+ remains available as strong reduction.
  - Add high-range UI warning text when blue reduction is 50% or higher.
- Verification:
  - Unit tests for `blueScale(for:)` at 0, 20, 40, 50, and 100.
  - Menu/dashboard view-model tests for warning visibility.
- Success criteria:
  - 20% blue reduction produces less reduction than the old 0.91 scale.
  - 40% and higher still visibly reduce blue.
  - Warning appears only in high range.
- Stop condition:
  - Stop if the curve makes current default schedule values visually too weak in tests or manual QA.
- Code snippet:

```swift
static func blueScale(for blueReduction: Int) -> CGGammaValue {
    let percent = CGGammaValue(Clamped.percent(blueReduction)) / 100.0
    let shaped = pow(percent, 1.35)
    return max(0.0, 1.0 - shaped * Constants.maximumBlueReduction)
}
```

## Plan Quality Check

- Alternative considered: keep all internal `warmth` names and only tune `blueScale`. Rejected because it leaves the exact confusion that triggered this follow-up.
- Alternative considered: hard schema migration with a new `schemaVersion`. Rejected because the old values are simple aliases and can be decoded locally without forcing a broad migration.
- Why this plan: it separates semantic cleanup from algorithm tuning while preserving old settings.
- Tradeoff: renaming touches many tests and call sites, but the change is mechanical and makes future blue-reduction work clearer.
- What this plan may still miss: stale historical docs may still mention warmth; this plan intentionally avoids rewriting old plan documents.
- When to stop and revise: stop if tests reveal that saved shortcuts/settings cannot be decoded safely with local compatibility decode.

## 구현 후 검토 리스트

- 회귀 확인:
  - Quick disable still resets blue reduction to 0.
  - Restore previous still restores brightness and blue reduction.
  - Schedule entries still apply brightness and blue reduction.
  - Legacy settings JSON still decodes.
- 검증 확인:
  - `xcodebuild test -scheme InnosDimmer -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO`
  - `xcodebuild -scheme InnosDimmer -configuration Debug build CODE_SIGNING_ALLOWED=NO`
- 리뷰 관점:
  - No hardware DDC/CI path is reintroduced.
  - Gamma failure and restore semantics remain unchanged.
  - Old persisted keys remain readable.
- Operator 재확인:
  - Manually check whether 20%, 32%, and 58% blue reduction feel less artificial on the actual INNOS monitor.

## 후행 실행

- 후행 실행: `구현커밋`
- 자동 탐지 기준: this document has `## Skill Routing Manifest` and `### Commit N:` headings.
