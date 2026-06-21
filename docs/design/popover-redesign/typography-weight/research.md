# Research

## Goal

Investigate what is now wrong or risky in the InnosDimmer font design after switching app UI fonts to Pretendard-first loading, with special attention to weight hierarchy and shortcut key symbols such as `⌥`, `⇧`, `↑`, `↓`, `→`, and `←`.

Mode: `research` Purpose Research, using `디자인올인원` foundations/tokens lane, `design-a11y-qa` as a QA lens, and `review-all-in-one`/`review-swarm` as the post-implementation review lens.

## Scope And Entry Points

In scope:

- App typography tokens in `InnosDesignTokens.Font`.
- Popover typography in `MenuBarPopoverView`.
- Shortcut key chip typography and spacing.
- Settings and schedule window font propagation where it affects global font consistency.
- Current design contract and approved popover mockup evidence.
- Existing test and screenshot evidence from the latest font-change pass.

Out of scope:

- Implementing another font-weight change in this research pass.
- Adding or bundling Pretendard font files.
- Changing command routing, schedule behavior, or dimming behavior.
- External benchmark research; this audit is grounded in local design/code/proof evidence.

## Relevant Files

- `/Users/moonsoo/projects/InnosDimmer/DESIGN.md`
- `/Users/moonsoo/projects/InnosDimmer/docs/design-decisions.md`
- `/Users/moonsoo/projects/InnosDimmer/docs/design/popover-redesign/mockup.html`
- `/Users/moonsoo/projects/InnosDimmer/docs/design/popover-redesign/mockup-preview.png`
- `/Users/moonsoo/projects/InnosDimmer/docs/design/popover-redesign/captures/actual-dark.png`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/DesignSystem/InnosDesignTokens.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/MenuBarPopoverView.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/StatusBadgeView.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/ScheduleEditorView.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/SettingsWindowController.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/ScheduleEditorWindowController.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmerTests/MenuBarStateTests.swift`

## Current Behavior

The implementation now routes most explicit AppKit fonts through `InnosDesignTokens.Font.app(ofSize:weight:)`, which tries Pretendard PostScript names first and falls back to AppKit system fonts if Pretendard is unavailable.

Current global font tokens:

| Token | Current value |
| --- | --- |
| `sectionTitle` | `12 / bold` |
| `body` | `13 / regular` |
| `bodyEmphasis` | `13 / semibold` |
| `value` | `18 / bold` |
| `chip` | `12 / semibold` |
| `button` | `13 / semibold` |

Current popover one-off roles include:

| Role | Current value |
| --- | --- |
| Header title | `17 / bold` |
| General wrapping text | `12 / regular` |
| Section title | `12 / semibold` |
| Control title | `13 / semibold` |
| Control value | `18 / semibold` |
| Schedule row value | `13 / bold` |
| Shortcut name | `13 / semibold` |
| Shortcut direction | `12 / semibold` |
| Shortcut token symbols | `13 / bold` |
| Shortcut plus signs | `9 / semibold` |
| `Off` chip | `12 / bold` |
| Compact badge | `9 / semibold` |
| Regular badge | `12 / semibold` |

The approved mockup uses a different hierarchy:

| Mockup role | Mockup CSS |
| --- | --- |
| Header title | `17px / 700` |
| Section title | `12px / 650` |
| Control title | `15px / 700` |
| Control value | `18px / 720` |
| Status title | `13px / 700` |
| Schedule row values | `13px / 650-720` |
| Shortcut name | `13px / 700` |
| Shortcut direction | `12px / 700` |
| Shortcut chip | `13px / 700`, monospace family |
| Shortcut token symbols | `14px / 800` |
| Shortcut plus signs | `10px / 700` |
| Shortcut section compact chip | `8px` |

The actual AppKit capture shows that Pretendard makes the UI feel heavier and wider than the earlier SF/system-weight assumptions. The shortcut code chips still fit after spacing reductions, but they now dominate the Shortcuts row more than the mockup because the symbols are bold, bright, and proportionally spaced.

## Data Flow And Control Flow

- `MenuBarPopoverView.init(...)` builds the view at `MenuBarPopoverView.preferredContentSize`.
- `MenuBarPopoverView.buildLayout()` assigns fonts to popover labels, badges, control rows, action buttons, schedule rows, and shortcut rows.
- `ShortcutSummaryFormatter.groups(from:)` turns shortcut bindings into `Brightness` and `Warmth` summary groups.
- `ShortcutPairRowView` lays out the row title, `Up`/`Down` direction labels, and `ShortcutKeyChipView` instances.
- `ShortcutKeyChipView.buildTokens(from:)` splits key labels into individual symbols and `+` separators, then assigns font per token.
- `InnosDesignTokens.Font.app(...)` decides the font family and concrete PostScript font name for each requested `NSFont.Weight`.

Changing weight tokens affects visible fitting size, not just visual tone. This was already observed empirically: after the Pretendard pass, `testMenuBarPopoverLayoutFitsPreferredContentSizeInLightAndDark` initially failed because fitting width rose to `454` against a `428` preferred width. The later spacing adjustment made tests pass again, but it did not solve the underlying typography contract issue.

## Existing Abstractions And Boundaries

- `InnosDesignTokens.Font` is the correct owner for shared font family, scale, and weight semantics.
- `MenuBarPopoverView` still contains local typography decisions for many roles. This is acceptable for surface-specific composition, but risky for family/weight semantics.
- `ShortcutKeyChipView` owns token-level keycap rendering, including the visual separation between shortcut symbols and `+`.
- `DESIGN.md` is the current design contract source of truth.
- `docs/design-decisions.md` is the decision log source of truth.
- The HTML mockup is review evidence, not the implementation source of truth.
- The latest AppKit PNG captures are implementation evidence, not a design contract.

## Side Effects And Integration Points

- Reducing weights can change intrinsic sizes and may shift fitting width/height; the popover preferred-size tests must remain part of verification.
- Reintroducing monospaced system fonts for shortcut chips would conflict with the user's explicit direction to make app fonts Pretendard.
- Removing monospaced digit fonts means percentage and time numerals may no longer be tabular. This can create subtle alignment jitter when values change, especially `9%` vs `100%` and `09:00` vs `23:00`.
- AppKit `NSImage.SymbolConfiguration` still uses symbol weights such as `.semibold`, so icon weight may not automatically track Pretendard text weight changes.
- The fallback path still uses `NSFont.systemFont` when Pretendard is unavailable. This is technically safe but can produce two different visual systems depending on the user's installed fonts unless Pretendard is bundled.

## Risk To Surrounding Systems

### Important: The design contract contradicts the implementation

`DESIGN.md` still says to use San Francisco via AppKit system fonts, while the code now prefers Pretendard. Future design/dev sync work can legitimately "fix" the UI back toward SF unless a new decision records Pretendard as the current rule.

Risk:

- repeated churn in font decisions
- screenshots/mockups reviewed against one font while app renders another
- future agents treating current Pretendard code as an accidental implementation detail

### Important: Typography roles are too coarse for the number of UI roles

The code has only six shared font tokens, but the popover uses many role-specific sizes and weights. This makes weight tuning ad hoc: `bold` may mean title, numeric value, schedule percentage, shortcut symbol, or `Off` state depending on the local code path.

Risk:

- changing one token can overcorrect unrelated UI
- visual hierarchy stays noisy because many small labels are semibold/bold
- mockup-to-AppKit sync remains manual and fragile

### Important: Pretendard changed width assumptions, but the layout fix was spacing-based

The passing layout after the font change depends partly on tighter shortcut title widths, chip padding, and token spacing. That keeps tests green, but it treats a typography-width problem as a layout compression problem.

Risk:

- localized strings, longer labels, or future shortcut variants can overflow again
- chips may feel cramped while still visually heavy
- width tests pass without proving hierarchy/readability

### Important: Numeric readability lost the explicit monospaced-digit behavior

The previous design token used `NSFont.monospacedDigitSystemFont` for numeric values. The current Pretendard-first version uses proportional `Pretendard` for values. The UI still looks acceptable in the captured default state, but the code no longer guarantees stable digit widths.

Risk:

- percentages can shift as values change
- schedule rows can lose column-like stability
- rapid brightness changes may feel visually jumpy

### Minor: Shortcut key symbols are still too assertive relative to their row labels

The user asked for `⌥ / ⇧ / ↑` to be larger than `+`, and the current rendering satisfies that. However, with Pretendard bold, the symbols now visually compete with `Brightness`, `Warmth`, and the primary action buttons. The code-chip affordance is present, but the keys read more like dominant controls than compact hints.

Risk:

- Shortcuts section becomes a visual endpoint instead of a reference summary
- `Up`/`Down` labels become secondary to heavy key symbols
- the row feels denser than the mockup despite fitting inside the same width

### Minor: Compact badge sizing is not documented as a separate typography role

`ENABLED` uses a compact badge font path (`9 / semibold`), and the mockup indicated an even smaller shortcut-section chip. The implementation now has a compact flag, but this is a component option rather than a documented semantic role.

Risk:

- `MANUAL`, `ENABLED`, and future small chips drift by local flag usage
- future compact chips may be visually inconsistent

## Do Not Duplicate Or Bypass

- Do not bypass `InnosDesignTokens.Font` for font-family decisions.
- Do not reintroduce scattered `NSFont.systemFont(...)` calls outside the token fallback.
- Do not use system monospace fonts for shortcut chips unless the user explicitly relaxes the "all fonts Pretendard" direction.
- Do not solve keycap width by expanding `MenuBarPopoverView.preferredContentSize` before first trying typography and chip role corrections.
- Do not encode font rules only in `mockup.html`; document adopted rules in `DESIGN.md` or `docs/design-decisions.md`.

## Open Questions

- Is Pretendard now the official design contract, or only a local fallback preference when installed?
- Should Pretendard be bundled with the app so the design is stable on machines without the font?
- Does the installed Pretendard build support tabular numeric OpenType features that AppKit can request through `NSFontDescriptor`?
- Should shortcut key symbols be `13 / semibold`, `14 / semibold`, or keep `13 / bold` with lower opacity?
- Should control title text increase toward the mockup's `15px` direction, or should the AppKit implementation keep a denser `13px` native popover scale?

## Plan Implications

Recommended next implementation direction:

1. Update the design contract first.
   - Add a design decision that Pretendard is now the app typography target.
   - Supersede the `DESIGN.md` line that says "Use San Francisco via AppKit system fonts."

2. Split typography tokens by role before changing weights again.
   - Suggested token groups:
     - `appTitle`
     - `sectionLabel`
     - `body`
     - `bodyStrong`
     - `controlLabel`
     - `controlValue`
     - `numericValue`
     - `buttonLabel`
     - `badgeLabel`
     - `badgeCompact`
     - `shortcutName`
     - `shortcutDirection`
     - `shortcutToken`
     - `shortcutSeparator`
     - `shortcutOff`

3. Pilot these weight changes in the popover only:
   - `shortcutToken`: reduce from `13 / bold` to `13 / semibold` first.
   - `shortcutSeparator`: reduce from `9 / semibold` to `9 / medium` or keep current weight but lower opacity.
   - `shortcutOff`: reduce from `12 / bold` to `12 / semibold`.
   - `schedule row values`: consider `13 / semibold` instead of mixed bold roles.
   - `buttonLabel`: keep semibold unless actual capture shows buttons overpowering content after shortcut reduction.

4. Restore stable numeric behavior without abandoning Pretendard.
   - Prefer a Pretendard tabular-number descriptor if supported.
   - If unsupported, document the tradeoff and keep fixed-width constraints for high-change numeric labels.

5. Verify visually and mechanically.
   - Re-run the preferred-size tests.
   - Regenerate `actual-dark.png` and `actual-light.png`.
   - Compare the Shortcuts section against `mockup-preview.png`, focusing on row rhythm, keycap dominance, and numeric alignment.

## Source Evaluation

| Source | Type | Quality | Adoption |
| --- | --- | --- | --- |
| `DESIGN.md` | Local active design contract | High | Adopt, but update because it conflicts with current Pretendard implementation. |
| `docs/design-decisions.md` | Local decision log | High | Adopt; it currently has no typography decision covering Pretendard. |
| `InnosDesignTokens.swift` | Implementation token owner | High | Adopt; this is the correct owner for global font semantics. |
| `MenuBarPopoverView.swift` | Implementation surface | High | Adopt; this is where current weight issues appear. |
| `mockup.html` / `mockup-preview.png` | Approved local design proof | Medium-high | Adopt for visual direction, but translate to native AppKit roles instead of copying CSS literally. |
| `actual-dark.png` | Current rendered implementation evidence | High for visible layout | Adopt for visual QA; it shows the current Pretendard weight balance. |
| External design sources | Not used | N/A | Not needed for this local typography audit. |

## Evidence

- `DESIGN.md:13-16` says to prefer native macOS patterns and system typography and to use San Francisco via AppKit system fonts.
- `docs/design-decisions.md` contains popover and control-system decisions, but no active Pretendard typography decision.
- `InnosDimmer/UI/DesignSystem/InnosDesignTokens.swift:31-44` defines the new Pretendard-first font loader and fallback.
- `InnosDimmer/UI/MenuBarPopoverView.swift:735-754` defines shortcut row title and direction font roles.
- `InnosDimmer/UI/MenuBarPopoverView.swift:758-849` defines key chip padding, spacing, and token font weights.
- `InnosDimmer/UI/MenuBarPopoverView.swift:1380-1505` defines header, control, value, summary, wrapping, and section fonts.
- `docs/design/popover-redesign/mockup.html` includes the approved mockup typography, including shortcut token/separator roles.
- `docs/design/popover-redesign/captures/actual-dark.png` shows the current AppKit rendering after Pretendard changes.
- Command evidence:
  - `rg -n "systemFont|monospacedSystemFont|monospacedDigitSystemFont|NSFont\\.systemFont|NSFont\\.monospaced" InnosDimmer -g'*.swift'`
  - Result: only `InnosDesignTokens.swift:44`, the fallback path.
  - `xcodebuild test -project InnosDimmer.xcodeproj -scheme InnosDimmer -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -only-testing:InnosDimmerTests/MenuBarStateTests`
  - Result from latest font pass: `39 tests`, `0 failures`.
