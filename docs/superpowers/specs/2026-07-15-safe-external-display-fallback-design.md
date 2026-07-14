# Safe External Display Fallback Design

## Summary

When the saved display is unavailable, InnosDimmer should inspect the other connected displays before rejecting a dimming command. It may automatically use another display only when exactly one eligible external display is available. It must never select the Mac's main or built-in display as an automatic fallback. When multiple external displays are available, the command remains blocked until the operator chooses a target.

## Goals

- Recover automatically when the saved external display is absent but exactly one other external display is connected.
- Keep automatic fallback deterministic and safe.
- Preserve the saved preferred display so it can be selected again when it reconnects.
- Explain fallback, ambiguity, and no-candidate outcomes in diagnostics.
- Cover the selection policy and command-routing behavior with automated tests.

## Non-Goals

- Automatically dim the Mac's main or built-in display.
- Probe multiple displays by visibly dimming each one.
- Persist an automatically chosen fallback over the operator's saved preference.
- Change Quick disable or Restore lifecycle semantics.
- Add hardware DDC/CI probing.

## User-Visible Behavior

### Saved target is connected

InnosDimmer selects the saved target exactly as it does today. No fallback message is shown.

### Saved target is missing and one other external display is connected

InnosDimmer selects that external display for the current runtime operation and applies the requested brightness/warmth command. Diagnostics record that the saved target was unavailable and name the temporary fallback display.

The stored preference is not overwritten. If the saved display reconnects, subsequent display reconciliation selects it again.

### Saved target is missing and multiple other external displays are connected

InnosDimmer does not guess. It blocks the command and records a diagnostic asking the operator to select a display in the Display page. Candidate names and the candidate count are included when practical.

### No external display is connected

InnosDimmer keeps the current blocked behavior and records that no eligible external display was found. The Mac's main display is not used as a fallback.

### No target was ever saved

Existing automatic-selection behavior remains: use the first eligible external display. If more than one external display exists, this existing behavior is preserved for compatibility; the new ambiguity rule applies specifically to fallback from an unavailable saved target.

## Architecture

### Resolution result

Replace the display resolver's display-or-nil result at the inventory boundary with a small result type that explains the outcome:

- `selected(display, reason)` where the reason distinguishes saved match, automatic selection, and single-external fallback.
- `unavailable(reason)` where the reason distinguishes no external candidate from multiple external fallback candidates.

The pure resolver remains responsible for identity matching. The inventory layer remains responsible for excluding unsafe fallback candidates because it owns the live CoreGraphics display metadata:

- Exclude `mainDisplayID`.
- Exclude every display for which `CGDisplayIsBuiltin(displayID) != 0`, even when the built-in panel is not currently the main display.

For deterministic tests, the static inventory resolution entry point accepts the main display ID and a set of built-in display IDs. The live instance builds that set from the active display IDs through `CGDisplayIsBuiltin` before invoking the pure selection policy.

### Controller integration

`MenuBarController.resolveFreshDisplay` consumes the richer result:

- A saved match follows the current path.
- A single-external fallback updates only the runtime `BrightnessState.display`, records one explicit fallback diagnostic when the selected runtime target changes, and returns the display so the original command can proceed.
- An ambiguous or empty result clears the runtime display, records the appropriate warning, and returns `nil`.

The controller must not call the software-dimming backend while resolution is ambiguous or has no external candidate.

### Reconnect behavior

Wake and screen-parameter reconciliation already call `resolveFreshDisplay`. Because the saved preference is retained, reconnecting the preferred display naturally replaces the temporary fallback during the next reconciliation. Existing stale overlay cleanup remains in front of re-resolution.

## Diagnostics

Suggested messages:

- Fallback selected: `Saved display <saved> is unavailable; using external display <fallback>`
- Multiple candidates: `Saved display <saved> is unavailable; select one of <count> external displays`
- No candidate: retain `No eligible external display found`

The controller should avoid repeating the fallback-selected message when the runtime display has not changed. Existing operation-specific skipped warnings may remain for commands that cannot proceed.

## Data Flow

1. A manual command, schedule boundary, startup, wake, or display-change event requests display resolution.
2. `DisplayInventory` reads all active displays, identifies the main display, and classifies built-in displays through CoreGraphics.
3. The resolver first attempts the saved identity match.
4. If the saved identity is missing, the inventory filters out both the main display and every built-in display.
5. One external candidate becomes a temporary fallback; zero or multiple candidates return a blocked result.
6. `MenuBarController` records the outcome and either applies the original command to the selected display or stops before software dimming.

## Error Handling And Safety

- Main-display and built-in-display exclusion are mandatory for every fallback branch. Built-in classification must not be inferred from main-display status.
- A fallback must still pass through `BrightnessController` and the existing software-dimming strategy; no direct overlay or gamma call is introduced.
- The saved preference must not be mutated by fallback selection.
- Multiple candidates must never be resolved by array order.
- If display inventory returns no candidates, behavior remains non-destructive and diagnostic-only.

## Test Design

### Pure selection tests

- Saved display reconnects with a new CoreGraphics ID and remains preferred.
- Missing saved display plus one external candidate selects the external fallback.
- Missing saved display plus built-in/main display only returns unavailable.
- Missing saved display plus a built-in display that is not the main display still returns unavailable.
- Missing saved display plus two external candidates returns ambiguous.
- Automatic mode with no saved target preserves the current first-external behavior.

### Controller tests

- A brightness command applies to the single fallback external display.
- Fallback application does not overwrite `DisplayTargetStore.selectedDisplay`.
- Diagnostics name the unavailable saved display and chosen fallback.
- Multiple external candidates apply no command and emit a selection warning.
- Main-display-only inventory applies no command.
- Reconciliation prefers the saved display again after it reconnects.

### Verification

- Run the narrow display resolver/store tests.
- Run `MenuBarStateTests` for command integration and diagnostics.
- Run the repository's Debug `build-for-testing` command.
- Manual follow-up: disconnect the preferred monitor while one alternate external display remains, issue a brightness command, reconnect the preferred monitor, and inspect Diagnostics.

## Risks

- Temporarily dimming an unexpected external display may surprise the operator. The exactly-one-candidate rule and diagnostic disclosure limit this risk.
- Display topology can change between inventory and apply. The existing software strategy's display-availability failure remains the final safety boundary.
- Repeated resolution may create noisy diagnostics. Fallback messages should be emitted on target transition rather than every command.

## Implementation Boundaries

- Expected production files: `InnosDimmer/Services/DisplayTargetResolver.swift`, `InnosDimmer/Services/DisplayInventory.swift`, and `InnosDimmer/UI/MenuBarController.swift`.
- Expected test files: `InnosDimmerTests/DisplayTargetStoreTests.swift` and `InnosDimmerTests/MenuBarStateTests.swift`.
- Do not change UI layout, persisted snapshot schema, software-dimming backend behavior, schedule policy, or shortcut bindings.

## Approved Product Decision

The operator approved automatic fallback to exactly one alternate external display, ambiguity blocking for multiple external displays, and exclusion of the Mac's built-in/main display on 2026-07-15.
