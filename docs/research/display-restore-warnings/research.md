# Research

## Goal

Explain the repeated diagnostics warnings in the supplied InnosDimmer log and determine whether they prove a software-dimming defect that should be changed in code.

## Scope And Entry Points

- Supplied diagnostics excerpt from 2026-07-15.
- Menu-bar command routing for Quick disable, Restore previous, manual dimming, and schedule application.
- Display resolution and runtime screen-change reconciliation.
- Existing unit tests and operator documentation for the same paths.

## Relevant Files

- `InnosDimmer/UI/MenuBarController.swift`
- `InnosDimmer/Domain/ShortcutBinding.swift`
- `InnosDimmer/App/AppDelegate.swift`
- `InnosDimmer/Services/ScheduleEngine.swift`
- `InnosDimmerTests/MenuBarStateTests.swift`
- `InnosDimmerTests/HotkeyBindingTests.swift`
- `README.md`
- `DESIGN.md`
- `docs/operator-guide.md`
- User-supplied diagnostics: `/Users/moonsoo/.codex/attachments/f829a1dd-cd10-47e9-b8d2-d5a387027acf/pasted-text.txt`

## Current Behavior

1. The app resolves an eligible external display at startup, before each manual dimming command, during schedule application, and after relevant wake/display notifications.
2. When no external display is eligible, resolution records `No eligible external display found`.
3. A manual dimming attempt then also records `Skipped dimming command because no display is selected`.
4. A schedule attempt adds `Skipped schedule because no display is selected` after the command cannot be constructed.
5. Quick disable stores its previous command only if `makeCommand` can resolve a display. It then attempts the disable command through the same display-resolution path.
6. Restore previous records `Restore previous requested without saved state` when the in-memory Quick disable command is absent.

The supplied log matches these branches exactly. It repeatedly shows missing-display resolution followed by skipped manual or schedule commands. The Restore warning occurs separately after Restore commands are received without an available saved Quick disable command.

## Data Flow And Control Flow

### Manual dimming

`MenuBarActions` or a global hotkey -> `MenuBarController.perform` -> `apply` -> `makeCommand` -> `resolveFreshDisplay`.

If display resolution fails, `resolveFreshDisplay` records the missing-display warning and `makeCommand` records the skipped-command warning before returning `nil`.

### Schedule

Startup, timer boundary, resume, or runtime reconciliation -> `applyScheduleDecision` -> `applyScheduledEntry` -> `makeCommand` -> `resolveFreshDisplay`.

If display resolution fails, the same two display warnings are followed by the schedule-specific skipped warning.

### Quick disable and restore

Quick disable -> `quickDisable` -> attempt to create and cache `commandBeforeQuickDisable` -> apply 100% brightness and 0% blue reduction.

Restore -> `restorePrevious` -> guard on `commandBeforeQuickDisable` -> apply the cached command once and clear it. There is no timer, schedule, startup, wake, or reconnect path that calls Restore automatically.

## Existing Abstractions And Boundaries

- `DisplayInventoryProviding` and `DisplayTargetStore` own active-display discovery and selected-target persistence.
- `MenuBarController` owns command routing, schedule coordination, the in-memory Quick disable snapshot, and diagnostics emission.
- `BrightnessController` and the software-dimming strategy own actual overlay/gamma application; the supplied warnings occur before that backend is invoked.
- `ScheduleEngine` decides schedule state but does not resolve displays or emit the supplied display warnings.

## Side Effects And Integration Points

- Changing missing-display handling can affect startup diagnostics, screen reconnect behavior, manual controls, schedule application, and the visible latest-diagnostic status.
- Persisting the Quick disable snapshot would introduce restoration across app launches and must handle stale display identities safely.
- Removing warnings without replacement could hide a genuinely disconnected or incorrectly selected target display.

## Risk To Surrounding Systems

- Treating Restore as a generic reset would change its documented meaning and could apply an unintended brightness/warmth state.
- Reusing a stale saved command after monitor reconnect could target an outdated display identity unless it is re-resolved through the existing display layer.
- Suppressing all missing-display warnings would reduce operator visibility into schedule and reconnect failures.

## Do Not Duplicate Or Bypass

- Do not bypass `resolveFreshDisplay` when applying a restored command.
- Do not apply directly through the software-dimming strategy from Restore or schedule code.
- Do not add a second persisted display-selection or brightness-state store; extend `DisplayTargetStore`/`SettingsSnapshot` only if cross-launch Restore is explicitly chosen.

## Open Questions

- Was the INNOS external monitor physically connected and visible to macOS during the logged periods?
- Was Restore invoked intentionally by the UI/global shortcut, or could Option+Shift+R have been pressed repeatedly?
- Should Restore work only after a successful Quick disable in the current app session (current documented behavior), or should it survive relaunch/reconnect?
- Resolved on 2026-07-15: when a saved target is unavailable, automatically use exactly one alternate external display; block and request selection when multiple external candidates exist; never automatically fall back to the built-in/main display.

## Solution Options

### Option 1: Operator recovery with no code change

- Operating principle: restore the required preconditions—connect/select the eligible external display, execute Quick disable successfully, then execute Restore once.
- Supporting evidence: every supplied display warning maps to a failed display-resolution guard; Restore has no autonomous call site.
- Fit conditions: the monitor was disconnected, powered off, not exposed to macOS, or Restore was invoked without a prior successful Quick disable.
- Failure modes: does not help if macOS sees the monitor but the resolver rejects it, or if cross-launch Restore is desired.
- Implementation implication: none; verify with a fresh diagnostics export after reconnect/select/Quick disable/Restore.

### Option 2: Coalesce expected missing-display diagnostics

- Operating principle: retain the actionable warning but avoid emitting multiple warnings for one failed operation or repeated unchanged absence.
- Supporting evidence: one schedule failure currently emits up to three related warnings; repeated resolve calls emit the same warning without a state transition.
- Fit conditions: behavior is correct but diagnostics noise obscures useful events.
- Failure modes: over-aggressive deduplication could hide a new failure context or delay visible feedback.
- Implementation implication: centralize failure reporting at the operation boundary or record only display availability transitions, with tests for manual, schedule, startup, and reconnect paths.

### Option 3: Persist and safely re-resolve the Quick disable snapshot

- Operating principle: store the pre-disable brightness/warmth values independently of transient display IDs, then resolve the current eligible target before Restore.
- Supporting evidence: `commandBeforeQuickDisable` is currently memory-only and unavailable after relaunch; the project already persists settings through `DisplayTargetStore`.
- Fit conditions: product intent requires Restore to survive relaunch or reconnect.
- Failure modes: stale snapshots, surprising restoration after a long delay, and ambiguity about when the saved state should expire.
- Implementation implication: define lifecycle/expiry semantics, extend the existing settings snapshot, and add relaunch/reconnect tests before implementation.

## Plan Implications

The local evidence explains the warnings, and the operator has now selected a behavior change: safe automatic fallback to exactly one alternate external display. The implementation should preserve the saved target, exclude the main display, refuse ambiguous multi-external selection, and log the chosen fallback. Cross-launch Restore persistence remains outside this change.

## Source Evaluation

Only local source code, tests, documentation, git history, and the supplied diagnostics were used. No changing external fact or third-party practice affects this diagnosis. External breadth was intentionally narrowed because the warnings are project-defined literals with complete local call paths.

## Evidence

- `rg -n -S "Restore previous requested without saved state|No eligible external display found|Skipped dimming command because no display is selected|Skipped schedule because no display is selected" .`
- `nl -ba InnosDimmer/UI/MenuBarController.swift | sed -n '40,910p'`
- `rg -n "perform\\(\\.restorePrevious\\)|restorePreviousDimming|applyScheduleDecision|resolveFreshDisplay" InnosDimmer InnosDimmerTests`
- `git blame -L 250,300 -- InnosDimmer/UI/MenuBarController.swift`
- Diagnostics evidence date: 2026-07-15 (Asia/Seoul session date).
- Confirmed: each message is emitted by a local guard before software dimming can run.
- Repeated observation: missing-display and skipped-operation warnings occur in clusters matching one manual or scheduled operation.
- Inference: repeated Restore warnings require repeated Restore command delivery, but the supplied log alone cannot identify whether the source was UI, hotkey, or user input repetition.
