# InnosDimmer Design Components

This registry tracks reusable UI primitives that should be shared by the menu bar popover and standalone app window.

## Registry

| Component | Contract | Code owner | Stage | Guard |
| --- | --- | --- | --- | --- |
| Section shell | `contracts/section-shell.md` | `InnosSectionView`, `InnosComponentFactory.section` | scaffolded | compile + specimen |
| Status chip | `contracts/status-chip.md` | `InnosStatusChipView` | scaffolded | compile + specimen |
| Dimming control group | `contracts/dimming-control-group.md` | `InnosDimmingControlGroupView`, `InnosDimmingTrackView` | scaffolded | compile + specimen |
| Action row | `contracts/action-row.md` | `InnosComponentFactory.actionRow` | scaffolded | compile + specimen |
| Summary row | `contracts/summary-row.md` | `InnosComponentFactory.summaryRow` | scaffolded | compile + specimen |

## Promotion Rule

The popover is the canonical control surface. The app window can widen or regroup components, but it should not invent a different visual language for the same command family.

## Migration Order

1. Keep the current popover behavior unchanged.
2. Replace one low-risk popover section with shared helpers.
3. Verify command routing and visual layout.
4. Reuse the same helpers in the app window.
5. Only then remove older private helper duplication.
