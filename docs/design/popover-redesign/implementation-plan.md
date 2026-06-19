# Popover Redesign Implementation Plan

## Target

`/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/MenuBarPopoverView.swift`

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

## Proposed Layout

1. Header
   - `InnosDimmer`
   - selected display
   - mode badge
   - automation chip
2. Primary controls
   - Brightness control row with value, slider, `-`, `+`
   - Blue reduction control row with value, slider, `-`, `+`
3. Schedule and safety
   - next schedule summary
   - quick disable and restore previous
   - pause automation
4. Secondary area
   - latest diagnostic summary
   - open app window
   - settings

## Visual Rules

- Keep the popover within the current `480 x 620` preferred size unless implementation proves clipping remains.
- Use a dark utility appearance with neutral panels, restrained separators, and blue only for the primary action/value accent.
- Do not use gradients, decorative glows, or large cards.
- Use framed groups only for functional clustering, with radius <= 8px.
- Keep text compact and wrap only in schedule/diagnostic summaries.
- Use stable row heights so values and buttons do not shift layout.

## AppKit Implementation Steps

1. Add small private helpers in `MenuBarPopoverView`:
   - `section(_ views: [NSView]) -> NSStackView`
   - `controlGroup(title:value:decrement:increment:) -> NSStackView`
   - `summaryRow(title:value:) -> NSStackView`
   - `secondaryActionRow(...)`
2. Replace the flat vertical stack in `buildLayout()` with grouped sections.
3. Add `NSSlider` only if value adjustment can be routed cleanly through existing commands or a new command surface.
   - Conservative first pass: use noninteractive progress track plus existing step buttons.
   - Fuller pass: add slider callbacks that emit absolute-value commands, which requires new command modeling.
4. Preserve `commandButtons` for all existing command tests.
5. Add test accessors only where needed for labels or layout assertions.
6. Update tests:
   - preferred popover size
   - every command still routable
   - labels use `Blue reduction`
   - diagnostics and schedule still wrap
   - new grouped layout includes primary controls before diagnostics
7. Run:

```bash
xcodebuild test -scheme InnosDimmer
xcodebuild -scheme InnosDimmer -configuration Release build CODE_SIGNING_ALLOWED=NO
```

## Recommended First Implementation Scope

Use the conservative first pass:

- Keep existing increment/decrement commands.
- Render compact value rows with a track-style progress indicator.
- Do not add absolute-value slider behavior yet.

Reason: current `MenuBarCommand` supports relative steps only. Real sliders would require a new command model for absolute values and more tests. The visual/ergonomic improvement can land safely first, then absolute sliders can be added as a second feature.

## Review Artifact

- Static mockup: `/Users/moonsoo/projects/InnosDimmer/docs/design/popover-redesign/mockup.html`
- Rendered preview: `/Users/moonsoo/projects/InnosDimmer/docs/design/popover-redesign/mockup-preview.png`

## Remaining Risks

- HTML mockup spacing does not guarantee AppKit constraint behavior.
- Real `NSPopover` material/background may differ from the mockup.
- If interactive sliders are added later, command modeling must change beyond this visual plan.
