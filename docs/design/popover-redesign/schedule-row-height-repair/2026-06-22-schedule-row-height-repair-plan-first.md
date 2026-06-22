# Schedule Row Height Repair Plan First

## Goal

Fix the production popover schedule table regression where the first schedule row becomes much taller than the remaining rows.

## Requested Outcome

- All schedule table rows have equal compact height.
- The first row no longer expands vertically.
- Existing schedule text, command routing, automation state, and shortcut display remain unchanged.
- A regression test prevents this specific layout failure.

## 검토용 결과물

- HTML artifact omitted.
- Reason: this is a production AppKit layout bug with a direct screenshot reproduction and an existing actual capture pipeline. The review surface is the regenerated production captures:
  - `/Users/moonsoo/projects/InnosDimmer/docs/design/popover-redesign/captures/actual-dark.png`
  - `/Users/moonsoo/projects/InnosDimmer/docs/design/popover-redesign/captures/actual-light.png`

## Operator 결정 필요 사항

- 없음.
- Default: repair the row height constraint and verify with tests/captures.

## Codebase Evidence

- Confirmed:
  - `ScheduleSummaryRowsView` renders schedule rows as arranged subviews in a vertical `NSStackView`.
  - Row containers used `heightAnchor.constraint(greaterThanOrEqualToConstant: 34)`.
  - The screenshot shows row 1 taking much more vertical space than rows 2 and 3.
- Inferred:
  - The vertical stack can allocate extra height to an arranged row because the row height is only a lower bound.
- Unverified before implementation:
  - Whether exact `34pt` row height fully removes the visible expansion in regenerated captures.

## Related Files

- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/MenuBarPopoverView.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmerTests/MenuBarStateTests.swift`
- `/Users/moonsoo/projects/InnosDimmer/docs/design/popover-redesign/captures/actual-dark.png`
- `/Users/moonsoo/projects/InnosDimmer/docs/design/popover-redesign/captures/actual-light.png`
- `/Users/moonsoo/projects/InnosDimmer/docs/design/popover-redesign/schedule-row-height-repair/research.md`
- `/Users/moonsoo/projects/InnosDimmer/docs/design/popover-redesign/schedule-row-height-repair/review-all-in-one.md`

## Implementation Strategy

- Keep the existing table component.
- Change row height from minimum height to exact height.
- Add a targeted test helper that reads actual row frames after layout.
- Assert all default schedule rows are the same compact height.
- Refresh production captures after tests pass.

## Code Snippets

Target constraint:

```swift
container.heightAnchor.constraint(equalToConstant: 34)
container.setContentHuggingPriority(.required, for: .vertical)
container.setContentCompressionResistancePriority(.required, for: .vertical)
```

Target regression assertion:

```swift
view.layoutSubtreeIfNeeded()
let rowHeights = view.popoverScheduleRowHeightsForTesting()
XCTAssertEqual(rowHeights.count, 3)
rowHeights.forEach { height in
    XCTAssertEqual(height, 34, accuracy: 1)
}
```

## Skill Routing Manifest

| Phase | Required skills | Optional skills | Evidence |
| --- | --- | --- | --- |
| Commit 1: Fix schedule row height regression | `review-all-in-one`, `research`, `plan-first-implementation`, `구현커밋` | `review-swarm` | Code/test fix in `MenuBarPopoverView.swift` and `MenuBarStateTests.swift`; screenshot reproduction. |
| Commit 2: Refresh production popover captures if needed | `구현커밋` | `테스트` | `actual-dark.png` and `actual-light.png` must show compact equal schedule rows; skip this commit if tests leave captures unchanged and visual inspection confirms the fix. |
| Final Gate | `review-all-in-one` | `review-swarm` | Verify tests, captures, and clean worktree. |

## Implementation Plan

### Commit 1: Fix schedule row height regression

- 대상 파일:
  - `InnosDimmer/UI/MenuBarPopoverView.swift`
  - `InnosDimmerTests/MenuBarStateTests.swift`
- 변경:
  - Add a schedule row height testing API.
  - Change row height constraint from `>= 34` to `== 34`.
  - Set vertical hugging/compression resistance to required.
  - Assert all schedule rows are equal compact height after layout.
- 검증:
  - `xcodebuild -project InnosDimmer.xcodeproj -scheme InnosDimmer -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test -only-testing:InnosDimmerTests/MenuBarStateTests/testMenuBarPopoverExposesScheduleStructureForTesting`
- 성공 기준:
  - Targeted test passes.
  - No schedule row can take extra vertical slack.
- 중단 조건:
  - If exact row height causes clipping, stop and revise to exact table height plus row constraints.

### Commit 2: Refresh production popover captures if needed

- 대상 파일:
  - `docs/design/popover-redesign/captures/actual-dark.png`
  - `docs/design/popover-redesign/captures/actual-light.png`
- 변경:
  - Regenerate captures through existing snapshot test path.
  - Visually confirm first schedule row no longer expands.
  - Commit capture files only when they become dirty.
- 검증:
  - `xcodebuild -project InnosDimmer.xcodeproj -scheme InnosDimmer -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test -only-testing:InnosDimmerTests/MenuBarStateTests -only-testing:InnosDimmerTests/HotkeyBindingTests`
  - `git diff --check`
- 성공 기준:
  - `71 tests` pass.
  - Captures render compact equal schedule rows.
- 중단 조건:
  - If captures still show unequal rows, do not commit captures; revise layout.

## Plan Quality Check

- Alternative considered:
  - Set only vertical hugging priority while keeping `>= 34`. Rejected because the row can still legally expand.
- Why this plan:
  - Exact row height matches the approved compact table design and directly fixes the faulty constraint.
- Tradeoff:
  - Exact height is stricter, but the schedule row content is fixed-size and already designed for compact 34pt rows.
- What this plan may still miss:
  - A future content string longer than current values could need clipping handling, but current schedule cells are numeric and compact.
- When to stop and revise:
  - Stop if row content clips or if AppKit logs unsatisfiable constraints.

## 구현 후 검토 리스트

- 회귀 확인:
  - First schedule row is not taller than the others.
  - `AUTO/MANUAL` quick controls badge remains.
  - `Shortcuts` `ENABLED` badge remains removed.
- 검증 확인:
  - Focused popover structure test.
  - MenuBarStateTests + HotkeyBindingTests.
  - Dark/light actual capture inspection.
- 리뷰 관점:
  - Ensure this fix does not widen into schedule data/model changes.
  - Ensure captures are regenerated only after tests pass.

## 후행 실행

`구현커밋`
