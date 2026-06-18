# Design Decisions

## INNOS-DES-2026-06-19-001

Status: Active

Decision: The menu bar popover is a compact quick-control surface, not a full diagnostics dashboard.

Reason: The existing popover includes state, schedule, shortcuts, diagnostics, and nine command buttons in a single vertical stack. The operator needs fast brightness and blue-reduction adjustment first; detailed logs already have a separate app window.

Supersedes: none

Source: `InnosDimmer/UI/MenuBarPopoverView.swift`, `README.md`, `docs/operator-guide.md`, Apple HIG popover/layout/control guidance.

## INNOS-DES-2026-06-19-002

Status: Active

Decision: Brightness and blue reduction should be represented as adjustable controls with value, track, and step actions.

Reason: The current paired text buttons force repeated clicking and do not communicate the current range. Apple HIG slider guidance frames sliders as controls for selecting a value from a continuous range.

Supersedes: current text-only `Brightness down/up` and `Blue reduction down/up` rows as the preferred redesign direction.

Source: `MenuBarCommand`, `MenuBarViewModel`, Apple HIG sliders guidance.

## INNOS-DES-2026-06-19-003

Status: Needs Decision

Decision: Decide how visibly the popover should report gamma apply/restore warnings.

Reason: Gamma is display-level state. Normal failures are recorded in diagnostics, but the quick-control popover may need a terse warning row when blue reduction is not applied while overlay brightness still works.

Supersedes: none

Source: `GammaDimmingController`, `SoftwareDimmingController`, `docs/2026-06-19-gamma-blue-reduction-plan-first.md`.
