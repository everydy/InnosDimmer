# Research

## Goal

Document the current popover mockup changes and identify the exact production-code implications needed to carry those changes into the real AppKit menu bar popover.

Mode: `research` / Pre-Plan Research Gate.

Primary question: what changed in `docs/design/popover-redesign/mockup-current.html`, and what must change in `MenuBarPopoverView.swift`, shared design tokens, and tests so the production popover matches the reviewed mockup without bypassing existing command routing?

## Scope And Entry Points

In scope:

- Current-state popover mockup created for feedback: `docs/design/popover-redesign/mockup-current.html`
- Side-by-side review page: `docs/design/popover-redesign/mockup-compare.html`
- Ideal/reference mockup: `docs/design/popover-redesign/mockup.html`
- Production popover implementation: `InnosDimmer/UI/MenuBarPopoverView.swift`
- Shared AppKit design tokens: `InnosDimmer/UI/DesignSystem/InnosDesignTokens.swift`
- Popover state/tests: `InnosDimmerTests/MenuBarStateTests.swift`

Out of scope for this research pass:

- Applying production Swift changes
- Commit packaging
- Reworking app-window pages
- Changing underlying `blueReduction` storage, command names, persistence keys, or shortcut action enum cases

## Relevant Files

- `/Users/moonsoo/projects/InnosDimmer/docs/design/popover-redesign/mockup-current.html`
- `/Users/moonsoo/projects/InnosDimmer/docs/design/popover-redesign/mockup-compare.html`
- `/Users/moonsoo/projects/InnosDimmer/docs/design/popover-redesign/mockup.html`
- `/Users/moonsoo/projects/InnosDimmer/docs/design/popover-redesign/research.md`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/MenuBarPopoverView.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/DesignSystem/InnosDesignTokens.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmerTests/MenuBarStateTests.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmerTests/HotkeyBindingTests.swift`

## Current Behavior

### Production Popover

`MenuBarPopoverView` is already close to the current-state mockup structurally:

- Preferred content size is `428 x 749`.
- Root stack padding is `16`.
- Section spacing is `12`.
- Section internal spacing is `9`.
- Control row layout uses `96` title width, `54` value width, flexible track, and two `34 x 30` step buttons.
- Schedule rows use subtle card containers.
- Shortcut rows use a table-like container with tokenized key chips.
- Quick controls badge already switches `MANUAL` / `AUTO` from `state.automationPausedUntilNextBoundary`.

Production copy and hierarchy still differ from the latest current-state mockup:

- Header `displaySummary` still appends automation paused text when paused.
- Schedule status still renders two lines: `Automation paused until 19:00` and `Next boundary 19:00`.
- Schedule action button still says `Resume automation` / `Pause automation`.
- Control and shortcut visible labels still use `Blue reduction`.
- Shortcut summary formatter still emits `Blue reduction`.
- Tests explicitly assert `Blue reduction`, `Automation paused`, `Next boundary`, and `Resume automation`.

### Current-State Mockup

The current-state review mockup now represents the desired production direction:

- Header display summary is only `27QA100M · software dimming`.
- `MANUAL` / `AUTO` badge is shown in Quick controls and toggles with schedule state.
- Schedule card uses one status line inside the `Schedule` section: `Paused until 19:00`.
- The secondary `Next boundary 19:00` line is removed.
- Schedule action is `Resume schedule` / `Pause schedule`.
- Visible user-facing dimming temperature label is `Warmth`.
- Shortcut group label is `Warmth`.
- Overall font weight is lighter than the current production token set:
  - title around bold / `700`
  - section labels around semibold / `620`
  - control labels, badges, buttons around medium-to-semibold / `600`
  - shortcut direction and time pills around medium / `560`
  - shortcut token around `600`
  - shortcut plus around `450`

## Data Flow And Control Flow

The production popover path is:

1. `MenuBarController` owns runtime side effects and opens the `NSPopover`.
2. `MenuBarController` creates `MenuBarPopoverView` and injects `MenuBarActions`.
3. `MenuBarPopoverView.update(...)` builds `MenuBarViewModel`.
4. `MenuBarViewModel` derives display strings from `BrightnessState`, schedule entries, shortcuts, and diagnostics.
5. `MenuBarPopoverView.update(...)` writes view model strings into labels and button titles.
6. Buttons dispatch `MenuBarCommand` through `MenuBarActions`.

The mockup changes mostly affect step 4 and step 5:

- Header copy belongs in `MenuBarViewModel.displaySummary`.
- Schedule status and action copy belong in `MenuBarViewModel.automationTitle` and `automationActionTitle`.
- Removing the second schedule status line affects `scheduleStatusDetail` and `scheduleStatusStack` rendering.
- `Warmth` visible copy affects `makeControlGroup(...)`, `blueReductionTrackView` accessibility label, `ShortcutSummaryFormatter.groups(from:)`, and `shortcutActionLabel(for:)`.
- Font weight changes affect `InnosDesignTokens.Font` and a few local popover font assignments.

The mockup must not change command routing:

- `MenuBarCommand.blueReductionDown`
- `MenuBarCommand.blueReductionUp`
- `MenuBarCommand.setBlueReduction(Int)`
- `ShortcutAction.blueReductionUp`
- `ShortcutAction.blueReductionDown`

Those names are internal command/data semantics and should remain stable unless a separate migration plan is written.

## Existing Abstractions And Boundaries

- `MenuBarViewModel` owns current popover copy and should remain the source of truth for strings used by `MenuBarPopoverView`.
- `MenuBarPopoverView` owns AppKit layout and button wiring.
- `InnosDesignTokens.Font` owns shared Pretendard font roles.
- `ShortcutSummaryFormatter` owns grouped shortcut display.
- `ScheduleSummaryRowsView` owns schedule row rendering.
- `MenuBarController` owns command side effects and should not be touched for visual/copy-only changes.
- `ShortcutBinding` and `ShortcutAction` own persisted shortcut semantics and legacy decoding. Do not rename enum cases as part of this UI copy pass.

## Side Effects And Integration Points

Likely test impact if the mockup is implemented in production:

- `MenuBarStateTests` assertions for `displaySummary` paused state must change because header should no longer include automation pause text.
- `MenuBarStateTests` assertions for `automationTitle`, `automationActionTitle`, and `scheduleStatusDetail` must change.
- Tests that assert `Blue reduction` is present and `Warmth` is absent must be inverted or rewritten.
- Snapshot/nonblank tests should still pass if geometry stays at `428 x 749`, but text widths change and should be visually rechecked.
- Accessibility labels for `Blue reduction down/up` and `Blue reduction percentage` need a decision: visible `Warmth` copy should probably be reflected as `Warmth down/up` for user-facing accessibility, while internal command names remain `blueReduction`.

Runtime integration points that must be preserved:

- `commandButtons[command]` registration for `.pauseAutomation` and `.resumeAutomation`.
- `commandButtonForTesting(_:)`.
- `brightnessTrackView.onUserFractionChange`.
- `blueReductionTrackView.onUserFractionChange`.
- `scheduleSummaryRowsView.update(schedule:)`.
- `shortcutSummaryRowsView.update(rows:)`.

## Risk To Surrounding Systems

- High: Renaming internal `blueReduction` commands, enum cases, or persisted shortcut keys would risk breaking shortcut persistence and legacy decoding.
- Medium: Removing `scheduleStatusDetailLabel` without updating tests and layout can leave stale spacing or broken `scheduleStatusForTesting()`.
- Medium: Changing font tokens globally can affect app window and schedule editor because `InnosDesignTokens.Font` is shared.
- Medium: Replacing `Automation` with `Schedule` in copy improves this popover but may diverge from other app surfaces that still use automation vocabulary.
- Low: Removing automation paused text from the header is low risk because the state remains visible in the Schedule section and the `MANUAL` badge.

## Do Not Duplicate Or Bypass

- Do not bypass `MenuBarViewModel`; update it instead of hard-coding labels directly in `MenuBarPopoverView.update(...)`.
- Do not bypass `MenuBarCommand` or `MenuBarActions`.
- Do not call `BrightnessController` directly from `MenuBarPopoverView`.
- Do not rename `blueReduction` storage, commands, shortcut enum cases, or persistence fields in this pass.
- Do not duplicate schedule formatting logic outside `ScheduleSummaryRowsView` unless extracting a shared visible-label helper.
- Do not introduce web content into the production popover; the HTML mockups remain review artifacts only.

## Open Questions

- Should the production accessibility labels use `Warmth` everywhere, or keep `Blue reduction` for technical precision? Recommendation: use `Warmth` for user-facing accessibility labels because the visible label is `Warmth`.
- Should other app surfaces also move from `Blue reduction` to `Warmth`, or only the compact menu bar popover? Recommendation: this pass should target only the menu bar popover and follow up with a separate app-wide naming audit.
- Should the schedule section use `Active`, or should the active state card disappear entirely when automatic schedule is active? Current mockup keeps `Active`.
- Should the blue/warmth icon color remain orange everywhere? Current mockup and production both lean orange/thermometer for the warmth control, but the ideal mockup still has blue-oriented styling.
- Should `BlueReductionWarning.message` become `High warmth may shift colors.`? Recommendation: if the visible control label is `Warmth`, the warning should also say `Warmth` when it appears.

## Plan Implications

Recommended implementation order:

1. Add or update tests first for the new popover copy:
   - header display summary excludes automation pause text
   - paused schedule state is `Paused until 19:00`
   - active schedule state is `Active`
   - action button is `Resume schedule` / `Pause schedule`
   - visible shortcut/control labels are `Warmth`
   - shortcut summary no longer contains `Blue reduction`
2. Update `MenuBarViewModel` copy:
   - remove paused automation text from `displaySummary`
   - change `automationTitle` to schedule wording
   - change `automationActionTitle` to schedule wording
   - make `scheduleStatusDetail` empty for configured schedules unless a missing schedule needs `No schedule configured`
3. Update `MenuBarPopoverView.buildLayout()`:
   - hide or remove `scheduleStatusDetailLabel` when empty
   - set schedule status stack spacing so the card does not reserve a second line
   - change the second control title from `Blue reduction` to `Warmth`
   - change track and button accessibility labels to `Warmth ...` if adopting user-facing accessibility copy
4. Update shortcut display helpers:
   - `ShortcutSummaryFormatter.groups(from:)`: title `Warmth`
   - `shortcutActionLabel(for:)`: `Warmth up` / `Warmth down`
   - keep `ShortcutAction.blueReductionUp/down` unchanged
5. Adjust typography carefully:
   - avoid a broad global weight drop unless app-window impacts are reviewed
   - prefer adding popover-specific font aliases if the app window should not change
   - candidate aliases:

```swift
static var popoverTitle: NSFont { app(ofSize: 17, weight: .bold) }
static var popoverSectionLabel: NSFont { app(ofSize: 12, weight: .semibold) }
static var popoverLabel: NSFont { app(ofSize: 13, weight: .semibold) }
static var popoverValue: NSFont { app(ofSize: 18, weight: .bold) }
static var popoverButton: NSFont { app(ofSize: 12, weight: .semibold) }
static var popoverShortcutDirection: NSFont { app(ofSize: 12, weight: .medium) }
static var popoverShortcutToken: NSFont { app(ofSize: 13, weight: .semibold) }
static var popoverShortcutSeparator: NSFont { app(ofSize: 9, weight: .regular) }
```

6. Verify with existing focused tests:

```bash
xcodebuild -project InnosDimmer.xcodeproj -scheme InnosDimmer -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test -only-testing:InnosDimmerTests/MenuBarStateTests -only-testing:InnosDimmerTests/HotkeyBindingTests
```

7. Visually verify the actual AppKit popover or a native snapshot harness against `mockup-current.html`.

## Source Evaluation

No external web sources influenced this research. Evidence is local repository evidence only.

Adoption decision:

- Local production Swift code: Adopt. It is the implementation source of truth.
- Current-state HTML mockup: Adopt as reviewed target for this popover pass.
- Ideal HTML mockup: Watch. It remains a design target, but the user asked specifically to carry the current-state feedback into production.
- Existing `docs/design/popover-redesign/research.md`: Partially superseded. It is useful historical context, but some claims are stale, including older preferred-size and naming recommendations.
- Tests: Adopt. They show exactly which expectations will fail and must be updated intentionally.

## Evidence

Commands run:

```bash
sed -n '1,220p' /Users/moonsoo/projects/codex-skills-user/research/references/research-md-artifact-contract.md
sed -n '1,760p' docs/design/popover-redesign/mockup-current.html
sed -n '1,220p' docs/design/popover-redesign/mockup.html
sed -n '1,190p' InnosDimmer/UI/DesignSystem/InnosDesignTokens.swift
sed -n '1,220p' docs/design/popover-redesign/research.md
sed -n '426,860p' InnosDimmer/UI/MenuBarPopoverView.swift
sed -n '1036,1168p' InnosDimmer/UI/MenuBarPopoverView.swift
sed -n '1223,1455p' InnosDimmer/UI/MenuBarPopoverView.swift
sed -n '1455,1695p' InnosDimmer/UI/MenuBarPopoverView.swift
rg -n "displaySummary|scheduleStatus|shortcutSummary|Blue reduction|Automation paused|Resume automation|Pause automation|Next boundary|Schedule paused|Warmth|shortcutName|Font\\." InnosDimmerTests/MenuBarStateTests.swift InnosDimmerTests/HotkeyBindingTests.swift
```

Confirmed local evidence:

- `MenuBarPopoverView.preferredContentSize` is `NSSize(width: 428, height: 749)`.
- `MenuBarViewModel.quickControlsBadgeTitle` already switches `MANUAL` / `AUTO`.
- `MenuBarViewModel.displaySummary` currently appends automation paused text when paused.
- `MenuBarViewModel.automationTitle` currently says `Automation paused...` / `Automation active`.
- `MenuBarViewModel.automationActionTitle` currently says `Resume automation` / `Pause automation`.
- `MenuBarViewModel.scheduleStatusDetail(...)` currently returns `Next boundary ...` or `Schedule rows below`.
- `ShortcutSummaryFormatter.groups(from:)` currently emits `Blue reduction`.
- `makeControlGroup(...)` currently uses title `Blue reduction` and accessibility labels `Blue reduction ...`.
- `MenuBarStateTests` has many direct expectations for `Blue reduction`, `Automation paused`, `Resume automation`, and `Next boundary`.

Empirical mockup verification already performed during this workstream:

- `mockup-current.html` rendered with Pretendard loaded.
- Current popover mockup width was verified at `428`.
- Shortcut row overflow was verified as false.
- The current mockup body no longer contains `Blue reduction` or `Blue reduc`.
- The current mockup shortcut names rendered as `Brightness` and `Warmth`.

Insufficient evidence:

- The actual native AppKit popover has not yet been visually re-captured after applying these changes because production Swift has not been changed in this research pass.
- App-wide naming consistency for `Warmth` vs `Blue reduction` has not been audited outside the menu bar popover.
