# Native Popover Snapshot Comparison

## Baseline

- Source mockup: `docs/design/popover-redesign/mockup.html`
- Native render target: `InnosDimmer/UI/MenuBarPopoverView.swift`
- Initial score estimate: 52 / 100
- Main mismatch: section cards collapsed to the right, action rows did not fill available width, and native buttons used default AppKit emphasis instead of the mockup hierarchy.

## Loop Results

| Pass | Score estimate | Decision | Evidence |
| --- | ---: | --- | --- |
| Baseline | 52 | Rework | User screenshot and first AppKit snapshot showed narrow, right-aligned sections. |
| Pass 1 | 75 | Keep | Root sections were constrained to stack width. |
| Pass 2 | 86 | Keep | Nested rows, action buttons, copy, and diagnostics hierarchy matched the mockup structure. |
| Pass 3 | 90 | Keep | Header/status labels, schedule trailing label, light/dark palette, and snapshot generation stabilized. |
| Pass 4 | 93 | Keep | Tracks gained draggable thumbs and absolute percentage commands; schedule actions were regrouped into one full-width warning action plus two balanced secondary actions. |
| App dashboard pass | 90 | Keep | The full app window now uses the same header, card, summary-grid, and diagnostics-log visual language while keeping the log as the only added detail surface. |

## Current Evidence

- Dark native snapshot: `docs/design/popover-redesign/captures/actual-dark.png`
- Light native snapshot: `docs/design/popover-redesign/captures/actual-light.png`
- Snapshot size: 960 x 1240 pixels, rendered from the native 480 x 620 AppKit popover.
- Dark app dashboard snapshot: `docs/design/popover-redesign/captures/dashboard-dark.png`
- Light app dashboard snapshot: `docs/design/popover-redesign/captures/dashboard-light.png`
- Dashboard snapshot size: 1120 x 1280 pixels, rendered from the native 560 x 640 AppKit window content.

## Residual Difference

The native popover is still rendered by AppKit controls and SF text metrics, so it will not be pixel-identical to the HTML mockup. The important layout contract now matches: full-width sections, compact rows, right-aligned status labels, primary/warning button hierarchy, and one dynamic layout for light and dark appearances.
