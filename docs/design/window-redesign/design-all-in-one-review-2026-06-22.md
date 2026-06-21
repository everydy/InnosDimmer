# 2026-06-22 Design All-In-One Review

## Intake Gate

- Target project: `InnosDimmer`
- Surface: full native app window and the linked HTML mockup
- User intent: do not copy the mockup blindly, but preserve the useful patterns that the real app still misses
- Success criterion: the mockup becomes a cleaner design-system handoff, and the implementation plan stops treating pixel parity as the goal

## Baseline Gate

Rule sources checked:

- `DESIGN.md`
- `docs/design-decisions.md`
- `docs/design-components/README.md`
- `docs/design/window-redesign/app-window-componentized-mockup.html`
- `docs/design/window-redesign/mockup-gap-audit/2026-06-22-mockup-gap-repair-plan-first.md`
- `InnosDimmer/UI/MenuBarPopoverView.swift`
- `InnosDimmer/UI/ScheduleEditorView.swift`

Current design contract still holds:

- This is a quiet, dense, personal macOS menu bar utility.
- The popover is the quick-control surface.
- The app window is the full settings, schedule, and diagnostics surface.
- The app window should reuse the popover component language, not become a separate dashboard product.
- Brightness and blue reduction should be represented as value + track + step controls.
- Long state, schedule, shortcut, and diagnostics detail belongs in the app window, not the popover.

## Design Research Brief

Question:

How should a small macOS monitor-dimming utility structure its full window without copying an inefficient mockup or overbuilding a settings app?

Targets:

- Apple HIG toolbar/window guidance
- Lunar
- MonitorControl
- MonitorControl Lite App Store listing

Evidence:

- Apple HIG describes toolbars as grouped controls along a window edge, which supports keeping page-level commands in stable header or page action areas instead of scattering them through cards.
- Apple HIG window guidance keeps the frame/body distinction clear; our fake HTML titlebar is acceptable as a mockup wrapper but should not be treated as app UI content.
- Lunar emphasizes quick brightness control, sub-zero/software-style dimming, hotkeys, and adaptive modes. The transferable pattern is not Lunar's feature breadth; it is the split between fast adjustment and deeper automation state.
- MonitorControl emphasizes menu bar sliders and keyboard/native-key control. The transferable pattern is a minimal quick surface plus reliable global adjustment paths.
- MonitorControl Lite's App Store copy highlights menu bar brightness control, smooth transitions, custom shortcuts, and unobtrusive UI. This supports InnosDimmer's compact control language.

Transferable principles:

- Keep primary dimming actions on the first screen.
- Keep the full window navigable by stable categories: Current status, Display, Schedule, Shortcuts, Settings, Diagnostics.
- Avoid explanatory text that sounds like implementation documentation inside the UI.
- Use table-like editing for the fixed three schedule rows because the user edits repeated time/value records.
- Put save/pause/resume actions near the schedule editor, not in a disconnected summary card.
- Keep diagnostics readable as actual log rows plus a small verification summary.

Do not copy:

- Lunar's broad commercial feature set, because InnosDimmer is intentionally single-monitor and personal.
- MonitorControl's hardware-DDC assumptions, because InnosDimmer has already pivoted toward software overlay plus gamma blue reduction.
- Marketing copy, illustrations, or decorative visual treatment.

Sources:

- [Apple HIG Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars)
- [Apple HIG Windows](https://developer.apple.com/design/human-interface-guidelines/windows)
- [Apple HIG Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons)
- [Lunar](https://lunar.fyi/)
- [MonitorControl GitHub](https://github.com/MonitorControl/MonitorControl)
- [MonitorControl Lite App Store](https://apps.apple.com/us/app/monitorcontrol-lite/id1595464182)

## Mockup Revision Summary

Changed file:

- `docs/design/window-redesign/app-window-componentized-mockup.html`

What changed:

- Reduced navigation tile descriptions to short labels.
- Removed detailed implementation captions from Current status, Display, Schedule, Shortcuts, Settings, and Diagnostics pages.
- Renamed the detail page heading from `Automation` to `Schedule`.
- Removed the stale `SettingsWindowController.scheduleSummary` reference from the schedule page.
- Replaced the self-referential `Open app window` command with `Open popover`.
- Kept the useful schedule table pattern: `Time`, `Bright`, `Blue`, numeric input, slider, adjacent `-` / `+` controls, and a fixed three-row structure.
- Kept Diagnostics as verification summary plus actual log rows.

What intentionally remains:

- `data-page="automation"` remains for the static mockup router so existing click wiring keeps working. The visible user-facing label is now `Schedule`.
- `Automation active` remains as a status concept because the product still has automation state; the page/navigation label should be `Schedule`.
- The static HTML titlebar and theme toggle are mockup scaffolding, not implementation requirements.
- The schedule table intentionally has no add/remove row controls in this pass.

## Design Dev Sync Report

Rule source:

- `DESIGN.md` and active decisions are the source of truth.
- The HTML mockup is a proof/specimen, not a literal implementation contract.

Proof/specimen:

- The revised mockup now better reflects the design system by removing doc-like copy and stale code references.

Implementation:

- `UnifiedAppWindowController` is already the native owner of Home and all detail pages.
- `SettingsWindowController` is not active in the current code search.
- `ScheduleEditorView` already contains table-like editing with `Time`, `Bright`, `Blue`, numeric fields, sliders, and adjacent step controls.
- `ScheduleEditorView` is treated as fixed three rows for this implementation pass.
- Native detail pages already moved closer to the mockup, but still need scrutiny against the revised specimen rather than the older verbose mockup.

Mismatches:

- Implementation drift: the real app may still look under-composed compared with the target density and spacing, even when tests pass.
- Proof drift: the prior mockup carried too much explanation text and stale implementation references.
- Plan drift: the plan's original goal wording says to match the approved mockup closely enough, but the updated source of truth is design-system alignment plus useful mockup patterns.

Source of truth:

1. `DESIGN.md`
2. active `docs/design-decisions.md`
3. revised `app-window-componentized-mockup.html`
4. current native AppKit implementation
5. tests and screenshots

## Plan Feedback

The existing plan is directionally useful, but it needs this framing change:

- Do not frame the next implementation as "make the app match the mockup."
- Frame it as "make the app satisfy the design system, using the revised mockup as the current specimen for useful patterns."

Patterns that should be preserved from the mockup:

- Home starts with Quick actions, not navigation.
- Brightness and Blue reduction use the same value/slider/step control language as the popover.
- Primary commands are aligned in one action row and use short labels: Disable, Restore, Resume.
- Next actions are a compact vertical list, not three horizontal mini cards.
- Detail pages use Back + page title + page action, but avoid explanatory subtitles.
- Display and Settings may use split layouts when the side summary genuinely helps.
- Schedule should be a full-width editor section with a compact summary above it.
- Schedule should stay fixed to three rows in this pass.
- Diagnostics should show real log rows, not a raw text wall as the primary view.

Patterns that should be rejected or treated as mockup-only:

- Fake titlebar and theme toggle as app feature requirements.
- Long captions that explain where code data came from.
- Self-referential full-window commands like `Open app window` inside the full window.
- Pixel-perfect sizing as the implementation goal.
- A forced two-column split when a page has too little sidebar content.

Recommended next implementation checkpoints:

1. Re-run visual smoke screenshots for Home, Schedule, Settings, Diagnostics.
2. Compare screenshots against the revised mockup for structure, not exact pixels.
3. Fix only the gaps where the implementation violates the design-system source of truth.
4. Add/adjust tests for user-facing labels that should now be stable: `Schedule`, `Open popover`, `Disable`, `Restore`, `Resume`.
5. Keep old dirty audit artifacts separate from this design-system correction unless the user explicitly asks to package all audit files together.

## Remaining Decisions

- The open gamma warning decision remains unresolved in `docs/design-decisions.md`.
- `Open popover` is now the selected full-window Current status command because the native command route already exists.
- `Blue` remains the compact table-column label; `Blue reduction` remains the explicit accessibility/control label.
