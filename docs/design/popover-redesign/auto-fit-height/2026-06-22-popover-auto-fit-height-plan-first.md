# Popover Auto-Fit Height Plan First

## Goal

Remove the large bottom slack in the menu bar popover by sizing the popover to the actual content height after layout.

## Requested Outcome

- The popover height follows the visible internal sections.
- The schedule table keeps compact equal rows.
- The bottom gap stays at the intended outer inset, not a large fixed leftover area.
- Opening and refreshing the popover both apply the fitted size.

## 검토용 결과물

- HTML artifact omitted.
- Reason: this is an AppKit popover sizing bug, not a new visual direction. The review surface is the production snapshot pipeline:
  - `/Users/moonsoo/projects/InnosDimmer/docs/design/popover-redesign/captures/actual-dark.png`
  - `/Users/moonsoo/projects/InnosDimmer/docs/design/popover-redesign/captures/actual-light.png`

## Operator 결정 필요 사항

- 없음.
- Default: keep the approved `428pt` width and make only the height content-driven.

## Codebase Evidence

- `MenuBarPopoverView.preferredContentSize` is currently `428 x 749`.
- `MenuBarController.start()` assigns that fixed value directly to `NSPopover.contentSize`.
- `MenuBarPopoverView.buildLayout()` places all sections in one root vertical stack with `16pt` outer inset.
- Current tests verify the old fixed height range, so they do not catch bottom slack regressions.

## Implementation Strategy

- Keep the existing root stack and visual layout.
- Store the root stack so the view can measure `contentStack.fittingSize.height`.
- Add `MenuBarPopoverView.applyFittingContentSizeForPopover()` to set the view frame to `content height + top/bottom inset`.
- Update `MenuBarController` to copy the fitted view size into `NSPopover.contentSize` at start and refresh.
- Replace the old fixed-height test with assertions for fitted height and bottom inset.

## Code Snippets

Proposed sizing API:

```swift
@discardableResult
func applyFittingContentSizeForPopover() -> NSSize {
    let size = fittedContentSizeForPopover()
    setFrameSize(size)
    layoutSubtreeIfNeeded()
    return size
}
```

Proposed controller usage:

```swift
let view = MenuBarPopoverView(...)
popover.contentViewController?.view = view
popover.contentSize = view.frame.size
```

## Skill Routing Manifest

| Phase | Required skills | Optional skills | Evidence |
| --- | --- | --- | --- |
| Commit 1: Fit popover height to visible content | `plan-first-implementation`, `구현커밋` | `review-all-in-one` | `MenuBarPopoverView`, `MenuBarController`, and `MenuBarStateTests` own the sizing contract. |
| Final Gate | `review-all-in-one` | `테스트` | Run focused popover tests, related menu bar tests, inspect regenerated captures, and check worktree. |

## Implementation Plan

### Commit 1: Fit popover height to visible content

- 대상 파일:
  - `InnosDimmer/UI/MenuBarPopoverView.swift`
  - `InnosDimmer/UI/MenuBarController.swift`
  - `InnosDimmerTests/MenuBarStateTests.swift`
- 변경:
  - Add root stack measurement and a fitted-size API to the popover view.
  - Apply the fitted size after content updates.
  - Assign the fitted view size to `NSPopover.contentSize`.
  - Update tests to assert bottom inset instead of a fixed `749pt` height.
- 검증:
  - `xcodebuild -project InnosDimmer.xcodeproj -scheme InnosDimmer -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test -only-testing:InnosDimmerTests/MenuBarStateTests/testMenuBarPopoverUsesContentFitSizeWithoutBottomSlack -only-testing:InnosDimmerTests/MenuBarStateTests/testMenuBarPopoverLayoutFitsPreferredContentSizeInLightAndDark -only-testing:InnosDimmerTests/MenuBarStateTests/testMenuBarPopoverWritesDesignSnapshotsWhenRequested`
  - `xcodebuild -project InnosDimmer.xcodeproj -scheme InnosDimmer -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test -only-testing:InnosDimmerTests/MenuBarStateTests -only-testing:InnosDimmerTests/HotkeyBindingTests`
  - `git diff --check`
- 성공 기준:
  - Bottom inset is approximately `16pt`.
  - Fitted height is below the old fixed height.
  - Snapshot captures no longer show large bottom slack.
- 중단 조건:
  - Stop and revise if fitted sizing clips content, causes unsatisfiable constraints, or breaks popover button routing.

## Plan Quality Check

- Alternative considered: keep fixed height and reduce it manually. Rejected because future content changes can recreate slack or clipping.
- Why this plan: content-driven height matches the user request and removes the fixed-size source of the regression.
- Tradeoff: width remains fixed, so this is not full two-axis autoresizing. This is intentional because the approved layout depends on a stable compact width.
- What this plan may still miss: live popover animation behavior if content changes while visible; covered by assigning `NSPopover.contentSize` during refresh.
- When to stop and revise: if snapshot inspection shows clipping or bottom inset above the intended outer padding.

## 구현 후 검토 리스트

- 회귀 확인:
  - No large empty area below `Shortcuts`.
  - Schedule rows remain equal height.
  - Quick controls and shortcuts remain readable at `428pt` width.
- 검증 확인:
  - Focused popover sizing tests.
  - Related menu bar and hotkey tests.
  - Dark/light production capture inspection.
- 리뷰 관점:
  - Ensure sizing logic stays inside popover view/controller and does not alter app window layout.
  - Ensure tests assert the visible gap, not only nonblank snapshots.

## 후행 실행

`구현커밋`
