# Popover Redesign Implementation Plan

## Target

`/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/MenuBarPopoverView.swift`

This plan exists to convert the HTML review mockup into the native macOS menu bar popover. The implementation must remain Swift/AppKit. Do not embed the HTML mockup or add a web view.

## Skill Routing Manifest

| Phase | Required skills | Optional skills | Evidence |
| --- | --- | --- | --- |
| Commit 1: Preserve review artifacts and native transfer contract | `research`, `plan-first-implementation` | `design-all-in-one` | `research.md`, `mockup.html`, and this plan define the HTML-to-AppKit mapping before app code changes. |
| Commit 2: Rebuild native popover layout shell | `구현커밋` | `review-all-in-one` | `MenuBarPopoverView.swift` owns AppKit layout; command routing must stay in `MenuBarCommand` and `MenuBarActions`. |
| Commit 3: Add native progress tracks and appearance palette | `구현커밋` | `qa-gate` | HTML tracks map to AppKit views; light/dark must use one layout with dynamic colors. |
| Commit 4: Test command routing, state refresh, and layout semantics | `구현커밋`, `qa-gate` | `테스트` | `MenuBarStateTests.swift` already verifies command buttons, size, and value refresh. |
| Final Gate | `review-all-in-one`, `qa-gate` | `테스트` | Native screenshot or AppKit render check must prove the popover looks like the mockup without clipping. |

## Source To Preserve

- All `MenuBarCommand` cases:
  - brightness down/up
  - blue reduction down/up
  - pause automation
  - quick disable
  - restore previous
  - open app window
  - settings
- Current state values:
  - mode
  - selected display
  - brightness percent
  - blue reduction percent
  - automation pause/resume
  - schedule summary
  - shortcut summary
  - latest diagnostic summary
- Existing command routing through `MenuBarActions`.
- Existing test access to `commandButtonForTesting(_:)`, plus equivalent semantic hooks for new native controls.

## Review Artifact

- Current static mockup: `/Users/moonsoo/projects/InnosDimmer/docs/design/popover-redesign/mockup.html`
- Rendered preview: `/Users/moonsoo/projects/InnosDimmer/docs/design/popover-redesign/mockup-preview.png`
- Research basis: `/Users/moonsoo/projects/InnosDimmer/docs/design/popover-redesign/research.md`

The HTML mockup is visual evidence only. It should guide spacing, hierarchy, grouping, and light/dark palette behavior, but the production app must be AppKit.

## Operator Decision Needed

Status: none.

Default: implement one native popover that follows macOS light/dark appearance. Do not create separate Swift code paths for light and dark. The earlier light and dark mockups should become appearance variants of the same AppKit layout.

## Proposed Native Layout

1. Header
   - `InnosDimmer`
   - selected display summary
   - mode badge
   - automation chip
2. Primary controls
   - Brightness control row with value, track, `-`, `+`
   - Blue reduction control row with value, track, `-`, `+`
3. Schedule and safety
   - schedule summary
   - shortcut summary
   - quick disable and restore previous
   - pause automation
4. Secondary area
   - latest diagnostic summary
   - open app window
   - settings

## Visual Rules

- Keep the popover within the current `480 x 620` preferred size unless native verification proves clipping remains.
- Use one dynamic AppKit palette that supports both light and dark appearances.
- Use restrained neutral backgrounds, separators, and a single accent color for value/progress emphasis.
- Do not use gradients, decorative glows, web views, or large cards.
- Use framed groups only for functional clustering, with radius <= 8 px.
- Keep text compact and wrap only in schedule and diagnostic summaries.
- Use stable row heights so values and buttons do not shift layout.

## Implementation Plan

### Commit 1: Preserve review artifacts and native transfer contract

- 대상 파일:
  - `/Users/moonsoo/projects/InnosDimmer/docs/design/popover-redesign/research.md`
  - `/Users/moonsoo/projects/InnosDimmer/docs/design/popover-redesign/implementation-plan.md`
  - `/Users/moonsoo/projects/InnosDimmer/docs/design/popover-redesign/mockup.html`
- 변경:
  - Keep the HTML mockup as a visual reference.
  - Document that production implementation is Swift/AppKit, not HTML/web content.
  - Record the HTML-to-AppKit mapping and light/dark appearance strategy.
- 검증:
  - Read the plan and research artifacts.
  - Confirm links point to local files that exist.
- 성공 기준:
  - A future `구현커밋` run can identify changed Swift files, tests, and verification gates without reinterpreting the design from scratch.
- 중단 조건:
  - If the operator wants forced dark-only behavior instead of system light/dark appearance, revise the palette plan before Swift changes.
- 코드 스니펫:
  - 필요 없음. This is a documentation and planning commit.

### Commit 2: Rebuild native popover layout shell

- 대상 파일:
  - `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/MenuBarPopoverView.swift`
  - `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/StatusBadgeView.swift` only if badge styling should stay reusable outside the popover.
- 변경:
  - Replace the flat vertical stack in `buildLayout()` with private AppKit helpers:
    - `makeHeader()`
    - `makeSection(title:trailing:content:)`
    - `makeSummaryRow(title:value:)`
    - `makeActionRow(...)`
  - Keep `MenuBarViewModel` display strings unless tests deliberately change copy.
  - Keep `commandButtons` registration for every existing `MenuBarCommand`.
- 검증:
  - `xcodebuild test -scheme InnosDimmer -only-testing:InnosDimmerTests/MenuBarStateTests`
- 성공 기준:
  - All current commands remain routable.
  - Existing visible state tests still pass or are updated only for intentional semantic changes.
  - The popover frame remains `480 x 620`.
- 중단 조건:
  - If the grouped layout clips in native rendering, stop and adjust size/spacing before adding more visual polish.
- 코드 스니펫:

```swift
// Proposed shape only. Final code should follow project style.
private func makeSection(title: String, trailing: NSView? = nil, views: [NSView]) -> NSView {
    let content = NSStackView(views: views)
    content.orientation = .vertical
    content.spacing = 10
    return StyledSectionView(title: title, trailing: trailing, content: content)
}
```

### Commit 3: Add native progress tracks and appearance palette

- 대상 파일:
  - `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/MenuBarPopoverView.swift`
  - `/Users/moonsoo/projects/InnosDimmer/InnosDimmerTests/MenuBarStateTests.swift`
- 변경:
  - Add a lightweight AppKit progress track for brightness and blue reduction.
  - Update track fractions in `update(...)` from `state.targetBrightness` and `state.targetWarmth`.
  - Use dynamic colors from system colors first; add a private dynamic palette only if actual popover contrast is weak.
  - Keep `-` and `+` buttons as the only value-changing controls in this pass.
- 검증:
  - Add tests for brightness and blue track fractions.
  - Add tests or assertions that compact `-` and `+` buttons still route their commands.
- 성공 기준:
  - The visual track matches the mockup intent without introducing absolute slider behavior.
  - Light and dark appearance can be verified from one Swift layout.
- 중단 조건:
  - If true slider behavior is required immediately, stop and expand the command model plan before implementing.
- 코드 스니펫:

```swift
// Proposed shape only.
final class ProgressTrackView: NSView {
    var fraction: CGFloat = 0 {
        didSet {
            fraction = min(1, max(0, fraction))
            needsDisplay = true
        }
    }
}
```

### Commit 4: Test command routing, state refresh, and layout semantics

- 대상 파일:
  - `/Users/moonsoo/projects/InnosDimmer/InnosDimmerTests/MenuBarStateTests.swift`
- 변경:
  - Preserve `testMenuBarPopoverButtonsRouteEveryCommand`.
  - Preserve/update visible state refresh tests.
  - Add semantic checks that primary controls appear before diagnostics if stable test hooks exist.
  - Avoid pixel-perfect AppKit unit tests; use runtime/native screenshot verification for visual approval.
- 검증:
  - `xcodebuild test -scheme InnosDimmer -only-testing:InnosDimmerTests/MenuBarStateTests`
  - `xcodebuild -scheme InnosDimmer -configuration Release build CODE_SIGNING_ALLOWED=NO`
- 성공 기준:
  - Targeted tests pass.
  - Release build passes.
  - Native popover screenshot or direct app inspection shows no clipping.
- 중단 조건:
  - If unrelated full-suite tests still fail from time/display/defaults isolation, report that separately and do not hide it as a popover failure.
- 코드 스니펫:
  - 필요 없음. Tests should use existing accessors or small semantic accessors added in `MenuBarPopoverView`.

## Recommended First Implementation Scope

Use the conservative first pass:

- Keep existing increment/decrement commands.
- Render compact value rows with a noninteractive AppKit track.
- Do not add absolute-value slider behavior yet.
- Use one dynamic native view for light and dark appearances.

Reason: current `MenuBarCommand` supports relative steps only. Real sliders would require a new command model for absolute values and more tests. The visual/ergonomic improvement can land safely first, then absolute sliders can be added as a second feature.

## Alternative Considered

- Embed the HTML mockup in a web view: rejected because the app is a native macOS menu bar utility and existing tests/controllers are AppKit-based.
- Implement true `NSSlider` immediately: deferred because current commands are relative and the app lacks absolute-value command routing.
- Force dark-only popover: deferred because the user asked to keep both light and dark design directions, and macOS users expect system appearance support unless there is a strong product reason to override it.

## Why This Plan

This plan preserves the current command architecture while moving the popover to the visual hierarchy of the mockup. It makes the first Swift change mostly layout and appearance, not controller behavior.

## Tradeoff

- Gain: lower implementation risk, fewer behavior regressions, and a native popover that can match both mockup directions.
- Cost: the track will look slider-like but will not support dragging in the first pass.
- Acceptable reason: `-` and `+` controls already match the current command model and hotkey behavior.
- Revisit when: the operator explicitly wants draggable absolute sliders or users need faster large value changes.

## What This Plan May Still Miss

- Native `NSPopover` materials and vibrancy can alter contrast compared with HTML.
- Accessibility focus order needs real AppKit inspection after implementation.
- Actual menu bar popover placement may make long diagnostics feel tighter than the static mockup.

## When To Stop And Revise

Stop before merging implementation if:

- the real popover clips inside `480 x 620`
- light or dark appearance has poor contrast
- any `MenuBarCommand` loses a button or route
- tests require controller behavior changes beyond visual/layout work

## Implementation After-Review Checklist

- 회귀 확인:
  - every `MenuBarCommand` routes through `MenuBarActions`
  - quick disable / restore behavior remains whatever the controller tests currently define
  - diagnostics still summarize the latest event without duplicating the app window log
- 검증 확인:
  - targeted `MenuBarStateTests`
  - Release build
  - native popover visual inspection in light and dark appearance
- 리뷰 관점:
  - no duplicated controller side effects in the view
  - no web view or third-party dependency
  - no clipping or layout jumps
- Operator 재확인:
  - confirm whether noninteractive tracks are acceptable for the first native pass
  - confirm whether system appearance should remain the default for light/dark

## Remaining Risks

- HTML mockup spacing does not guarantee AppKit constraint behavior.
- Real `NSPopover` material/background may differ from the mockup.
- If interactive sliders are added later, command modeling must change beyond this visual plan.
