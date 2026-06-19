# Research

## Goal

InnosDimmer 프로젝트 전체의 현재 상태, 구조, 동작 경계, 테스트/QA 근거, 다음 계획에 영향을 줄 리스크를 조사한다.

이번 조사는 구현 전 의사결정용 프로젝트 리서치다. 특정 기능 구현은 하지 않았고, 기존 코드와 문서의 근거를 읽어 프로젝트 수준의 research basis를 남긴다.

## Scope And Entry Points

시작점:

- `/Users/moonsoo/projects/InnosDimmer/README.md`
- `/Users/moonsoo/projects/InnosDimmer/research.md`
- `/Users/moonsoo/projects/InnosDimmer/docs/operator-guide.md`
- `/Users/moonsoo/projects/InnosDimmer/docs/qa-matrix.md`
- `/Users/moonsoo/projects/InnosDimmer/docs/release-notes-local.md`
- `/Users/moonsoo/projects/InnosDimmer/docs/design-decisions.md`
- `/Users/moonsoo/projects/InnosDimmer/docs/2026-06-19-overlay-reliability-plan-first.md`
- `/Users/moonsoo/projects/InnosDimmer/docs/2026-06-19-gamma-blue-reduction-plan-first.md`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/App/InnosDimmerApp.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/App/AppDelegate.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/MenuBarController.swift`

조사 lane:

- `codebase`: AppKit app lifecycle, dimming pipeline, display targeting, schedule, hotkeys, persistence, diagnostics, UI, tests.
- `reasoning`: current code/doc evidence에서 다음 계획에 필요한 위험과 경계를 정리.
- `empirical`: 과거 문서화된 build/manual QA 기록만 사용. 이번 턴에서 새 build/test는 실행하지 않았다.

웹/커뮤니티 조사는 하지 않았다. 현재 요청은 로컬 프로젝트 리서치이고, 최신 외부 정보가 필요한 API/정책 판단은 포함하지 않았다.

## Relevant Files

핵심 앱 파일:

- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/App/AppDelegate.swift`: app startup, accessory activation policy, duplicate instance termination, termination cleanup.
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/App/InnosDimmerApp.swift`: `NSApplication` bootstrap.
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/MenuBarController.swift`: runtime coordinator. menu/popover/dashboard/settings, command routing, schedule, hotkeys, display-change/wake reconciliation, diagnostics recording.
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/MenuBarPopoverView.swift`: compact quick-control UI, dark utility popover, brightness/blue-reduction track controls, dashboard window classes.
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/SettingsWindowController.swift`: display selection, schedule, shortcut editing, launch-at-login toggle, diagnostics export save panel.
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/StatusBadgeView.swift`: visible mode labels.

Core domain/services:

- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Domain/BrightnessCommand.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Domain/BrightnessState.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Domain/DimmingMode.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Domain/DisplayIdentity.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Domain/ScheduleEntry.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Domain/SettingsSnapshot.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Domain/ShortcutBinding.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Services/BrightnessController.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Services/SoftwareDimmingController.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Services/OverlayWindowManager.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Services/GammaDimmingController.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Services/DisplayInventory.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Services/DisplayTargetResolver.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Services/DisplayTargetStore.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Services/HotkeyManager.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Services/ScheduleEngine.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Services/LoginItemController.swift`

Diagnostics/QA:

- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Diagnostics/DiagnosticsStore.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Diagnostics/DiagnosticsExporter.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Diagnostics/VerificationMatrix.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmerTests/*.swift`
- `/Users/moonsoo/projects/InnosDimmer/docs/qa-matrix.md`

## Current Behavior

Confirmed current product shape:

- InnosDimmer is a personal native macOS menu bar utility for an external INNOS 27QA100M display connected to an M1 Mac by direct HDMI.
- The app is intentionally not a hardware DDC/CI brightness controller in normal operation.
- The current user-facing dimming model is software-based:
  - brightness is handled by an AppKit overlay panel on the target display;
  - blue reduction is handled by a CoreGraphics gamma table blue-channel scale;
  - the old internal `warmth` field remains in state/schedule/shortcuts for compatibility, while visible copy mostly says `Blue reduction`.
- The repository has no detected package manifests and the README/operator guide state that there are no third-party package dependencies.

Current runtime behavior:

- `InnosDimmerApp.main` creates `NSApplication.shared`, assigns `AppDelegate`, calls `startIfNeeded()`, then runs the app.
- `AppDelegate.startIfNeeded()` terminates other running apps with the same bundle identifier, sets `.accessory` activation policy, creates `MenuBarController`, and starts it.
- `MenuBarController.start()` loads persisted settings, resolves the selected display, applies schedule decision, builds menu bar popover/dashboard/settings surfaces, registers hotkeys, registers wake/display-change observers, schedules the next boundary timer, and opens the app dashboard window.
- `MenuBarController.stop()` clears current software state, unregisters hotkeys, invalidates schedule timer, cancels reconcile task, and removes observers.
- Commands can come from menu controls, popover track controls, hotkeys, schedule, startup restore, and forced diagnostics.
- Manual commands pause automation until the next schedule boundary; schedule commands should not become manual overrides.

Current QA state from docs:

- Debug `build-for-testing` and Release build were previously documented as passing on 2026-06-19 after reliability/gamma work.
- Focused gamma/brightness/menu/schedule tests were documented as passing in the gamma plan.
- Full manual QA remains incomplete for full-screen Spaces, presentation mode, browser full-screen video, DRM/protected playback, screen sharing/recording, sleep/wake, HDMI reconnect, browser/full-screen shortcuts, shortcut conflict recovery, and schedule boundary behavior.
- `docs/qa-matrix.md` explicitly forbids claiming all requested contexts are handled until every row is filled with concrete notes.

## Data Flow And Control Flow

Main command flow:

```text
User input / hotkey / schedule
  -> MenuBarController.perform / applyScheduleDecision
  -> MenuBarController.makeCommand
  -> DisplayInventory + DisplayTargetStore + DisplayTargetResolver
  -> BrightnessCommand
  -> BrightnessController.apply
  -> SoftwareDimmingController.apply
  -> GammaDimmingController.apply(display, blueReduction: command.warmth)
  -> OverlayWindowManager.apply(display, brightness: command.brightness, warmth: 0)
  -> DiagnosticsStore + popover/dashboard refresh
```

Display targeting flow:

```text
UserDefaults SettingsSnapshot
  -> DisplayTargetStore.load()
  -> DisplayInventory.activeDisplays()
  -> DisplayTargetResolver.resolve(saved:candidates:)
  -> BrightnessController.state.display
  -> BrightnessCommand.display
```

Runtime boundary flow:

```text
NSWorkspace.didWakeNotification
NSWorkspace.screensDidWakeNotification
NSApplication.didChangeScreenParametersNotification
  -> MenuBarController.scheduleRuntimeBoundaryReconcile()
  -> debounce Task sleep 250 ms
  -> clear stale overlay panels and gamma baselines
  -> resolve fresh display
  -> reapply current software state
  -> apply schedule decision
  -> schedule next boundary timer
```

Persistence flow:

```text
SettingsWindowController actions
  -> DisplayTargetStore.saveSelectedDisplay / saveSchedule / saveShortcuts
  -> SettingsSnapshot validation
  -> UserDefaults JSON blob at "InnosDimmer.SettingsSnapshot"
```

Diagnostics flow:

```text
MenuBarController.record(...)
  -> DiagnosticsStore events ring buffer
  -> popover latest diagnostic summary
  -> dashboard recent diagnostics
  -> Settings exportDiagnostics
  -> DiagnosticsExporter JSON
  -> NSSavePanel
```

## Existing Abstractions And Boundaries

Strong boundaries:

- `BrightnessController` owns applied brightness state, active mode, failed software-dimming attempts, reapply, and clear-current behavior.
- `SoftwareDimmingController` is the strategy boundary for software dimming. It currently coordinates gamma blue reduction and overlay brightness.
- `OverlayWindowManager` owns AppKit overlay panel creation, frame lookup, click-through/all-Spaces settings, layer update, and stale panel cleanup.
- `GammaDimmingController` owns CoreGraphics gamma table capacity/read/set, original table storage, blue-channel scaling, and restore.
- `DisplayInventory`, `DisplayTargetResolver`, and `DisplayTargetStore` separate active display enumeration, matching logic, and persisted selection.
- `ScheduleEngine` is pure scheduling logic; `ScheduleTimerController` owns Timer scheduling.
- `HotkeyManager` owns validation and Carbon registration backend details.
- `SettingsSnapshot` is the persistence schema boundary; current schema version is 2.
- `DiagnosticsStore` and `DiagnosticsExporter` keep diagnostics data separate from UI.
- `VerificationMatrix` is the guardrail for product claims across requested contexts.

Boundaries that need extra care:

- `SoftwareDimmingController.apply` applies gamma before overlay. If gamma apply fails, brightness overlay is not attempted. This couples blue-reduction failure to brightness-dimming failure.
- If overlay apply fails after gamma succeeds, the controller tries to clear gamma and then throws. This protects against partially applied blue reduction, but clear failure is swallowed with `try?`.
- `BrightnessController.applySoftware` sets `activeMode = .overlay` after any successful software apply, even if gamma blue reduction was also applied. The `.gamma` mode exists and has UI copy, but normal combined gamma+overlay success is represented as overlay.
- The public UI has mostly moved to `Blue reduction`, but several internal names remain `warmth`. That is acceptable for compatibility if documented, but it increases copy/state confusion risk.
- `AppDelegate.startIfNeeded()` terminates other running instances with the same bundle identifier. That prevents duplicate overlay/gamma controllers, but it is a launch side effect that matters during local QA.
- `MenuBarController.start()` shows the app dashboard window immediately. This is a product behavior, not just a menu bar background utility behavior.

## Side Effects And Integration Points

Important side effects:

- Overlay panels are `NSPanel` windows at `.screenSaver` level, click-through, non-opaque, no shadow, can join all Spaces, stationary, ignore window cycling, and full-screen auxiliary.
- Gamma blue reduction mutates display transfer tables through CoreGraphics and stores original tables in memory for restore.
- App termination attempts to restore current software state through `MenuBarController.stop()` and `BrightnessController.clearCurrentSoftwareState()`.
- Force quit, crash, OS display profile changes, Night Shift interactions, and external monitor reconnects can affect gamma recovery differently than overlay recovery.
- Hotkeys use Carbon `RegisterEventHotKey`; unsafe or duplicate enabled bindings are rejected before registration.
- Launch-at-login uses `SMAppService` on macOS 13+ and reports unsupported on older systems.
- Diagnostics export writes JSON via `NSSavePanel`; tests verify the encoded snapshot does not include obvious local path strings.
- UserDefaults persistence stores selected display, state, schedule, and shortcuts as JSON.

External/manual integration points:

- Actual target environment is the user's M1 Mac + HDMI external INNOS 27QA100M.
- Full-screen Spaces, Stage Manager-like behavior, protected video, screen sharing/recording, sleep/wake, HDMI reconnect, and shortcut focus behavior are not fully provable by unit tests.
- README build commands use Xcode directly:
  - `xcodebuild -scheme InnosDimmer -configuration Debug build-for-testing CODE_SIGNING_ALLOWED=NO`
  - `xcodebuild -scheme InnosDimmer -configuration Release build CODE_SIGNING_ALLOWED=NO`

## Risk To Surrounding Systems

High-value risks:

- Gamma failure currently blocks overlay brightness. If blue reduction fails because of gamma table read/write, a brightness-only command may also fail. Decide whether this is desired fail-closed behavior or whether overlay brightness should degrade gracefully while surfacing a blue-reduction warning.
- Gamma restore is best-effort in some paths. If restore fails during app quit, display reconnect, or overlay failure cleanup, the visible display color state may remain changed until OS/profile/display reset.
- Mode labeling may under-report combined behavior. `activeMode = .overlay` is used after successful gamma+overlay software apply, while `.gamma` remains a possible label but is not the normal combined-success state.
- Documentation and UI terminology are not fully synchronized. README still mentions warmth in several places, while operator guide, release notes, current UI, and gamma plan describe blue reduction.
- Broad manual QA is still the limiting evidence for release-like claims. Unit tests cover many contracts, but cannot prove protected playback, screen sharing, full-screen Spaces, or actual HDMI reconnect behavior.
- Immediate dashboard opening at startup may be inconvenient for a menu bar utility if the desired behavior is background-only startup.
- Terminating duplicate app instances by bundle identifier can interrupt a manually running local build during QA.

Medium risks:

- Internal `warmth` naming is now compatibility debt. A mechanical rename would be risky because it touches persistence, tests, schedule, shortcuts, and legacy decode.
- `SettingsSnapshot` migration relies on decode compatibility and validation. Invalid persisted shortcuts or empty schedules fall back to default snapshot, which is safe but may discard user settings.
- Design capture artifacts are currently untracked in the worktree. They appear unrelated to this research, but dirty state must be protected before any commit/packaging workflow.

## Do Not Duplicate Or Bypass

Future work should not bypass these existing paths:

- Do not apply dimming directly from UI views. Route through `MenuBarController -> BrightnessController -> SoftwareDimmingController`.
- Do not create a second display-selection path. Reuse `DisplayInventory`, `DisplayTargetResolver`, and `DisplayTargetStore`.
- Do not write schedule logic in UI. Reuse `ScheduleEngine` and `ScheduleTimerController`.
- Do not register hotkeys directly from Settings or popover. Reuse `HotkeyManager` and its validation.
- Do not write diagnostics JSON directly from UI. Reuse `DiagnosticsStore.snapshot` and `DiagnosticsExporter.export`.
- Do not claim all scenarios are handled without `VerificationMatrix.canClaimAllRequestedContextsHandled` and `docs/qa-matrix.md` notes.
- Do not reintroduce DDC/CI hardware brightness as the normal runtime path unless the product direction changes explicitly.
- Do not rename `warmth` persistence fields casually. Treat visible `Blue reduction` copy and internal `warmth` storage as a compatibility boundary unless a migration plan exists.

## Open Questions

- Should gamma blue-reduction failure block brightness overlay, or should brightness still apply while diagnostics/UI report blue-reduction failure?
- Should `.gamma` mode remain a future/diagnostic state, or should the mode model represent combined `overlay + gamma` success more explicitly?
- Should startup open the dashboard window automatically, or should the app remain menu-bar-only until the user opens it?
- Does the user's actual INNOS 27QA100M setup reliably restore gamma after sleep/wake, HDMI reconnect, app quit, and crash/force quit?
- Does overlay dimming remain visible in full-screen Spaces, browser full-screen video, DRM/protected playback, and screen sharing/recording?
- Should README be updated to fully align with the post-gamma `Blue reduction` terminology?

## Plan Implications

Recommended next planning lanes:

1. Stabilize gamma/overlay failure semantics.
   - Decide whether brightness overlay should degrade independently from gamma blue reduction.
   - If decoupling is desired, add a diagnostics state for blue-reduction warning without losing brightness overlay.

2. Align product vocabulary.
   - Keep internal `warmth` field for schema compatibility.
   - Update user-facing docs and any visible copy to consistently say `Blue reduction`.

3. Add or update manual QA evidence.
   - Use `docs/qa-matrix.md` as the canonical manual checklist.
   - Do not mark scenario rows as handled without concrete display/app/surface notes.

4. Review startup behavior.
   - Decide whether automatic dashboard opening is intentional.
   - If this should be a silent menu bar utility, plan a behavior change with tests.

5. Treat test runner reliability separately from product behavior.
   - Existing docs report `xcodebuild test` launch/finalization stalls or dylib denial in some runs.
   - Keep `build-for-testing` as compiler gate, but isolate full XCTest runner issues before treating them as app regressions.

## Evidence

Commands run on 2026-06-19 from `/Users/moonsoo/projects/InnosDimmer`:

- `git status --short`
  - Result before this research artifact: worktree had untracked design capture PNGs under `docs/design/popover-redesign/captures/`.
- `find docs -maxdepth 3 -type f | sort`
- `find InnosDimmer -maxdepth 3 -type f | sort`
- `find InnosDimmerTests -maxdepth 3 -type f | sort`
- `find . -maxdepth 2 -name Package.swift -o -name package.json -o -name pyproject.toml -o -name requirements.txt -o -name Gemfile`
  - Result: no package manifest files found.
- `rg -c "func test" InnosDimmerTests/*.swift`
  - Result: 103 test functions across 12 test files.
- Targeted `sed`/`rg` reads of files listed in `Relevant Files`.

Confirmed by files:

- README project purpose and no dependency policy: `/Users/moonsoo/projects/InnosDimmer/README.md`
- Operator policy and QA notes: `/Users/moonsoo/projects/InnosDimmer/docs/operator-guide.md`
- Manual QA gate: `/Users/moonsoo/projects/InnosDimmer/docs/qa-matrix.md`
- Release status: `/Users/moonsoo/projects/InnosDimmer/docs/release-notes-local.md`
- Existing software-dimming research: `/Users/moonsoo/projects/InnosDimmer/research.md`
- Overlay reliability plan: `/Users/moonsoo/projects/InnosDimmer/docs/2026-06-19-overlay-reliability-plan-first.md`
- Gamma blue reduction plan: `/Users/moonsoo/projects/InnosDimmer/docs/2026-06-19-gamma-blue-reduction-plan-first.md`
- Current command coordinator: `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/MenuBarController.swift`
- Software strategy implementation: `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Services/SoftwareDimmingController.swift`
- Gamma implementation: `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Services/GammaDimmingController.swift`
- Overlay implementation: `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Services/OverlayWindowManager.swift`
- State/persistence/schema: `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Domain/SettingsSnapshot.swift`
- Tests and coverage count: `/Users/moonsoo/projects/InnosDimmer/InnosDimmerTests`

Insufficient evidence:

- No new `xcodebuild` build or test command was run in this turn.
- No live app launch, visual overlay check, gamma restore check, sleep/wake check, HDMI reconnect check, or full-screen/protected-media QA was performed in this turn.
- No external Apple documentation was re-browsed for this project-level pass; previous root research already contains Apple API links for overlay/window/gamma-related APIs.
