# Shortcut Compression Plan First

## Goal

Compress the menu bar popover `Shortcuts` rows when up/down bindings share the same modifier keys.

## Requested Outcome

- Default rows render as:
  - `Brightness  Up / Down  ⌥ + ⇧ + ↑ / ↓`
  - `Warmth  Up / Down  ⌥ + ⇧ + → / ←`
- If either side is `Off`, keep the existing split layout:
  - `Brightness  Up  Off  Down  ⌥ + ⇧ + ↓`
- Keep existing shortcut routing, settings editor bindings, and app-window shortcut editor unchanged.

## 검토용 결과물

- Existing HTML mockup/current mockup and production captures.
- HTML artifact is not created separately because this changes an existing small component variant in both mockup-current and AppKit implementation.

## Operator 결정 필요 사항

- 없음.
- Default: compress only when both shortcuts are enabled and have the same modifier prefix.

## Codebase Evidence

- `ShortcutPairRowView` currently renders four horizontal cells: `Up`, up chip, `Down`, down chip.
- `ShortcutSummaryFormatter.plainSummary` currently always emits the split text shape.
- `ShortcutKeyChipView` currently inserts `+` between every character token, so a compressed slash variant needs explicit token handling.
- Tests already cover both default enabled shortcuts and disabled `Off` fallback.

## Implementation Strategy

- Add a small compression model to `ShortcutSummaryGroup`.
- Keep `ShortcutKeyChipView(title:)` for existing split/off rows.
- Add a compressed chip initializer that renders modifier tokens once, then `first / second` direction tokens.
- Update `ShortcutPairRowView` to branch between compressed and split layouts.
- Update tests and `mockup-current.html` to match the new default compact display.

## Code Snippets

```swift
if let compressed = group.compressedKeyDisplay {
    // Up / Down + shared modifier chip
} else {
    // Existing Up + chip + Down + chip fallback
}
```

## Skill Routing Manifest

| Phase | Required skills | Optional skills | Evidence |
| --- | --- | --- | --- |
| Commit 1: Compress shared shortcut modifiers | `plan-first-implementation`, `구현커밋` | `review-all-in-one` | `MenuBarPopoverView`, `MenuBarStateTests`, and `mockup-current.html` define the popover shortcut display. |
| Final Gate | `review-all-in-one` | `테스트` | Focused popover/view-model tests and visual mockup/capture inspection. |

## Implementation Plan

### Commit 1: Compress shared shortcut modifiers

- 대상 파일:
  - `InnosDimmer/UI/MenuBarPopoverView.swift`
  - `InnosDimmerTests/MenuBarStateTests.swift`
  - `docs/design/popover-redesign/mockup-current.html`
- 변경:
  - Add compression detection for shared modifier shortcuts.
  - Render compressed rows as `Up / Down` plus one shared chip.
  - Preserve split layout when either key is `Off`.
  - Update expected summary strings.
- 검증:
  - `xcodebuild -project InnosDimmer.xcodeproj -scheme InnosDimmer -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test -only-testing:InnosDimmerTests/MenuBarStateTests/testMenuBarViewModelShortcutSummaryStillFocusesOnCoreAdjustments -only-testing:InnosDimmerTests/MenuBarStateTests/testMenuBarViewModelUsesStateValues -only-testing:InnosDimmerTests/MenuBarStateTests/testMenuBarPopoverUpdateRefreshesVisibleStateAndDiagnostics`
  - `xcodebuild -project InnosDimmer.xcodeproj -scheme InnosDimmer -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test -only-testing:InnosDimmerTests/MenuBarStateTests/testMenuBarPopoverButtonsRouteEveryCommand -only-testing:InnosDimmerTests/MenuBarStateTests/testMenuBarPopoverCommandButtonsKeepMinimumActionHeight -only-testing:InnosDimmerTests/MenuBarStateTests/testMenuBarPopoverExposesScheduleStructureForTesting -only-testing:InnosDimmerTests/MenuBarStateTests/testMenuBarPopoverLayoutFitsPreferredContentSizeInLightAndDark -only-testing:InnosDimmerTests/MenuBarStateTests/testMenuBarPopoverShowsResumeAutomationWhenPaused -only-testing:InnosDimmerTests/MenuBarStateTests/testMenuBarPopoverTracksRouteAbsolutePercentageCommands -only-testing:InnosDimmerTests/MenuBarStateTests/testMenuBarPopoverUpdateRefreshesVisibleStateAndDiagnostics -only-testing:InnosDimmerTests/MenuBarStateTests/testMenuBarPopoverUsesContentFitSizeWithoutBottomSlack -only-testing:InnosDimmerTests/MenuBarStateTests/testMenuBarPopoverWritesDesignSnapshotsWhenRequested -only-testing:InnosDimmerTests/MenuBarStateTests/testMenuBarViewModelShortcutSummaryStillFocusesOnCoreAdjustments -only-testing:InnosDimmerTests/MenuBarStateTests/testMenuBarViewModelUsesStateValues -only-testing:InnosDimmerTests/HotkeyBindingTests`
  - `git diff --check`
- 성공 기준:
  - Default rows use compressed summary.
  - Disabled rows keep split summary.
  - Popover visible state tests pass.
- 중단 조건:
  - Stop if compressed chip tokenization inserts `+` around `/`, or if disabled rows no longer show `Off` clearly.

## Plan Quality Check

- Alternative considered: Always compress regardless of disabled state. Rejected because `Off / ↓` is less clear than the existing split fallback.
- Why this plan: It removes duplicated `⌥ + ⇧` while preserving readability and the disabled-state exception the Operator requested.
- Tradeoff: Adds one conditional view path, but keeps the existing split path as fallback.
- What this plan may still miss: Custom shortcut pairs with different modifiers stay split, which is intentional.
- When to stop and revise: If a custom enabled pair has same direction but different modifiers and is incorrectly compressed.

## 구현 후 검토 리스트

- 회귀 확인:
  - Default brightness/warmth rows are compressed.
  - Any `Off` pair remains split.
  - Shortcut chip typography and plus/slash spacing remain readable.
- 검증 확인:
  - Focused view-model and popover tests.
  - Mockup-current visual check.
- 리뷰 관점:
  - Ensure only menu bar popover summary changes, not shortcut editor behavior.

## 후행 실행

`구현커밋`
