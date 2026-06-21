# Research

## Goal

Define recommended solutions for the typography problems found after switching InnosDimmer to Pretendard-first app fonts. This is a pre-implementation research pass: no production code is changed here.

Mode: `research` Purpose Research with a design-foundations/tokens lane and design QA review lens.

## Scope And Entry Points

In scope:

- Resolve the mismatch between the active design contract and Pretendard-first implementation.
- Recommend a token structure that can support future font-weight tuning without ad hoc local changes.
- Recommend specific first-pass weight changes for shortcut key chips and related small labels.
- Recommend a safe approach to numeric stability after dropping `monospacedDigitSystemFont`.
- Recommend how to handle Pretendard availability and app-bundle reliability.
- Recommend verification gates for visual and mechanical regressions.

Out of scope:

- Editing `DESIGN.md`, `docs/design-decisions.md`, or Swift source in this pass.
- Bundling font files.
- Changing popover behavior, command routing, or preferred size.
- Broad external benchmarking. External evidence is limited to official Apple font/design resources and the Pretendard source repository.

## Relevant Files

- `/Users/moonsoo/projects/InnosDimmer/DESIGN.md`
- `/Users/moonsoo/projects/InnosDimmer/docs/design-decisions.md`
- `/Users/moonsoo/projects/InnosDimmer/docs/design/popover-redesign/typography-weight/research.md`
- `/Users/moonsoo/projects/InnosDimmer/docs/design/popover-redesign/mockup.html`
- `/Users/moonsoo/projects/InnosDimmer/docs/design/popover-redesign/mockup-preview.png`
- `/Users/moonsoo/projects/InnosDimmer/docs/design/popover-redesign/captures/actual-dark.png`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/DesignSystem/InnosDesignTokens.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/MenuBarPopoverView.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmerTests/MenuBarStateTests.swift`

## Current Behavior

The app now uses `InnosDesignTokens.Font.app(ofSize:weight:)` for explicit UI fonts. This helper tries Pretendard PostScript names first and falls back to `NSFont.systemFont(...)` if Pretendard is unavailable.

The active design contract still says to use San Francisco via AppKit system fonts. That means the implementation and documentation currently disagree.

The current font token set is coarse:

| Token | Current role |
| --- | --- |
| `sectionTitle` | section headings |
| `body` | normal labels |
| `bodyEmphasis` | emphasized labels |
| `value` | values |
| `chip` | chips |
| `button` | buttons |

The popover still has many local typography roles that bypass semantic token names even though they use the Pretendard helper:

- header title
- section title
- control title
- control value
- schedule row values
- shortcut name
- shortcut direction
- shortcut symbol token
- shortcut `+` separator
- `Off` key chip
- compact badge

The latest test run after the previous font change passed `MenuBarStateTests` with `39 tests`, `0 failures`, but the first run failed because Pretendard increased intrinsic width. The current passing state depends partly on reduced shortcut row and chip spacing.

## Data Flow And Control Flow

Typography flows through two layers:

1. `InnosDesignTokens.Font`
   - Chooses family and maps `NSFont.Weight` to Pretendard PostScript names.
   - Provides the few shared font tokens.

2. UI composition files, mainly `MenuBarPopoverView`
   - Assign local sizes and weights to concrete labels and controls.
   - `ShortcutKeyChipView` splits the shortcut text into symbols and separators.
   - `MenuBarPopoverView.preferredContentSize` tests detect overflows caused by intrinsic text size.

The recommended fix should therefore start at token semantics, then move outward into local view roles. Directly tweaking scattered local weights would keep the current problem alive.

## Existing Abstractions And Boundaries

- `DESIGN.md` is the active design contract and must describe the current typography system.
- `docs/design-decisions.md` is the correct place to record the decision that supersedes SF/system typography.
- `InnosDesignTokens.Font` is the correct implementation owner for family and semantic typography roles.
- `ShortcutKeyChipView` is the correct local owner for symbol/separator layout.
- `MenuBarStateTests` are the current mechanical guard for preferred popover size, command routing, and key-label behavior.
- `mockup.html` and `mockup-preview.png` are review artifacts, not implementation owners.

## Side Effects And Integration Points

- Any weight or size change can alter intrinsic width and break the `428` preferred popover width.
- Font availability changes visual output. Without bundled Pretendard files, the same app can render as Pretendard on one machine and SF/system on another.
- Shortcut key symbols are both typography and symbolic UI. They need text-token control and should not be treated like ordinary body text.
- SF Symbols icon weights remain controlled through `NSImage.SymbolConfiguration`, not Pretendard text tokens.
- Numeric values are not merely text; they are dynamic operational readings that benefit from stable widths.

## Risk To Surrounding Systems

### Risk 1: Documentation can overwrite the implementation direction

If `DESIGN.md` continues to say "Use San Francisco via AppKit system fonts," future design/dev-sync work may revert Pretendard or create conflicting mockups.

Recommended solution:

- Add a new design decision:
  - `Decision`: InnosDimmer uses Pretendard as the app typography target for visible app UI, with AppKit system font as fallback only when Pretendard is unavailable.
  - `Reason`: The user explicitly chose Pretendard; the current implementation already loads Pretendard first; future weight tuning depends on Pretendard metrics.
  - `Supersedes`: `DESIGN.md` foundation line that specifies San Francisco/system fonts.
- Update `DESIGN.md` to say:
  - Use Pretendard for app UI typography.
  - Keep native AppKit control behavior and spacing.
  - Use system font only as fallback, not as the design target.

Adoption: **Adopt immediately before further font tuning.**

### Risk 2: Font tokens are too coarse to tune safely

The current tokens cannot distinguish "numeric value" from "shortcut token" from "badge label." That makes every future weight adjustment risky.

Recommended solution:

- Replace the current small token set with semantic role tokens while keeping the current `app(ofSize:weight:)` primitive helper.
- Suggested first token structure:

| New token | Suggested initial value | Purpose |
| --- | --- | --- |
| `appTitle` | `17 / bold` | popover/app title |
| `sectionLabel` | `12 / semibold` | uppercase section labels |
| `body` | `12-13 / regular` | ordinary explanatory text |
| `bodyStrong` | `13 / semibold` | important short labels |
| `controlLabel` | `13 / semibold` first, later test `14 / semibold` | brightness/warmth labels |
| `controlValue` | `18 / semibold` | large current values |
| `numericValue` | `13 / semibold` with tabular strategy if possible | schedule row values and compact numbers |
| `buttonLabel` | `12 / semibold` for popover buttons, `13 / semibold` for app window buttons | action buttons |
| `badgeLabel` | `12 / semibold` | regular status chips |
| `badgeCompact` | `9 / semibold` or `8 / semibold` after visual check | compact chips like `ENABLED` |
| `shortcutName` | `13 / semibold` | `Brightness`, `Warmth` |
| `shortcutDirection` | `12 / semibold` | `Up`, `Down` |
| `shortcutToken` | `13 / semibold` | `⌥`, `⇧`, arrows |
| `shortcutSeparator` | `9 / medium` plus tertiary color | `+` separators |
| `shortcutOff` | `12 / semibold` | `Off` key chip |

Adoption: **Adopt.** This should be the main implementation step before individual weights are tuned.

### Risk 3: Shortcut key symbols are visually too strong after Pretendard

The current shortcut symbols are `13 / bold`. They satisfy the requirement that symbols be larger than `+`, but they dominate the row.

Recommended solution:

- Change `shortcutToken` from `13 / bold` to `13 / semibold`.
- Keep `+` smaller than symbols, but make it less prominent through weight and color:
  - `shortcutSeparator`: `9 / medium`
  - keep `.tertiaryLabelColor`
- Change `shortcutOff` from `12 / bold` to `12 / semibold`.
- Do not reduce symbol size before trying weight. The user explicitly wanted `⌥ / ⇧ / ↑` to be larger and clearer than `+`; reducing size first would work against that direction.
- Keep chip padding/spacing stable for the first weight pass. If the weight pass reduces width, avoid adding width back unless the visual looks cramped.

Adoption: **Pilot first.** This is the lowest-risk visual fix and should be verified with updated screenshots.

### Risk 4: Pretendard width was treated as a layout problem

The previous fix reduced title width, direction width, chip padding, and token spacing to make the popover fit. That passed tests but can make the Shortcuts section feel cramped.

Recommended solution:

- Keep current width constraints until after shortcut token weight is reduced.
- After weight reduction, visually re-check whether chip horizontal padding can return from `5` to `6` or `7` without breaking preferred width.
- Do not increase `MenuBarPopoverView.preferredContentSize.width` yet. The popover design contract says text must fit at the preferred width, and the popover should remain compact.
- Add or keep a test that catches fitting width regressions in both light and dark appearances.

Adoption: **Adopt as sequencing rule.** Typography fix first, spacing restoration second, preferred-size expansion last resort.

### Risk 5: Numeric alignment lost explicit monospaced-digit behavior

Pretendard provides the desired family direction, but the implementation removed `monospacedDigitSystemFont`. Apple notes that SF numbers are proportional by default and SF Mono enables row/column alignment. Pretendard's public repo confirms multiple weights and variable fonts, but local evidence is insufficient to prove AppKit tabular number support for the installed font.

Recommended solution:

- Introduce a `numericValue` token separate from `controlValue`.
- First implementation fallback:
  - Keep Pretendard family for numeric text.
  - Keep fixed-width constraints on high-change numeric labels.
  - Use `13 / semibold` for schedule row values and `18 / semibold` for large control values.
- Research/experiment step:
  - Inspect installed Pretendard font descriptors/features locally.
  - If tabular figures are exposed via AppKit/Core Text, add a `numericApp(ofSize:weight:)` helper.
  - If tabular figures are not reliably available, document that numeric stability is layout-constrained rather than font-feature-constrained.

Adoption: **Pilot with local font-feature inspection before adding complex font descriptor code.**

### Risk 6: Pretendard is not bundled, so design output is machine-dependent

The repository currently contains no Pretendard font files. The helper can only use Pretendard when it is installed in the runtime environment.

Recommended solution:

- For local development now:
  - Keep fallback behavior.
  - Document "Pretendard installed" as a visual QA prerequisite.
- For distribution/release:
  - Bundle Pretendard font files in the app and register them through the app bundle if stable typography is required.
  - Do not download or install fonts automatically during this work because package/download actions are restricted by the supply-chain freeze.
- Make this a separate task from weight tuning. Weight tuning can proceed with installed local Pretendard, but release-grade consistency needs bundled font assets.

Adoption: **Adopt as separate release-hardening task.**

### Risk 7: Icon symbol weights are not tied to text token weights

`NSImage.SymbolConfiguration` still uses explicit symbol weights such as `.semibold`. This can become inconsistent if text weights are reduced.

Recommended solution:

- Leave icon weights unchanged in the first typography pass.
- After text weights are adjusted, visually review brightness/warmth icons against labels.
- If icons overpower labels, add semantic icon tokens:
  - `metricIconSmall`: `11 / semibold`
  - `controlIcon`: existing size/weight
- Do not make icon and text weights share the same token blindly, because SF Symbols are designed around their own weight/scale system.

Adoption: **Watch, do not modify first.**

## Do Not Duplicate Or Bypass

- Do not scatter new `.app(ofSize:weight:)` calls when a semantic font token can express the role.
- Do not reintroduce `NSFont.systemFont(...)` or `NSFont.monospacedSystemFont(...)` outside fallback paths.
- Do not use CSS mockup weights literally as AppKit truth; translate them into native role tokens and verify screenshots.
- Do not expand the popover width before checking whether token weights solve the fitting pressure.
- Do not solve release font consistency by installing packages or downloading assets in this workflow.

## Open Questions

- Should Pretendard be a hard product requirement for release, requiring bundled font files?
- Does the locally installed Pretendard expose tabular figures that AppKit can enable reliably?
- Should `controlLabel` remain `13 / semibold`, or should it move closer to the mockup's larger `15px / 700` after shortcut weights are quieted?
- Should `badgeCompact` be `9 / semibold` or match the mockup's smaller `8px` treatment for `ENABLED`?
- Should the app window inherit the same token names immediately, or should the first pass only migrate the popover?

## Plan Implications

Recommended implementation sequence:

1. **Contract update**
   - Add Pretendard typography decision to `docs/design-decisions.md`.
   - Update `DESIGN.md` foundation line from SF/system target to Pretendard target with system fallback.

2. **Token refactor**
   - Add role-specific font tokens to `InnosDesignTokens.Font`.
   - Keep `app(ofSize:weight:)` as primitive helper.
   - Replace popover local one-off fonts with role tokens first.

3. **Shortcut pilot**
   - Apply `shortcutToken = 13 / semibold`.
   - Apply `shortcutSeparator = 9 / medium` or keep size and rely on tertiary color if `.medium` looks too faint.
   - Apply `shortcutOff = 12 / semibold`.
   - Regenerate `actual-dark.png` and `actual-light.png`.

4. **Numeric pilot**
   - Add `numericValue` role token.
   - Keep fixed-width constraints.
   - Inspect Pretendard font-feature support before adding a tabular-number descriptor.

5. **Spacing revisit**
   - Only after the shortcut pilot, decide whether chip padding can return from `5` to `6` or `7`.
   - Keep preferred content width at `428` unless screenshots and tests prove a real need.

6. **Verification**
   - Run `MenuBarStateTests`.
   - Check `rg` for raw system/monospace font calls.
   - Compare screenshots against `mockup-preview.png`, focusing on Shortcuts hierarchy, number stability, and badge balance.

## Source Evaluation

| Source | Type | Quality | Adoption |
| --- | --- | --- | --- |
| `DESIGN.md` | Local active design contract | High | Adopt as source of truth, but update because it conflicts with Pretendard implementation. |
| `docs/design-decisions.md` | Local decision log | High | Adopt as place to record Pretendard decision. |
| `typography-weight/research.md` | Prior local audit | High | Adopt as issue list. |
| `InnosDesignTokens.swift` | Current implementation owner | High | Adopt as token owner. |
| `MenuBarPopoverView.swift` | Target UI surface | High | Adopt as current behavior evidence. |
| `mockup.html` / `mockup-preview.png` | Approved visual proof | Medium-high | Adopt directionally; do not copy CSS literally. |
| `actual-dark.png` | Current rendered implementation | High for visual evidence | Adopt for QA. |
| Apple Fonts page | Official external reference | High | Adopt for system-font context, numeric and mono alignment context, and SF Symbols caveat. |
| Apple Design Resources page | Official external reference | High | Adopt for SF Symbols weight/scale caveat. |
| Pretendard GitHub repository | Primary font project reference | High for availability/weights | Adopt for Pretendard weights/variable-font availability, but not enough to prove local AppKit tabular-number behavior. |

## Evidence

- `DESIGN.md:13-16` currently prefers system typography and San Francisco.
- `docs/design-decisions.md:51-61` records shared control-system language but does not record a typography-family decision.
- `InnosDesignTokens.swift:31-44` defines Pretendard-first font loading with system fallback.
- `MenuBarPopoverView.swift:735-850` defines shortcut title, direction, symbol, separator, and `Off` chip typography.
- `MenuBarPopoverView.swift:1435-1458` defines control label and value typography.
- `MenuBarPopoverView.swift:1494-1506` defines wrapping text and section label typography.
- `find . \\( -iname '*Pretendard*' -o -iname '*.ttf' -o -iname '*.otf' -o -iname '*.woff' -o -iname '*.woff2' \\) -print` returned no bundled font files.
- Apple Fonts page: SF Pro is the Apple platform system font and SF Mono is intended for row/column alignment; it also notes proportional default numbers and system-specific font feature behavior.
- Apple Design Resources page: SF Symbols have weights/scales and align with San Francisco, which means SF Symbol weight should be reviewed separately when the text family is Pretendard.
- Pretendard official GitHub: Pretendard is positioned as a cross-platform system-UI alternative and provides 9 weights plus variable fonts.
- Latest prior verification: `xcodebuild test -project InnosDimmer.xcodeproj -scheme InnosDimmer -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -only-testing:InnosDimmerTests/MenuBarStateTests` passed `39 tests`, `0 failures` after the previous font change.

