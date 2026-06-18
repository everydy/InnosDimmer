# Research

## Goal

Finish the current InnosDimmer macOS menu bar app from its present "running shell plus tested service pieces" state into a personally usable external-monitor dimming utility for:

- macOS only.
- M1 Mac.
- Direct HDMI.
- INNOS 27QA100M secondary display.
- Hardware brightness first where empirically verified.
- Software perceived dimming when hardware control is exhausted or explicitly forced for diagnostics.
- Time-table automation, customizable global shortcuts, warmth/color adjustment, diagnostics, and manual QA evidence.

This research is a pre-plan hypothesis ladder. It is not an implementation patch. Its purpose is to define the method choices, ranked hypotheses, failure tests, and next attempts before writing the next `plan-first-implementation` document.

## Scope And Entry Points

Starting mode: `Pre-Plan Research Gate`.

Evidence lanes used:

- `codebase`: current InnosDimmer source, tests, docs, and git history.
- `official`: Apple documentation/search snippets for AppKit windows, Quartz Display Services, Timer, ServiceManagement, screen-change and wake notifications.
- `community`: MonitorControl, Lunar, ddcctl, and GitHub discussions around Apple Silicon HDMI DDC/CI behavior.
- `reasoning`: ranked implementation hypotheses and failure chains based on the current architecture.

Primary app entry points:

- `InnosDimmer/App/InnosDimmerApp.swift`
- `InnosDimmer/App/AppDelegate.swift`
- `InnosDimmer/UI/MenuBarController.swift`
- `InnosDimmer/UI/MenuBarPopoverView.swift`
- `InnosDimmer/UI/SettingsWindowController.swift`

Primary policy/services:

- `InnosDimmer/Services/BrightnessController.swift`
- `InnosDimmer/Services/SoftwareDimmingController.swift`
- `InnosDimmer/Services/OverlayWindowManager.swift`
- `InnosDimmer/Services/HardwareDDCController.swift`
- `InnosDimmer/Services/ScheduleEngine.swift`
- `InnosDimmer/Services/HotkeyManager.swift`
- `InnosDimmer/Services/DisplayInventory.swift`
- `InnosDimmer/Services/DisplayTargetStore.swift`
- `InnosDimmer/Services/LoginItemController.swift`

## Relevant Files

Files read in this pass:

- `/Users/moonsoo/projects/InnosDimmer/README.md`
- `/Users/moonsoo/projects/InnosDimmer/docs/operator-guide.md`
- `/Users/moonsoo/projects/InnosDimmer/docs/release-notes-local.md`
- `/Users/moonsoo/projects/InnosDimmer/docs/qa-matrix.md`
- `/Users/moonsoo/projects/InnosDimmer/docs/ddc-probe-notes.md`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/App/InnosDimmerApp.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/App/AppDelegate.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/App/Info.plist`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/MenuBarController.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/MenuBarPopoverView.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/UI/SettingsWindowController.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Services/BrightnessController.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Services/SoftwareDimmingController.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Services/OverlayWindowManager.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Services/GammaDimmingController.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Services/HardwareDDCController.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Services/ScheduleEngine.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Services/HotkeyManager.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Services/DisplayInventory.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Services/DisplayTargetStore.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Services/DisplayTargetResolver.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Services/LoginItemController.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Diagnostics/DiagnosticsStore.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Diagnostics/DiagnosticsExporter.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Diagnostics/VerificationMatrix.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Domain/BrightnessState.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Domain/ScheduleEntry.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmer/Domain/ShortcutBinding.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmerTests/SmokeTests.swift`
- `/Users/moonsoo/projects/InnosDimmer/InnosDimmerTests/SoftwareDimmingControllerTests.swift`
- `/Users/moonsoo/projects/Chat-Bot/docs/superpowers/plans/2026-06-18-external-monitor-brightness-app-plan.md`

Official and external sources used:

- Apple Developer Documentation: `SMAppService`, `loginItem(identifier:)`, Quartz Display Services, Core Graphics display functions, `NSWindow.CollectionBehavior`, `NSWindow.Level.screenSaver`, `Timer`, `NSApplication.didChangeScreenParametersNotification`, `NSWorkspace.didWakeNotification`, `NSWorkspace.activeSpaceDidChangeNotification`.
- Apple Energy Efficiency Guide for Mac Apps: timer usage and tolerance.
- MonitorControl GitHub README and discussions.
- Lunar M1 DDC writeup.
- ddcctl GitHub README.

## Current Behavior

Confirmed current state:

- The app builds and tests under Xcode after Swift 6 `@MainActor` fixes.
- The app can launch as an `LSUIElement=true` menu bar utility.
- The menu bar icon opens a popover.
- The popover displays labels and buttons, but button actions are currently `nil`.
- `SettingsWindowController` exists but is mostly a static summary view.
- `BrightnessController` owns hardware-vs-software policy and queues commands while hardware state is `.notProbed`, `.probing`, or `.readSupported`.
- `SoftwareDimmingController` can invoke `OverlayWindowManager`, but production activation is blocked until policy chooses software mode or diagnostics force it.
- `OverlayWindowManager` creates click-through `NSPanel` overlays but currently configures new panels with `.zero` frame and never repositions them to the target display frame at apply time.
- `HardwareDDCController` implements a safe read -> one-step write -> readback -> restore probe state machine, but its default `NoopDDCAdapter` always fails. Real IOKit DDC transport is not implemented.
- `ScheduleEngine` is pure and tested, but no runtime timer calls it.
- `HotkeyManager` can validate and register Carbon hotkeys, but no app startup code instantiates it or maps actions to brightness commands.
- `DisplayInventory` can enumerate active displays and prefer the first non-main display.
- `DisplayTargetStore` persists `SettingsSnapshot` in `UserDefaults`, but the app lifecycle does not yet load, apply, or save live changes.
- `DiagnosticsStore`, `DiagnosticsExporter`, and `VerificationMatrix` exist, but the UI does not yet record runtime events or expose export.

## Data Flow And Control Flow

Current intended flow:

1. `InnosDimmerApp.main()` creates `NSApplication`, assigns `AppDelegate`, and runs the app.
2. `AppDelegate.applicationDidFinishLaunching` sets `.accessory`, creates `MenuBarController`, and starts it.
3. `MenuBarController.start()` creates the `NSStatusItem`, configures `NSPopover`, and installs `MenuBarPopoverView`.
4. `MenuBarPopoverView` renders `BrightnessState`, default schedule text, default shortcut summary, and diagnostic summary.
5. No user command currently leaves the view, because all buttons are created with `target: nil, action: nil`.

Current service flow when called by tests or future runtime code:

1. A caller builds a `BrightnessCommand`.
2. `BrightnessController.apply(_:)` checks forced software mode, then hardware capability.
3. If hardware is verified, `HardwareBrightnessStrategy.applyHardware(_:)` is attempted.
4. If hardware fails or capability is exhausted, `SoftwareDimmingStrategy.apply(_:reason:)` is attempted.
5. `SoftwareDimmingController` delegates to `OverlayWindowManager`.
6. `OverlayWindowManager` updates black and warm overlay layers and shows the panel.

Missing runtime flow:

- App lifecycle does not yet select a display.
- App lifecycle does not yet load `SettingsSnapshot`.
- App lifecycle does not yet probe DDC.
- UI controls do not send commands.
- Schedule engine is not driven by a timer.
- Hotkeys are not started.
- Diagnostics are not recorded/exported from real runtime events.
- Overlay frames are not refreshed on display/screen/Space changes.

## Existing Abstractions And Boundaries

Boundaries to preserve:

- `BrightnessController` is the policy boundary. UI, hotkeys, and schedule should not call DDC or overlay directly.
- `HardwareDDCController` is the hardware safety boundary. Real DDC transport should enter through `DDCAdapter`, not by rewriting routing policy.
- `SoftwareDimmingController` is the software perceived-dimming boundary. Overlay and gamma variants should remain behind this strategy.
- `DisplayTargetStore` is the persistence boundary for settings snapshots.
- `DisplayInventory` and `DisplayTargetResolver` own display enumeration and identity resolution.
- `ScheduleEngine` is pure scheduling logic. Runtime timer code should be outside it.
- `HotkeyManager` owns validation and registration. UI should update `ShortcutBinding` values, not duplicate validation.
- `DiagnosticsStore` and `VerificationMatrix` own evidence and claim safety.
- `@MainActor` on UI/dimming policy must be respected because AppKit windows and menu bar objects are main-thread/UI state.

## Side Effects And Integration Points

Side effects:

- Hardware DDC writes can change real monitor settings; probe must stay reversible and readback-gated.
- Software overlay can obscure the user's screen; it must stay click-through and easy to disable.
- Global hotkeys affect system-wide input and can conflict with apps; validation and recovery defaults are required.
- Login item registration changes user launch behavior; it should remain explicit and reversible.
- Timer/automation can unexpectedly change brightness; manual override must pause until the next schedule boundary.
- Screen/Space/wake/reconnect events can leave overlays on the wrong display or stale display identity if not handled.
- Diagnostics export writes local JSON; it should avoid sensitive user content.

Integration points:

- AppKit: status item, popover, panels, settings window, screen/Space/wake notifications.
- CoreGraphics/NSScreen: display inventory and frames.
- Carbon: global hotkey registration.
- ServiceManagement: login item status/register/unregister.
- IOKit/private-ish display paths: possible DDC adapter implementation.
- UserDefaults: settings persistence.
- Local filesystem: diagnostics export and QA notes.

## Risk To Surrounding Systems

High risks:

- Bypassing `BrightnessController` would make software fallback activate before hardware exhaustion, violating the project policy.
- Implementing real DDC directly in UI would make it hard to test and unsafe to recover from failed restore.
- Reusing GPL code from `ddcctl` inside this app would contaminate licensing for a personal project unless explicitly accepted. Use as conceptual reference only.
- Copying MonitorControl/Lunar internals is out of scope and unnecessary for the first runtime-completion pass.
- Using a repeating per-second schedule timer would waste energy and fight the schedule engine's boundary model.
- Overlay windows may not cover some full-screen/DRM/protected contexts. This must become `partial` or `platformBlocked`, not hidden success.
- Native brightness/media key interception may require Accessibility/Input Monitoring permissions. The current MVP should keep custom shortcuts first.
- Display identity can change after sleep/reconnect; silently picking a different display would be dangerous.

## Do Not Duplicate Or Bypass

Do not duplicate:

- `BrightnessController.apply(_:)`
- `HardwareDDCController.probe(display:)`
- `HardwareDDCController.reversibleProbeValue(current:range:)`
- `ScheduleEngine.decision(at:entries:state:)`
- `ScheduleEngine.stateAfterManualOverride(from:at:entries:)`
- `ScheduleEngine.stateAfterApplying(_:to:)`
- `HotkeyManager.validate(_:)`
- `DisplayTargetResolver.resolve(saved:candidates:)`
- `DisplayTargetStore.load()` / `save(_:)`
- `DiagnosticsStore.snapshot(...)`
- `VerificationMatrix.canClaimAllRequestedContextsHandled(_:)`

Do not bypass:

- Hardware write/readback/restore probe before enabling `.hardwareDDC`.
- Main actor for AppKit overlay/menu paths.
- Shortcut safety validation.
- Manual QA matrix before claiming coverage across all requested contexts.
- User-controlled setting for login item.

## Method Hypotheses

### Overall Completion Strategy

#### H1: Runtime-Orchestrator-First Completion

Hypothesis:

The lowest-risk path is to keep all existing domain/services and add a thin main-actor runtime orchestration layer that wires menu UI, selected display, settings, software dimming, schedule timer, hotkeys, diagnostics, and settings window together. Real DDC transport remains behind `DDCAdapter` and can be completed after software dimming and command routing are usable.

Why H1 ranks first:

- It matches the current architecture: most business logic already exists as testable services.
- It avoids touching hardware until the app has a visible status, diagnostics, and safe software disable path.
- It fixes the user's immediate gap: the menu bar app currently opens but does not do anything.
- It preserves the rule that software fallback activation only happens after hardware exhaustion, while still allowing explicit forced software testing.
- It can be verified without changing monitor firmware or needing third-party dependencies.

Success test:

- Menu buttons and hotkeys visibly change perceived brightness/warmth on the selected external display in forced software test mode.
- Runtime state and popover labels update after each command.
- Schedule automation can apply the default timetable.
- Manual changes pause automation until the next boundary.
- Xcode build/test pass.
- QA matrix has concrete manual notes for general desktop, full-screen Space, shortcut, schedule boundary, sleep/wake, and HDMI reconnect.

Failure conditions:

- Overlay does not appear on the selected external display.
- Overlay steals focus/clicks.
- State updates but UI does not refresh.
- Timer fires too often or overwrites manual changes.
- Hotkeys register but action handler is not called.
- Display reconnect moves overlay to the wrong display.

Next hypotheses if H1 fails:

- H2: Split the orchestration into `AppCoordinator`, `DimmingCommandController`, and `MenuBarController` instead of extending `MenuBarController`.
- H3: Replace the static `NSView` popover with a small `NSViewController` that owns callbacks and refreshes, keeping layout AppKit-native.
- H4: Use a `NotificationCenter`/observer state propagation model only if direct callback refresh becomes tangled.

#### H2: DDC-First Completion

Hypothesis:

Implement real DDC/CI transport before UI wiring so the app can become hardware-first immediately.

Why H2 is lower priority:

- It touches the highest-risk area first.
- M1 direct HDMI DDC has conflicting community evidence.
- The app currently lacks enough visible diagnostics/recovery UI to safely expose hardware failures.
- It does not solve the current "menu bar buttons do nothing" issue.

Use H2 only if:

- The user explicitly prioritizes hardware DDC before perceived dimming.
- We first add diagnostics/probe UI and a no-op safety mode.

#### H3: Software-Only Product Completion

Hypothesis:

Ship a robust overlay/gamma dimmer and postpone hardware DDC indefinitely.

Why H3 is lower priority:

- The project requirement is hardware-first where possible.
- It would be honest and useful, but incomplete against the requested hardware path.

Use H3 if:

- Real DDC is blocked on M1 HDMI or INNOS firmware after repeated probe attempts.
- The overlay passes the user's practical contexts and diagnostics clearly says `Overlay active`.

### Runtime Wiring Hypotheses

#### H1: Extend `MenuBarController` With Injected Runtime Services

Hypothesis:

For the next implementation slice, extend `MenuBarController` to own:

- `DisplayInventory`
- `DisplayTargetStore`
- `BrightnessController`
- `HardwareDDCController`
- `HotkeyManager`
- `DiagnosticsStore`
- `SettingsWindowController`
- `Timer?` or dispatch timer wrapper
- current `SettingsSnapshot`
- current selected `DisplayIdentity`

Why H1 ranks first:

- The current app is small.
- It keeps the visible command source and state refresh in one main-actor object.
- It minimizes new abstraction before behavior exists.
- It is easy to unit test with injected doubles.

Failure conditions:

- `MenuBarController` becomes too large or hard to test.
- Test setup needs too many injected dependencies.
- Schedule/hotkey/display notification code becomes tangled with UI layout.

Next hypotheses:

- H2: Extract `AppCoordinator` as the owner of services and let `MenuBarController` only render and forward actions.
- H3: Extract `DimmingCommandRouter` for commands only, while `MenuBarController` keeps status item/popover.

H1 code snippet pack:

```swift
@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let brightnessController: BrightnessController
    private let displayInventory: DisplayInventory
    private let settingsStore: DisplayTargetStore
    private let hardwareController: HardwareDDCController
    private let diagnosticsStore: DiagnosticsStore
    private var hotkeyManager: HotkeyManager?
    private var settings = SettingsSnapshot.defaultSnapshot()
    private var selectedDisplay: DisplayIdentity?
    private weak var popoverView: MenuBarPopoverView?

    init(
        statusItem: NSStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength),
        brightnessController: BrightnessController = BrightnessController(),
        displayInventory: DisplayInventory = DisplayInventory(),
        settingsStore: DisplayTargetStore = DisplayTargetStore(),
        hardwareController: HardwareDDCController = HardwareDDCController(),
        diagnosticsStore: DiagnosticsStore = DiagnosticsStore()
    ) {
        self.statusItem = statusItem
        self.brightnessController = brightnessController
        self.displayInventory = displayInventory
        self.settingsStore = settingsStore
        self.hardwareController = hardwareController
        self.diagnosticsStore = diagnosticsStore
        super.init()
    }
}
```

```swift
func start() {
    settings = settingsStore.load()
    refreshSelectedDisplay()
    configureStatusItem()
    configurePopover()
    registerHotkeys()
    observeDisplayLifecycle()
    applyStartupScheduleIfReady()
    scheduleNextBoundaryTimer()
}
```

### Menu Button And UI Action Hypotheses

#### H1: Make `MenuBarPopoverView` Callback-Based

Hypothesis:

Keep `MenuBarPopoverView` as AppKit `NSView`, but give it callbacks for commands:

- `onBrightnessUp`
- `onBrightnessDown`
- `onWarmthUp`
- `onWarmthDown`
- `onProbe`
- `onPauseAutomation`
- `onSettings`
- `onQuickDisable`
- `onRestore`

Why H1 ranks first:

- It requires the fewest structural changes.
- It keeps UI layout separate from app policy.
- It lets tests instantiate the view and verify buttons have actions.

Failure conditions:

- Callback memory cycles or selector bridging becomes awkward.
- Buttons need enabled/disabled state and richer binding than callbacks provide.

Next hypotheses:

- H2: Introduce `MenuBarPopoverViewController` with target/action methods.
- H3: Use SwiftUI for the popover content only, keeping AppKit app shell.

H1 code snippet pack:

```swift
struct MenuBarActions {
    var brightnessDown: () -> Void
    var brightnessUp: () -> Void
    var warmthDown: () -> Void
    var warmthUp: () -> Void
    var probeDDC: () -> Void
    var pauseAutomation: () -> Void
    var openSettings: () -> Void
}
```

```swift
final class MenuBarPopoverView: NSView {
    private let actions: MenuBarActions

    init(state: BrightnessState, actions: MenuBarActions) {
        self.actions = actions
        self.modeBadge = StatusBadgeView(mode: state.activeMode)
        super.init(frame: NSRect(x: 0, y: 0, width: 320, height: 260))
        buildLayout()
        update(state: state)
    }

    @objc private func brightnessUpPressed() {
        actions.brightnessUp()
    }
}
```

### Command Semantics Hypotheses

#### H1: Fixed Step Commands With Clamping

Hypothesis:

Use fixed increments for menu buttons and hotkeys:

- Brightness: `+/- 5`
- Warmth: `+/- 5`
- Quick disable overlay: clear software dimming and mark mode/status visibly.
- Restore previous dimming: reapply last non-disabled brightness/warmth.

Why H1 ranks first:

- Simple and predictable.
- Existing `Clamped.percent` and `BrightnessState` already bound values.
- Easy to test.

Failure conditions:

- User wants smoother control.
- Hardware DDC monitor reacts slowly or with visible flicker.

Next hypotheses:

- H2: Use `+/- 2` for warmth and `+/- 5` for brightness.
- H3: Add press-and-hold repeat only after the single-step path is stable.
- H4: Add sliders in the popover after button/hotkey command routing is reliable.

H1 code snippet pack:

```swift
private enum DimmingStep {
    static let brightness = 5
    static let warmth = 5
}

private func adjust(brightnessDelta: Int = 0, warmthDelta: Int = 0, source: BrightnessCommandSource) {
    guard let display = selectedDisplay else {
        record(.display, "No selected display", .warning)
        return
    }

    let command = BrightnessCommand(
        display: display,
        brightness: brightnessController.state.targetBrightness + brightnessDelta,
        warmth: brightnessController.state.targetWarmth + warmthDelta,
        source: source
    )

    brightnessController.apply(command)
    pauseAutomationForManualOverrideIfNeeded(source: source)
    persistCurrentState()
    refreshPopover()
}
```

### Software Dimming Hypotheses

#### H1: Fix Per-Display Overlay Frame And Use It As The First Usable Runtime Path

Hypothesis:

Before DDC work, make overlay dimming visually correct:

- Look up the selected display's current `NSScreen.frame`.
- Set the panel frame on every apply, not only at creation.
- Include `.fullScreenAuxiliary` in addition to `.canJoinAllSpaces`, `.stationary`, `.ignoresCycle`.
- Keep `ignoresMouseEvents = true`, transparent background, no shadow.
- Rebuild/reapply on screen parameter, active Space, wake, and HDMI reconnect notifications.

Why H1 ranks first:

- Overlay is the lowest-risk way to give the user working perceived dimming now.
- It does not write monitor firmware.
- It is already partially implemented and tested.
- Community tools also use software/shade/gamma paths when DDC is unavailable.

Failure conditions:

- Overlay does not appear in full-screen Spaces.
- Overlay appears on the wrong display after reconnect.
- Overlay is captured in screen sharing when the user expects local-only dimming.
- DRM/protected playback ignores/overrides/blocks visible dimming.

Next hypotheses:

- H2: Add `.canJoinAllApplications` where available and test whether it improves Stage Manager/full-screen contexts.
- H3: Use a separate overlay panel per `NSScreen` plus selected-display filter after reconnect.
- H4: Add gamma dimming as a separate optional strategy for contexts where overlay is not suitable.
- H5: Mark the scenario `platformBlocked` with visible app status if macOS prevents a requested context.

H1 code snippet pack:

```swift
func apply(display: DisplayIdentity, brightness: Int, warmth: Int) {
    guard let screen = screen(for: display) else {
        return
    }

    let panel = panelsByDisplayID[display.cgDisplayID] ?? makePanel()
    panelsByDisplayID[display.cgDisplayID] = panel
    Self.configureOverlayPanel(panel, for: screen.frame)

    let appearance = OverlayAppearance.make(brightness: brightness, warmth: warmth)
    updateLayers(for: panel, appearance: appearance)
    panel.contentView?.frame = NSRect(origin: .zero, size: screen.frame.size)
    panel.contentView?.layer?.sublayers?.forEach { $0.frame = panel.contentView?.bounds ?? .zero }
    panel.orderFrontRegardless()
}
```

```swift
static func configureOverlayPanel(_ panel: NSPanel, for frame: CGRect) {
    panel.setFrame(frame, display: true)
    panel.level = .screenSaver
    panel.collectionBehavior = [
        .canJoinAllSpaces,
        .fullScreenAuxiliary,
        .stationary,
        .ignoresCycle
    ]
    panel.ignoresMouseEvents = true
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
}
```

### Hardware DDC Hypotheses

#### H1: Keep Real DDC Behind `DDCAdapter` And Implement Probe UI Before Transport

Hypothesis:

The next hardware step is not raw IOKit writes first. It is a probe button that calls `HardwareDDCController.probe(display:)`, records the result, updates `BrightnessState.hardwareCapability`, and persists diagnostics. Initially it will fail with `NoopDDCAdapter`, which verifies UI/status flow safely.

Why H1 ranks first:

- It exercises all safety and diagnostics paths before hardware writes.
- It lets the app show honest state: DDC not implemented/unsupported.
- It protects against accidental brightness changes.

Failure conditions:

- User expects hardware probe to actually change brightness immediately.

Next hypotheses:

- H2: Add a clearly labeled `Real DDC experimental probe` mode after the safe probe UI exists.

#### H2: Implement Native IOKit/I2C DDC Adapter

Hypothesis:

Add `IOKitDDCAdapter: DDCAdapter` using IOKit display/framebuffer/I2C access to send VCP code `0x10` brightness commands, then reuse the existing read/write/readback/restore policy.

Why H2 is second:

- It is the only route to real monitor backlight control inside this app.
- It is high variance on Apple Silicon and direct HDMI.
- Official Apple display APIs expose display enumeration and window-server control, but they do not provide a simple public "set external monitor VCP brightness" API.

Failure conditions:

- IOKit framebuffer path is inaccessible on M1 HDMI.
- Read succeeds but write fails.
- Write succeeds but readback mismatches.
- Restore fails.
- INNOS firmware exposes DDC/CI inconsistently.

Next hypotheses:

- H3: Probe multiple candidate services/paths for the display, keyed by `CGDirectDisplayID`, vendor/model/serial, and IORegistry metadata.
- H4: Separate read-only capability from write capability and keep software dimming for write failure.
- H5: Document hardware as unsupported for this connection and rely on overlay/gamma.
- H6: Optional later external-helper route only if the user explicitly accepts a helper tool or dependency review. Do not use `ddcctl` code directly because of GPL and maintenance risks.

Community observations supporting caution:

- MonitorControl lists DDC, gamma, shade/software, and combined hardware/software dimming as separate protocols and explicitly supports software alternatives for TVs/virtual displays.
- MonitorControl maintainer comments in a 2023 discussion say MonitorControl does not support the HDMI port of M1 Macs and points to BetterDisplay for all connection types.
- Lunar's M1 writeup describes old Intel `IOFramebuffer`/`IOI2C*` assumptions breaking on M1 and requiring Apple-Silicon-specific work.
- `ddcctl` is a useful conceptual reference but is maintenance-mode and GPLv3.

### Schedule Automation Hypotheses

#### H1: One-Shot Boundary Timer, Not Polling

Hypothesis:

Use the existing `ScheduleEngine.minutesUntilNextBoundary` to schedule one timer for the next boundary, apply the decision, then schedule the next one. Also evaluate once at app startup and after wake/reconnect.

Why H1 ranks first:

- It matches the schedule engine's boundary model.
- It minimizes energy use.
- Apple energy guidance recommends avoiding unnecessary timers, invalidating timers, and using tolerance.

Failure conditions:

- Timer misses due to sleep/wake.
- Manual override is cleared too early or too late.
- System clock/time zone changes are not handled.

Next hypotheses:

- H2: Re-evaluate on `NSWorkspace.didWakeNotification` and `NSApplication.didChangeScreenParametersNotification`.
- H3: Add a low-frequency safety reconciliation timer, e.g. every 5-15 minutes, only if event-driven boundary timers prove unreliable.
- H4: Add date/time-change notifications if manual tests show clock changes break schedule state.

H1 code snippet pack:

```swift
private func scheduleNextBoundaryTimer() {
    scheduleTimer?.invalidate()

    let minute = currentMinuteOfDay()
    guard let minutes = ScheduleEngine.minutesUntilNextBoundary(after: minute, entries: settings.schedule) else {
        return
    }

    let interval = TimeInterval(max(1, minutes) * 60)
    let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
        Task { @MainActor in
            self?.applyScheduleDecision(reason: .schedule)
            self?.scheduleNextBoundaryTimer()
        }
    }
    timer.tolerance = min(60, interval * 0.1)
    scheduleTimer = timer
}
```

### Global Shortcut Hypotheses

#### H1: Custom Carbon Hotkeys Only

Hypothesis:

Use the existing `HotkeyManager` and default `Option + Shift + Arrow/0/R` shortcuts. Do not intercept native brightness/media keys in the MVP.

Why H1 ranks first:

- The code already implements validation and Carbon registration.
- It avoids Accessibility/Input Monitoring permission prompts for media-key interception.
- It matches `docs/operator-guide.md`.

Failure conditions:

- Hotkeys do not fire in full-screen apps.
- A user's existing apps conflict with the defaults.
- Carbon registration returns nonzero status.

Next hypotheses:

- H2: Add settings UI to change bindings and persist them.
- H3: Add conflict recovery: disable failing binding, keep others, show diagnostics.
- H4: Only later consider event taps/native media keys if the user explicitly wants F1/F2-style keys and accepts permissions.

H1 code snippet pack:

```swift
private func registerHotkeys() {
    hotkeyManager = HotkeyManager { [weak self] action in
        Task { @MainActor in
            self?.handleShortcut(action)
        }
    }

    do {
        try hotkeyManager?.start(bindings: settings.shortcuts)
        record(.shortcut, "Registered \(settings.shortcuts.filter(\.isEnabled).count) shortcuts", .info)
    } catch {
        record(.shortcut, "Shortcut registration failed: \(error)", .warning)
    }
}
```

```swift
private func handleShortcut(_ action: ShortcutAction) {
    switch action {
    case .brightnessUp:
        adjust(brightnessDelta: DimmingStep.brightness, source: .hotkey)
    case .brightnessDown:
        adjust(brightnessDelta: -DimmingStep.brightness, source: .hotkey)
    case .warmthUp:
        adjust(warmthDelta: DimmingStep.warmth, source: .hotkey)
    case .warmthDown:
        adjust(warmthDelta: -DimmingStep.warmth, source: .hotkey)
    case .quickDisableOverlay:
        clearSoftwareDimming()
    case .restorePreviousDimming:
        restorePreviousDimming()
    }
}
```

### Settings Hypotheses

#### H1: Incremental AppKit Settings Window

Hypothesis:

Upgrade `SettingsWindowController` incrementally:

- Display picker.
- Schedule table or simple editable fields.
- Shortcut list with reset defaults.
- Launch at login toggle.
- Diagnostics export button.
- QA matrix summary.

Why H1 ranks first:

- Existing class is AppKit.
- No new framework complexity.
- Personal-use MVP can start with compact controls.

Failure conditions:

- AppKit manual layout becomes slow to evolve.
- Shortcut capture UI becomes too custom.

Next hypotheses:

- H2: Use SwiftUI only for Settings, embedded in `NSHostingController`.
- H3: Postpone rich settings editing and store defaults until core dimming is verified.

### Diagnostics And QA Hypotheses

#### H1: Diagnostics-First Runtime Evidence

Hypothesis:

Every meaningful runtime event should record diagnostics:

- app start
- selected display
- probe start/result
- hardware failure
- software activation reason
- hotkey registration/action
- schedule apply/pause/resume
- display reconnect/wake
- platform-blocked observation

Why H1 ranks first:

- Manual QA is required for this app.
- The user wants certainty across a hypothesis chain.
- Diagnostics make failure recovery concrete.

Failure conditions:

- Diagnostics becomes noisy or includes sensitive data.

Next hypotheses:

- H2: Keep only last 200 events, already supported.
- H3: Add severity filters in UI.
- H4: Keep raw diagnostics local JSON only; no external reporting.

### Login Item Hypotheses

#### H1: Settings Toggle Using `SMAppService.mainApp`

Hypothesis:

Use existing `LoginItemController` to expose launch-at-login in settings.

Why H1 ranks first:

- App targets macOS 14 and `SMAppService` is the modern path for macOS 13+.
- Existing controller already maps known statuses.

Failure conditions:

- Unsigned local debug app cannot fully register as expected.
- System Settings requires user approval.

Next hypotheses:

- H2: Show `requiresApproval` with a clear note and leave final signing/login QA until packaging.
- H3: Treat login item as post-MVP packaging if local debug behavior is inconsistent.

## Prioritized Implementation Hypothesis Ladder

### Stage 1: Make The Current App Actually Control Perceived Dimming

H1:

- Add callback-based menu actions.
- Add selected-display resolution on startup.
- Add forced software diagnostic command path for manual dimming before real DDC.
- Fix overlay frame to selected display.
- Refresh popover after state changes.

If H1 fails:

- H2: Extract `AppCoordinator` and keep `MenuBarController` only as UI.
- H3: Replace popover `NSView` with `NSViewController`.
- H4: Use SwiftUI popover only if AppKit target/action becomes too costly.

### Stage 2: Wire Hotkeys To The Same Command Path

H1:

- Start `HotkeyManager` from app startup.
- Route every shortcut to the same `adjust(...)` and clear/restore functions used by menu buttons.

If H1 fails:

- H2: Disable only failing bindings and expose diagnostics.
- H3: Add settings-based rebinding before enabling defaults broadly.
- H4: Defer native media keys until custom shortcuts pass.

### Stage 3: Wire Schedule Automation

H1:

- Evaluate schedule at startup.
- Use one-shot next-boundary timer with tolerance.
- Manual commands pause automation until the next boundary.
- Re-evaluate after wake and screen changes.

If H1 fails:

- H2: Add a low-frequency reconciliation timer.
- H3: Add explicit pause/resume UI state and require user resume if boundary logic is ambiguous.

### Stage 4: Add Safe DDC Probe UI

H1:

- Probe button calls `HardwareDDCController.probe(display:)`.
- Store result in `BrightnessState.hardwareCapability`.
- Keep default `NoopDDCAdapter` so the first UI pass is safe.

If H1 fails:

- H2: Show probe result in diagnostics only, not state, until UI state handling is stable.

### Stage 5: Implement Real DDC Adapter

H1:

- Add `IOKitDDCAdapter` behind `DDCAdapter`.
- Reuse existing probe safety ladder.
- Enable hardware mode only after read/write/readback/restore succeeds.

If H1 fails:

- H2: Try alternate IORegistry/framebuffer service matching.
- H3: Classify as read-only if reads work but writes do not.
- H4: Mark hardware unsupported for M1 HDMI/INNOS and use overlay.
- H5: Consider optional external helper only with explicit user approval and license/dependency review.

### Stage 6: Complete Settings And Persistence

H1:

- Persist selected display, schedule, shortcuts, and login preference through `SettingsSnapshot`.
- Keep settings UI simple and AppKit-native.

If H1 fails:

- H2: Use SwiftUI settings view inside AppKit.
- H3: Postpone custom schedule editor and keep operator-guide defaults.

### Stage 7: Manual QA And Claim Gate

H1:

- Fill `docs/qa-matrix.md` row by row with actual observations.
- Keep `VerificationMatrix.canClaimAllRequestedContextsHandled` as the app's claim gate.

If H1 fails:

- H2: Mark context `partial` or `platformBlocked` with visible UI copy.
- H3: Restrict the app's claim to contexts that passed.

## Open Questions

- Does the actual INNOS 27QA100M expose DDC/CI brightness over this M1 direct HDMI path?
- Does the monitor OSD have a DDC/CI toggle that must be enabled manually?
- Does the user want native F1/F2 brightness key interception later, accepting permissions, or are custom shortcuts enough?
- Should screen sharing dim the shared output, or should dimming be local-only when possible?
- How should DRM/protected playback be classified after observation: `pass`, `partial`, or `platformBlocked`?
- Is the user comfortable with an experimental real DDC probe changing brightness by one step during testing?

## Plan Implications

Plan-ready recommendation:

1. Do not start with real DDC transport.
2. First implement the runtime wiring that makes menu actions, hotkeys, software dimming, state refresh, selected display, diagnostics, and schedule automation work together.
3. Keep hardware DDC behind the existing `DDCAdapter` and add probe UI before implementing real IOKit transport.
4. Treat software dimming as a first-class strategy but activate it only through policy: forced diagnostic mode, hardware exhausted, or explicit platform-blocked handling.
5. Use one-shot schedule timers with tolerance and wake/screen-change re-evaluation.
6. Keep custom global shortcuts as MVP; defer native media keys.
7. Only claim complete context coverage after `docs/qa-matrix.md` has evidence rows.

Likely next plan-first implementation slices:

- Slice 1: Runtime command wiring and overlay frame correctness.
- Slice 2: Hotkey startup and command handling.
- Slice 3: Schedule timer and manual override.
- Slice 4: Probe button and diagnostics result surface.
- Slice 5: Settings persistence/editing.
- Slice 6: Real DDC adapter experiment.
- Slice 7: Manual QA matrix and packaging.

## Evidence

Local code evidence:

- `MenuBarPopoverView.swift` creates buttons with `target: nil, action: nil`; buttons are not connected.
- `MenuBarController.swift` starts status item/popover only; no display selection, hotkey manager, schedule timer, settings window, or diagnostics.
- `OverlayWindowManager.swift` calls `configureOverlayPanel(panel, for: .zero)` when creating panels and does not resolve `NSScreen.frame` during apply.
- `HardwareDDCController.swift` has a safe probe state machine and `NoopDDCAdapter` default.
- `ScheduleEngine.swift` has next-boundary and manual-override decisions but no runtime caller.
- `HotkeyManager.swift` validates and registers Carbon hotkeys but is not started by app lifecycle.
- `DisplayInventory.swift` enumerates active displays and can prefer a non-main display.
- `DisplayTargetStore.swift` persists `SettingsSnapshot` in `UserDefaults`.
- `VerificationMatrix.swift` prevents claiming all contexts while rows are `notTested` or `fail`.
- `docs/operator-guide.md` defines default schedule and shortcuts and says not to intercept native brightness/media keys in the MVP.
- `docs/ddc-probe-notes.md` says hardware DDC is not yet implemented and must be verified with read/write/readback/restore.
- `docs/qa-matrix.md` requires concrete manual notes before changing rows to handled states.

Commands run:

- `rg --files /Users/moonsoo/projects/InnosDimmer/InnosDimmer /Users/moonsoo/projects/InnosDimmer/InnosDimmerTests /Users/moonsoo/projects/InnosDimmer/docs | sort`
- `rg -n "TODO|MVP|milestone|phase|DDC Probe|Pause automation|Settings|HotkeyManager|ScheduleEngine|Timer|start\\(|action:|target:" /Users/moonsoo/projects/InnosDimmer -g '*.swift' -g '*.md'`
- `git -C /Users/moonsoo/projects/InnosDimmer log --oneline --decorate -5`
- `git -C /Users/moonsoo/projects/InnosDimmer status --short`

Official evidence:

- Apple `SMAppService` documentation states macOS 13+ apps use it to register/control login items, launch agents, and launch daemons.
- Apple Quartz Display Services documentation describes access to macOS window-server display hardware configuration and control, supporting the current use of CoreGraphics for display enumeration but not establishing a simple public external-monitor DDC brightness setter.
- Apple Core Graphics functions include display vendor/model/serial access, matching current `DisplayInventory` identity collection.
- Apple `NSWindow.CollectionBehavior` and `NSWindow.Level.screenSaver` documentation/search snippets support the overlay-window strategy but do not guarantee all full-screen/Stage Manager/DRM behavior.
- Apple `Timer` and Energy Efficiency Guide support avoiding unnecessary timers, invalidating timers, and setting tolerance.
- Apple `NSApplication.didChangeScreenParametersNotification`, `NSWorkspace.didWakeNotification`, and `NSWorkspace.activeSpaceDidChangeNotification` are relevant to display reconnect, wake, and Spaces overlay refresh.

Community evidence:

- MonitorControl README lists multiple brightness protocols: DDC for external displays, native Apple protocols, gamma table software dimming, and shade/overlay control for AirPlay, Sidecar, DisplayLink, and virtual screens. It also lists combined hardware/software dimming and custom shortcuts.
- MonitorControl README says most modern external LCD displays support DDC/CI through USB-C, DisplayPort, HDMI, DVI, or VGA, but TVs often need software alternatives.
- MonitorControl discussion #1460 includes a maintainer comment that MonitorControl does not support the HDMI port of any M1 Macs and suggests BetterDisplay for all connection types.
- Lunar's M1 DDC article says Intel-era `IOFramebuffer`/`IOI2C*` assumptions stopped working on M1 and required Apple-Silicon-specific investigation.
- ddcctl README confirms external monitor brightness/contrast control by DDC is possible on macOS in some environments, but the project is GPLv3 and maintenance-mode.

Insufficient evidence:

- No local real DDC probe has been run against the user's INNOS 27QA100M HDMI connection.
- No manual overlay QA has been recorded yet for full-screen Spaces, presentation, browser full-screen video, DRM playback, screen sharing, sleep/wake, or HDMI reconnect.
- No settings/login-item behavior has been tested after signing/packaging.
- No native media-key interception feasibility has been tested or approved.
