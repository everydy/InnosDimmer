# Research

## Goal

Explain the repeated diagnostics warnings in the supplied InnosDimmer log, determine the safe display-fallback behavior, and establish the AppKit lifecycle contract required for normal `Command-Q` termination.

## Scope And Entry Points

- Supplied diagnostics excerpt from 2026-07-15.
- Menu-bar command routing for Quick disable, Restore previous, manual dimming, and schedule application.
- Display resolution and runtime screen-change reconciliation.
- Application entry, activation policy, main-menu setup, and termination cleanup.
- Existing unit tests and operator documentation for the same paths.

## Relevant Files

- `InnosDimmer/UI/MenuBarController.swift`
- `InnosDimmer/Domain/ShortcutBinding.swift`
- `InnosDimmer/App/AppDelegate.swift`
- `InnosDimmer/App/InnosDimmerApp.swift`
- `InnosDimmer/Services/DisplayInventory.swift`
- `InnosDimmer/Services/DisplayTargetResolver.swift`
- `InnosDimmer/Services/ScheduleEngine.swift`
- `InnosDimmerTests/MenuBarStateTests.swift`
- `InnosDimmerTests/HotkeyBindingTests.swift`
- `InnosDimmerTests/SoftwareDimmingControllerTests.swift`
- `InnosDimmerTests/SmokeTests.swift`
- `docs/request-refiner-artifacts/2026-07-15-094631-refined-request.md`
- `docs/superpowers/specs/2026-07-15-safe-external-display-fallback-design.md`
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
7. When a saved display has stable hardware identity and no active candidate matches it, `DisplayTargetResolver.resolve` returns `nil`; `DisplayInventory` does not currently consider a different external fallback in that branch.
8. `DisplayInventory` currently excludes only `CGMainDisplayID()` when no target is saved. It does not yet classify built-in displays independently with `CGDisplayIsBuiltin`.
9. InnosDimmer runs as an `LSUIElement` accessory app and creates no `NSApplication.mainMenu`. Therefore no standard Quit menu item currently owns the `Command-Q` key equivalent.
10. `AppDelegate.applicationWillTerminate` already calls `MenuBarController.stop()`, which clears the current software state and unregisters runtime resources. A standard `NSApplication.terminate(_:)` action can reuse this cleanup path.
11. Quick disable currently resolves the display twice and caches the previous command before the disable apply succeeds. A topology change or backend failure can therefore produce a snapshot for a different or unsuccessfully disabled display.
12. Restore currently applies the display-specific cached command directly. It does not re-resolve the active target, so reconnect or topology changes can apply to a stale fallback display.
13. Runtime reconciliation clears only displays absent from the active-display list. When a fallback and the reconnected saved target are both active, the old fallback overlay is not stale by that definition and can remain dimmed.
14. Only the Command Line Tools toolchain is installed (`xcode-select -p` reports `/Library/Developer/CommandLineTools`); `xcodebuild` cannot run until full Xcode is installed and selected.

The supplied log matches these branches exactly. It repeatedly shows missing-display resolution followed by skipped manual or schedule commands. The Restore warning occurs separately after Restore commands are received without an available saved Quick disable command.

The later reliability request is a bounded behavior extension rather than evidence of a backend dimming failure: one eligible alternate external display may be used temporarily, but ambiguous or unsafe candidates must remain blocked. The quit request is caused by a missing AppKit menu command, not by the existing termination cleanup implementation.

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

The safe contract is stricter than the current sequence: Quick disable must resolve once, apply once, and cache only after successful disable. Restore must retain only the brightness/warmth values from that snapshot, resolve the current target again, replace the stale display identity, and clear the snapshot only after a successful restore.

### Saved-target fallback

Manual/scheduled/reconciliation request -> `MenuBarController.resolveFreshDisplay` -> `DisplayInventoryProviding.resolveSelectedDisplay` -> `DisplayInventory.resolveSelectedDisplay` -> `DisplayTargetResolver.resolve`.

The current optional result cannot explain whether selection was a saved match, automatic selection, single-external fallback, no eligible candidate, or multi-external ambiguity. A typed resolution outcome at the inventory boundary is the smallest way to preserve selection ownership while giving `MenuBarController` enough context for actionable diagnostics.

### Command-Q termination

`InnosDimmerApp.main` -> configure `NSApplication.shared` -> retain `AppDelegate` -> start controller -> `NSApplication.run()`.

The missing step is construction of `NSApplication.mainMenu` with an application submenu containing `Quit InnosDimmer`, action `NSApplication.terminate(_:)`, key equivalent `q`, and modifier mask `.command`. Normal termination then enters `AppDelegate.applicationWillTerminate` and the existing controller cleanup. A process whose main event loop is completely frozen cannot process the key event and still requires macOS Force Quit.

## Existing Abstractions And Boundaries

- `DisplayInventoryProviding` and `DisplayTargetStore` own active-display discovery and selected-target persistence.
- `MenuBarController` owns command routing, schedule coordination, the in-memory Quick disable snapshot, and diagnostics emission.
- `BrightnessController` and the software-dimming strategy own actual overlay/gamma application; the supplied warnings occur before that backend is invoked.
- `BrightnessController.clearCurrentSoftwareState()` clears only the controller's current display. A bounded explicit-display cleanup seam is required to remove an old fallback after a successful target transition without bypassing the brightness boundary.
- `ScheduleEngine` decides schedule state but does not resolve displays or emit the supplied display warnings.
- `DisplayTargetResolver` owns saved-identity matching; `DisplayInventory` owns live topology facts such as main and built-in display classification.
- `NSApplication.mainMenu` owns standard app command key equivalents; Carbon hotkey registration must remain limited to the existing user-configurable dimming shortcuts.

## Side Effects And Integration Points

- Changing missing-display handling can affect startup diagnostics, screen reconnect behavior, manual controls, schedule application, and the visible latest-diagnostic status.
- Persisting the Quick disable snapshot would introduce restoration across app launches and must handle stale display identities safely.
- Removing warnings without replacement could hide a genuinely disconnected or incorrectly selected target display.

## Risk To Surrounding Systems

- Treating Restore as a generic reset would change its documented meaning and could apply an unintended brightness/warmth state.
- Reusing a stale saved command after monitor reconnect could target an outdated display identity unless it is re-resolved through the existing display layer.
- Suppressing all missing-display warnings would reduce operator visibility into schedule and reconnect failures.
- Selecting a fallback using only `candidate.cgDisplayID != mainDisplayID` can still target a built-in panel when the built-in panel is not currently main.
- Applying a new target without clearing an earlier fallback can leave two monitors dimmed. Clearing the old fallback before the new apply would create the opposite regression if the new apply fails, so transition order must be apply-new-then-clear-old.
- Registering `Command-Q` as a global Carbon hotkey would intercept a system-standard shortcut outside the normal active-app command path and create avoidable conflicts.

## Do Not Duplicate Or Bypass

- Do not bypass `resolveFreshDisplay` when applying a restored command.
- Do not resolve Quick disable twice or clear its snapshot before the restore apply succeeds.
- Do not clear an old fallback before the replacement command succeeds; preserve the usable previous state on replacement failure.
- Do not apply directly through the software-dimming strategy from Restore or schedule code.
- Do not add a second persisted display-selection or brightness-state store; extend `DisplayTargetStore`/`SettingsSnapshot` only if cross-launch Restore is explicitly chosen.
- Do not move live main/built-in topology classification into `DisplayTargetResolver`; keep it at the inventory boundary.
- Do not implement Quit through `HotkeyManager`; install a standard AppKit menu item and reuse `NSApplication.terminate(_:)`.

## Open Questions

- Was the INNOS external monitor physically connected and visible to macOS during the logged periods?
- Was Restore invoked intentionally by the UI/global shortcut, or could Option+Shift+R have been pressed repeatedly?
- Should Restore work only after a successful Quick disable in the current app session (current documented behavior), or should it survive relaunch/reconnect?
- Resolved on 2026-07-15: when a saved target is unavailable, automatically use exactly one alternate external display; block and request selection when multiple external candidates exist; never automatically fall back to the built-in/main display.
- Resolved by the refined request: add a standard active-app `Command-Q` Quit command; full event-loop hangs remain outside the guarantee and require Force Quit.

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

### Option 4: Typed display resolution plus a standard AppKit Quit menu (selected)

- Operating principle: return a resolution outcome that distinguishes a saved match, normal automatic selection, single safe fallback, no candidate, and ambiguity; install Quit in `NSApplication.mainMenu` and target `NSApplication.terminate(_:)`.
- Supporting evidence: the controller needs outcome context for diagnostics, while inventory already owns main-display filtering; local SDK headers expose `CGDisplayIsBuiltin`, `NSApplication.mainMenu`, `NSApplication.terminate:`, and `NSMenuItem.keyEquivalentModifierMask`.
- Fit conditions: exactly one alternate external display may be used temporarily; standard active-app termination is required without changing global shortcut ownership.
- Failure modes: topology can change between resolve and apply; a fully frozen event loop cannot process `Command-Q`.
- Implementation implication: introduce a small typed result at the inventory boundary, inject main/built-in IDs into deterministic tests, preserve the saved snapshot, and add an idempotent minimal application menu during startup.
- Additional transition implication: centralize explicit software cleanup in `BrightnessController`; after a successful target change clear the old overlay, and when resolution becomes unavailable clear the tracked fallback before dropping runtime ownership. If cleanup fails, retain enough ownership to retry during termination.

### Option 5: Keep optional display resolution and infer fallback in the controller

- Operating principle: compare saved/current/resolved optional values in `MenuBarController` and add menu setup independently.
- Supporting evidence: fewer signature changes are initially required.
- Fit conditions: only selected/not-selected behavior matters.
- Failure modes: cannot reliably distinguish no candidate from ambiguous candidates, duplicates topology policy in the controller, and weakens diagnostic precision.
- Implementation implication: rejected because it bypasses the existing ownership boundary and makes multi-display safety harder to test.

### Option 6: Add a visible Quit control or global hotkey instead of an AppKit main menu

- Operating principle: expose termination through the popover/window or Carbon hotkey registration.
- Supporting evidence: either can trigger termination in some contexts.
- Fit conditions: a visible Quit control is separately desired, or the app has no active-app command surface.
- Failure modes: does not satisfy standard `Command-Q` semantics cleanly; a global shortcut can conflict system-wide; UI work expands scope.
- Implementation implication: rejected for this task. A visible Quit button may be considered later but is not required for the requested keyboard behavior.

## Plan Implications

The local evidence explains the warnings and supports a two-commit implementation: first add typed safe display resolution, single-resolution Quick disable/Restore, and explicit cleanup of abandoned fallback dimming; then add a minimal standard AppKit Quit menu and smoke tests. Preserve the saved target, exclude both main and built-in displays, refuse every ambiguous multi-external selection (including the no-saved state), and reuse the existing termination cleanup. Cross-launch Restore persistence and visible Quit UI remain outside this change.

## Source Evaluation

Only local source code, tests, documentation, git history, supplied diagnostics, and headers from the installed macOS SDK were used. No changing external fact or third-party practice affects this diagnosis. External breadth was intentionally narrowed because the display warnings are project-defined literals and the quit behavior is defined by the local AppKit/CoreGraphics SDK contracts.

## Evidence

- `rg -n -S "Restore previous requested without saved state|No eligible external display found|Skipped dimming command because no display is selected|Skipped schedule because no display is selected" .`
- `nl -ba InnosDimmer/UI/MenuBarController.swift | sed -n '40,910p'`
- `rg -n "perform\\(\\.restorePrevious\\)|restorePreviousDimming|applyScheduleDecision|resolveFreshDisplay" InnosDimmer InnosDimmerTests`
- `git blame -L 250,300 -- InnosDimmer/UI/MenuBarController.swift`
- `rg -n "DisplayInventoryProviding|resolveSelectedDisplay|CGDisplayIsBuiltin|mainMenu|terminate:" InnosDimmer InnosDimmerTests <macOS SDK>`
- Installed SDK evidence: `NSApplication.h` declares `terminate:` and `mainMenu`; `NSMenuItem.h` declares key equivalents and modifier masks; `CGDisplayConfiguration.h` declares `CGDisplayIsBuiltin`.
- Diagnostics evidence date: 2026-07-15 (Asia/Seoul session date).
- Confirmed: each message is emitted by a local guard before software dimming can run.
- Confirmed: the current app creates no main menu, while normal termination cleanup already exists.
- Confirmed: Quick disable resolves twice and Restore bypasses fresh resolution.
- Confirmed: reconciliation does not clear a still-connected fallback after the saved target reconnects.
- Confirmed: full Xcode is not installed or selected, so XCTest and build-for-testing cannot be executed in the current environment.
- Repeated observation: missing-display and skipped-operation warnings occur in clusters matching one manual or scheduled operation.
- Inference: repeated Restore warnings require repeated Restore command delivery, but the supplied log alone cannot identify whether the source was UI, hotkey, or user input repetition.
