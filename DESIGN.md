# InnosDimmer Design

## Current Design Contract

- Product: personal macOS menu bar utility for dimming a single external `27QA100M` display.
- Primary users: one operator who repeatedly changes brightness, blue reduction, automation, and diagnostics while working on macOS.
- Primary workflows: glance current dimming state, adjust brightness, adjust blue reduction, pause schedule, quick disable, restore previous, open app window, open settings.
- Experience principles:
  - Keep the menu bar popover quiet, dense, and utility-first.
  - Put the current display, mode, and automation status before secondary logs.
  - Make brightness and blue reduction feel like adjustable controls, not pairs of unrelated text buttons.
  - Keep dangerous or disruptive actions visually separate from routine adjustments.
  - Prefer native macOS control patterns and system typography over decorative styling.
- Foundations:
  - Use San Francisco via AppKit system fonts.
  - Use neutral system backgrounds and separators; avoid decorative gradients, glows, and marketing-style cards.
  - Prefer a dark popover treatment for this personal dimming utility so the control surface does not brighten the external display at night.
  - Keep corner radius at 8px or less for framed groups and repeated rows.
  - Keep spacing compact: 16px outer padding, 10-12px group gaps, 6-8px row gaps.
- Component rules:
  - Numeric dimming values should pair a large value label with a slider and small step controls.
  - Status should use concise badges with clear severity: ready, active, paused, warning, blocked.
  - Long schedule, shortcut, and diagnostics text should be collapsed or summarized inside the popover, with the full dashboard one click away.
  - Popover and app-window controls must share the same core component language: section shell, status chip, dimming control group, action row, summary row, diagnostics row, and footer status.
  - The app window may widen or group these components, but it should not rename, reorder, or visually restyle the same command family without a design decision.
- Pattern rules:
  - The popover is the quick-control surface; the app window remains the detailed diagnostics surface.
  - The popover should fit without vertical scrolling at its preferred size.
  - Settings and full diagnostics should be secondary navigation actions at the bottom.
  - The app window should reuse popover patterns before inventing new layout primitives. New window-only primitives need a documented reason.
- Accessibility target:
  - All controls need accessible labels, keyboard focus, and stable dimensions.
  - Text must wrap without overlap at the preferred popover width.
  - Color cannot be the only indicator of mode, pause, warning, or blocked status.
- Verification:
  - Unit tests should cover view model strings, command routing, preferred size, and key labels.
  - Manual review should compare the HTML mockup to the AppKit implementation before code changes.
- Open decisions:
  - Whether `Quick disable` should also set blue reduction to zero or only restore brightness to 100 while preserving blue reduction.
  - Whether gamma failures need a dedicated warning row in the popover or only in the app diagnostics window.
