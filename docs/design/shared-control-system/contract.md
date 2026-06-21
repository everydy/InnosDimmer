# InnosDimmer Shared Popover and Window Design Contract

## Design System Working Contract

- Product: personal macOS utility for dimming one external `27QA100M` display.
- Primary users: one operator repeatedly adjusting brightness, blue reduction, automation, shortcuts, startup, and diagnostics while working.
- Primary workflows: glance current state, adjust dimming, pause or resume automation, quick disable, restore previous dimming, review failures, edit durable settings.
- IA:
  - Popover: immediate control surface.
  - App window: durable settings and deeper diagnostics surface.
  - Shared layer: common command and status components used by both surfaces.
- User flows:
  - Fast path: menu bar -> brightness or blue reduction -> done.
  - Recovery path: menu bar -> quick disable -> restore previous.
  - Schedule path: menu bar or window -> automation summary -> schedule editor.
  - Troubleshooting path: warning chip -> diagnostics section/page -> export if needed.
  - Setup path: app window -> settings -> launch at login, target display, shortcuts.
- Experience principles:
  - Utility-first, quiet, dense, and native-feeling.
  - The popover defines the interaction language; the window expands it.
  - Do not make the app window look like a different dashboard product.
  - Current dimming state should be visible before logs, settings, or secondary navigation.
  - Dangerous or disruptive commands stay visually separate from routine adjustments.
- Foundations:
  - Use San Francisco/AppKit system typography.
  - Use neutral dark utility surfaces by default.
  - Use 8px or smaller radius for framed groups, controls, tiles, and badges.
  - Use compact spacing: 16px surface padding, 12px section gaps, 8px row gaps.
  - Avoid decorative gradients, glow, fake metrics, and marketing-style cards.
- Token strategy:
  - Use `InnosDesignTokens` as the AppKit source of truth for shared dark/light palette values.
  - Keep `PopoverPalette` only as a local compatibility facade while existing popover classes still call it.
  - Promote by meaning: surface, section, subtle surface, control, border, text, muted text, accent, ready, warning, danger.
  - Component tokens are allowed only for real variants such as primary button, warning button, and subtle diagnostics background.
  - Dark surfaces must stay neutral and very dark; accent blue is limited to progress, focus, and primary action states.
- Component priority:
  - `SectionShell`
  - `StatusChip`
  - `DimmingControlGroup`
  - `ActionRow`
  - `SummaryRow`
  - `OpsStrip`
  - `NavigationTile`
  - `DiagnosticsRow`
  - `FooterStatus`
- Pattern priority:
  - Current-state pattern.
  - Schedule-status pattern.
  - Settings-entry pattern.
  - Diagnostics-review pattern.
  - Page hub to detail-page pattern for the app window.
- Templates:
  - Popover template: header -> quick controls -> schedule -> shortcuts/settings actions.
  - App-window template: title bar -> home or detail page -> footer status.
  - Detail template: back button -> title/subtitle -> optional current-state rail -> primary section.
- Documentation:
  - Source of truth: `DESIGN.md`, `docs/design-decisions.md`, and this contract.
  - Visual proof: `docs/design/shared-control-system/specimen.html`.
  - Existing app-window exploration: `docs/design/window-redesign/app-window-componentized-mockup.html`.
- Dev integration:
  - Extract shared AppKit helpers only after the specimen and current mockup agree.
  - Prefer adapting `MenuBarPopoverView` helpers before creating a separate window-only style layer.
  - `InnosDesignTokens`, `PopoverPalette`, `PopoverContainerView`, `ProgressTrackView`, `PopoverCommandButton`, and `StatusBadgeView` are current implementation anchors.
- Accessibility target:
  - Stable dimensions for controls.
  - Accessible labels for every button, slider/track, and page navigation control.
  - Color cannot be the only signal for paused/warning/blocked states.
  - Text must wrap inside its region without overlapping neighboring controls.
- Governance:
  - A component can change only when both popover and window impact are checked.
  - New window-only components need a design decision explaining why shared components are insufficient.
  - HTML specimens are review artifacts, not implementation truth.
- Open decisions:
  - Whether `Quick disable` should also reset blue reduction or only restore brightness.
  - Whether gamma warnings should be visible in the popover, app window, or both.
  - Whether AppKit helper extraction should happen before or after the next window layout implementation.
- Next lanes:
  - Component promotion for shared AppKit helpers.
  - A11y QA for focus order and no-overlap checks.
  - Dev sync after the next implementation pass.

## Foundation Token Packet

- Source evidence:
  - `DESIGN.md`
  - `docs/design-decisions.md`
  - `docs/design/dark-palette/research.md`
  - `docs/design/dark-palette/2026-06-20-dark-palette-plan-first.md`
  - `InnosDimmer/UI/MenuBarPopoverView.swift`
  - `InnosDimmer/UI/DesignSystem/InnosDesignTokens.swift`
  - `docs/design/popover-redesign/mockup.html`
  - `docs/design/window-redesign/app-window-componentized-mockup.html`
- Existing tokens:
  - `InnosDesignTokens.surfaceRoot`
  - `InnosDesignTokens.surfaceSection`
  - `InnosDesignTokens.surfaceSubtle`
  - `InnosDesignTokens.surfaceControl`
  - `InnosDesignTokens.border`
  - `InnosDesignTokens.controlBorder`
  - `InnosDesignTokens.trackBackground`
  - `InnosDesignTokens.accent`
  - `InnosDesignTokens.primaryBackground`
  - `InnosDesignTokens.foreground`
  - `PopoverPalette.*` delegates to `InnosDesignTokens` for menu bar compatibility.
- New/changed primitives:
  - `surface.root.dark = #161616`
  - `surface.section.dark = #1f1f22`
  - `surface.subtle.dark = #18181b`
  - `surface.control.dark = #303036`
  - `border.default.dark = #3b3b40`
- New/changed semantics:
  - `surface.root`
  - `surface.section`
  - `surface.subtle`
  - `surface.control`
  - `border.default`
  - `text.primary`
  - `text.muted`
  - `accent.blue`
  - `status.ready`
  - `status.warning`
  - `status.danger`
- Component tokens:
  - `button.primary.background`
  - `button.warning.background`
  - `track.fill`
  - `chip.ready.foreground`
  - `chip.warning.foreground`
  - `section.radius`
  - `control.radius`
- CSS/code owner:
  - AppKit: `InnosDimmer/UI/DesignSystem/InnosDesignTokens.swift`.
  - Popover compatibility: `InnosDimmer/UI/MenuBarPopoverView.swift`.
  - HTML proof: `docs/design/shared-control-system/specimen.html` and `docs/design/dark-palette/artifacts/dark-palette-specimen.html`.
- Documentation owner:
  - `DESIGN.md`
  - `docs/design-decisions.md`
  - this contract
- Migration notes:
  - Keep mockup token headers aligned with the dark palette artifact.
  - Route AppKit custom colors through `InnosDesignTokens`; do not add new raw dark surface values to `PopoverPalette`.
  - Then replace ad hoc window controls with shared helpers.
- Verification:
  - Run HTML structure checks on `specimen.html`.
  - Review the specimen against popover/window mockups before AppKit changes.

## Shared Components

### SectionShell

Purpose: frame a related command group without making the page feel card-heavy.

Rules:

- Radius: 8px.
- Padding: 12px in popover, 12-14px in window.
- Header: section title left, optional chip/action right.
- Use for command groups, schedules, diagnostics, and settings groups.

### StatusChip

Purpose: show concise state.

Variants:

- ready
- warning
- danger
- neutral

Rules:

- Include text, not only color.
- Use 24-26px minimum height.
- Avoid stacking more than three chips in a compact header.

### DimmingControlGroup

Purpose: represent a dimming value as a real adjustable control.

Order:

```text
Label -> Value -> Track -> Decrement -> Increment
```

Rules:

- Brightness and blue reduction must use the same pattern.
- Value uses tabular/numeric emphasis.
- Track remains the primary affordance; step buttons are secondary.
- The app window may widen the track but must keep the same order.

### ActionRow

Purpose: group related commands.

Rules:

- Primary action appears first or right-most depending on native AppKit convention for that context.
- Warning commands use warning tone.
- Do not mix destructive and routine commands without visual separation.

### SummaryRow

Purpose: compact key/value status text.

Rules:

- Use for display, mode, automation, schedule, shortcuts, diagnostics.
- Keep label column stable.
- Long values wrap; they do not force horizontal scrolling.

### OpsStrip

Purpose: show brief operational state on the app-window home page.

Rules:

- Only high-level state belongs here.
- Detailed logs move to Diagnostics.
- Good cells: automation next boundary, diagnostics count, settings shortcut/login status.

### NavigationTile

Purpose: app-window page entry.

Rules:

- One icon region, title, and short description.
- Tile opens a page; it does not expose a nested setting.
- Do not duplicate the current-state controls as a nav tile when they already appear as controls.

### DiagnosticsRow

Purpose: make recent failures readable.

Rules:

- Include timestamp or relative time, severity, category, and message.
- Warning and error text must be readable without relying on color alone.

### FooterStatus

Purpose: persistent transient state.

Rules:

- Use for save/apply context and current page hint.
- Do not place detailed diagnostics in the footer.

## Popover Rules

- The popover is for immediate dimming control.
- It should not become the full settings window.
- It should show:
  - display/mode status
  - quick controls
  - schedule status
  - settings/app-window entry points
- It should collapse or summarize:
  - full shortcut table
  - full diagnostics log
  - full schedule editor

## App Window Rules

- The app window expands the same command language.
- It should show current controls on home or the first detail page.
- It should contain all durable settings:
  - target display
  - schedule
  - shortcuts
  - launch at login
  - diagnostics export
  - verification matrix
  - transient status label
- It should not introduce a separate visual style for the same commands.

## Implementation Handoff

Suggested AppKit helper targets:

```swift
private func makeSectionShell(title: String, trailing: NSView?, views: [NSView]) -> NSView
private func makeStatusChip(_ title: String, tone: StatusTone) -> NSTextField
private func makeDimmingControlGroup(
    title: String,
    valueLabel: NSTextField,
    trackView: ProgressTrackView,
    decrement: NSButton,
    increment: NSButton
) -> NSView
private func makeActionRow(_ buttons: [NSButton]) -> NSStackView
private func makeSummaryRow(title: String, value: NSView) -> NSView
```

Do not start by implementing the entire window layout. First make the shared helpers render the current popover without regression, then use them in the app window.
