# Research

## Goal

Prepare a design improvement plan and review mockup for the InnosDimmer menu bar popover. The plan should improve scanability and control ergonomics without changing runtime behavior yet.

## Scope And Entry Points

- Target surface: `MenuBarPopoverView`, the transient popover opened from the macOS menu bar item.
- Trigger mode: `research` Pre-Plan Research Gate with `디자인올인원` bootstrap, design-research, and redesign lanes.
- In scope:
  - current popover hierarchy
  - visible labels and action grouping
  - control patterns for brightness and blue reduction
  - design baseline needed before implementation
  - static HTML mockup for review
  - rendered PNG preview for quick visual review
  - dark-mode redesign direction
- Out of scope:
  - AppKit implementation changes
  - gamma algorithm changes
  - settings window redesign
  - app dashboard redesign

## Relevant Files

- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/MenuBarPopoverView.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/MenuBarController.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/StatusBadgeView.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Domain/BrightnessState.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Domain/ScheduleEntry.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Domain/ShortcutBinding.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmerTests/MenuBarStateTests.swift`
- `/Users/moonsoo/projects/InnosDimmer/README.md`
- `/Users/moonsoo/projects/InnosDimmer/docs/operator-guide.md`
- `/Users/moonsoo/projects/InnosDimmer/docs/2026-06-19-gamma-blue-reduction-plan-first.md`

## Current Behavior

The current popover is a fixed `480 x 620` vertical stack with these elements:

1. title: `INNOS 27QA100M`
2. mode badge
3. display summary
4. brightness value row
5. blue reduction value row
6. automation summary
7. schedule summary
8. shortcut summary
9. diagnostics summary
10. brightness down/up buttons
11. blue reduction down/up buttons
12. quick disable / restore previous buttons
13. pause automation
14. open app window
15. settings

This preserves all required commands, but it makes routine adjustment slower than necessary because the primary controls appear after several summary lines and are represented as text button pairs.

## Data Flow And Control Flow

- `MenuBarController.start()` creates `MenuBarPopoverView` and injects `MenuBarActions`.
- `MenuBarPopoverView.update(...)` builds `MenuBarViewModel`.
- `MenuBarViewModel` converts `BrightnessState`, `ScheduleEntry`, shortcuts, and latest diagnostics into display strings.
- `MenuBarPopoverView` owns button targets and maps them to `MenuBarCommand`.
- `MenuBarController.perform(_:)` maps commands to brightness, blue reduction, automation pause, quick disable, restore, app window, and settings behavior.

The redesign must preserve `MenuBarCommand.allCases`, existing routing tests, and value strings unless implementation tests are updated intentionally.

## Existing Abstractions And Boundaries

- `MenuBarViewModel` owns popover display copy.
- `MenuBarPopoverView` owns AppKit layout and command buttons.
- `MenuBarController` owns runtime side effects and diagnostics.
- `StatusBadgeView` owns the mode label vocabulary.
- `AppDashboardWindowController` is the full diagnostics surface and should not be duplicated in the popover.
- `SettingsWindowController` remains the schedule, shortcut, login item, and export configuration surface.

## Side Effects And Integration Points

- Changing command button creation can break `commandButtonForTesting(_:)`.
- Replacing buttons with sliders or segmented controls needs accessible labels and test hooks.
- Reordering summary text can break `MenuBarStateTests` if view model copy changes.
- A larger popover may reintroduce the earlier clipping problem; the redesign should fit inside the existing preferred size unless code review proves a better size.
- Gamma failures affect user trust because blue reduction is display-level state. The popover can summarize the latest warning, but detailed diagnostics should remain in the app window.

## Risk To Surrounding Systems

- High: duplicating diagnostics logic in the popover would create drift from `DiagnosticsStore` and the app dashboard.
- Medium: collapsing schedule/shortcut data too aggressively could hide automation state that explains unexpected dimming changes.
- Medium: introducing sliders without preserving step commands could break current shortcut/menu command tests.
- Low: visual-only grouping changes are safe if command identity and view model semantics are preserved.

## Do Not Duplicate Or Bypass

- Do not bypass `MenuBarCommand` or `MenuBarActions`.
- Do not call `BrightnessController` directly from `MenuBarPopoverView`.
- Do not duplicate full diagnostics log rendering from `AppDashboardWindowController`.
- Do not migrate internal `warmth` storage names during the popover redesign; visible copy can remain `Blue reduction`.
- Do not add third-party dependencies.

## Design Research Brief

- Question: How should a compact macOS menu bar popover expose two numeric dimming controls, automation state, and secondary actions?
- Targets:
  - Apple HIG Popovers
  - Apple HIG Sliders
  - Apple HIG Layout
  - Apple HIG Designing for macOS
  - Apple HIG Menus and actions
- Evidence:
  - Apple describes popovers as transient surfaces that appear when people click a control or interactive area.
  - Apple describes sliders as horizontal tracks for choosing a value between a minimum and maximum.
  - Apple layout guidance emphasizes differentiating controls from content.
  - Apple macOS guidance notes that people expect to use keyboard, pointing devices, and other input modes.
  - Apple menus/actions guidance points toward clear, action-oriented command labels.
- Transferable principles:
  - Keep the popover focused on quick decisions and immediate controls.
  - Put primary adjustable values above secondary status text.
  - Use sliders/steppers for brightness and blue reduction instead of equal-weight text button rows.
  - Use summary rows for schedule, shortcuts, and diagnostics; link to the app window for detail.
  - Preserve keyboard and pointer usability with visible focusable controls.
- Do not copy:
  - Apple marketing styling, Liquid Glass visual effects, or brand-specific animation.
  - Competitor UI styling. This research uses platform patterns, not product cloning.
- Project rule impact:
  - Create a minimal project design contract.
  - Treat the popover as a quick-control pattern.
  - Treat the app window as the diagnostics detail pattern.
  - Prefer a dark utility palette for this dimming app so the popover does not visually fight the user's brightness-reduction goal.
- Component/pattern candidates:
  - `ControlGroup`: title, value, slider, decrement, increment.
  - `StatusSummary`: display/mode/automation in a compact top band.
  - `SecondaryActionBar`: app window, settings, pause automation.
- Open decisions:
  - Whether `Quick disable` should preserve or zero blue reduction.
  - Whether gamma warnings should get a dedicated warning row in the popover.
- Sources:
  - https://developer.apple.com/design/human-interface-guidelines/popovers
  - https://developer.apple.com/design/human-interface-guidelines/sliders
  - https://developer.apple.com/design/human-interface-guidelines/layout
  - https://developer.apple.com/design/human-interface-guidelines/designing-for-macos
  - https://developer.apple.com/design/human-interface-guidelines/menus-and-actions

## Open Questions

- Should the first implementation include real `NSSlider` controls, or should it keep buttons but restyle them into compact stepper rows first?
- Should popover diagnostics show only the latest warning/error, or always show the latest event regardless of severity?
- Should the popover include the next scheduled boundary time as a prominent chip?

## Plan Implications

Recommended plan:

1. Preserve `MenuBarViewModel` semantics but add grouped display data for status, two controls, automation, and secondary summaries.
2. Rebuild `MenuBarPopoverView.buildLayout()` into four regions:
   - header/status
   - primary controls
   - automation and context
   - secondary actions
3. Introduce a reusable control row pattern in AppKit:
   - label
   - current value
   - slider or stable track mock
   - decrement/increment buttons
4. Keep `commandButtonForTesting(_:)` or add equivalent test hooks for every command.
5. Update tests for preferred size, visible strings, command routing, and no-clipping expectations.
6. Run full `xcodebuild test -scheme InnosDimmer` after implementation.

## Evidence

- Local code read:
  - `rg --files | sort | rg '(^DESIGN\\.md$|design|MenuBarPopover|SettingsWindow|README|operator-guide|qa-matrix)'`
  - `sed -n '1,380p' InnosDimmer/UI/MenuBarPopoverView.swift`
  - `sed -n '1,220p' InnosDimmer/UI/StatusBadgeView.swift`
  - `sed -n '1,220p' InnosDimmerTests/MenuBarStateTests.swift`
  - `sed -n '1,140p' InnosDimmer/Domain/DimmingMode.swift`
  - `sed -n '1,110p' InnosDimmer/Domain/ScheduleEntry.swift`
  - `sed -n '1,120p' InnosDimmer/Domain/ShortcutBinding.swift`
- Official sources checked on 2026-06-19:
  - Apple HIG Popovers: https://developer.apple.com/design/human-interface-guidelines/popovers
  - Apple HIG Sliders: https://developer.apple.com/design/human-interface-guidelines/sliders
  - Apple HIG Layout: https://developer.apple.com/design/human-interface-guidelines/layout
  - Apple HIG Designing for macOS: https://developer.apple.com/design/human-interface-guidelines/designing-for-macos
  - Apple HIG Menus and actions: https://developer.apple.com/design/human-interface-guidelines/menus-and-actions
- Insufficient evidence:
  - Browser Playwright rendering could not use the bundled browser or local Chrome in this environment, so the preview screenshot was generated with macOS Quick Look.
  - The HTML mockup has not been converted into AppKit constraints yet.
  - Actual accessibility tree and keyboard focus order still need verification after implementation.
