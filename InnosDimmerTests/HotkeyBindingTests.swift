import XCTest
@testable import InnosDimmer

final class HotkeyBindingTests: XCTestCase {
    func testDefaultBindingsCoverEveryShortcutActionWithoutConflicts() {
        let bindings = HotkeyManager.defaultBindings

        XCTAssertEqual(Set(bindings.map(\.action)), Set(ShortcutAction.allCases))
        XCTAssertEqual(HotkeyManager.duplicateShortcuts(bindings), [])
        XCTAssertTrue(HotkeyManager.unsafeBindings(in: bindings).isEmpty)
    }

    func testDuplicateDetectionIgnoresDisabledShortcuts() {
        let bindings = [
            ShortcutBinding(action: .brightnessUp, keyCode: 126, modifiers: [.option, .shift], isEnabled: true),
            ShortcutBinding(action: .brightnessDown, keyCode: 126, modifiers: [.option, .shift], isEnabled: false)
        ]

        XCTAssertEqual(HotkeyManager.duplicateShortcuts(bindings), [])
    }

    func testDuplicateDetectionRejectsEnabledConflicts() {
        let bindings = [
            ShortcutBinding(action: .brightnessUp, keyCode: 126, modifiers: [.option, .shift], isEnabled: true),
            ShortcutBinding(action: .blueReductionUp, keyCode: 126, modifiers: [.option, .shift], isEnabled: true)
        ]

        XCTAssertEqual(
            HotkeyManager.duplicateShortcuts(bindings),
            [ShortcutSignature(keyCode: 126, modifiers: [.option, .shift])]
        )
    }

    func testUnsafeBindingsRejectUnmodifiedOrWeakModifiedKeys() {
        let bindings = [
            ShortcutBinding(action: .brightnessUp, keyCode: 126, modifiers: [], isEnabled: true),
            ShortcutBinding(action: .brightnessDown, keyCode: 125, modifiers: [.shift], isEnabled: true),
            ShortcutBinding(action: .blueReductionUp, keyCode: 124, modifiers: [.option, .shift], isEnabled: true)
        ]

        XCTAssertEqual(
            HotkeyManager.unsafeBindings(in: bindings),
            [
                ShortcutBinding(action: .brightnessUp, keyCode: 126, modifiers: [], isEnabled: true),
                ShortcutBinding(action: .brightnessDown, keyCode: 125, modifiers: [.shift], isEnabled: true)
            ]
        )
    }

    func testValidationReportsConflictsAndUnsafeBindings() {
        let bindings = [
            ShortcutBinding(action: .brightnessUp, keyCode: 126, modifiers: [.option, .shift], isEnabled: true),
            ShortcutBinding(action: .blueReductionUp, keyCode: 126, modifiers: [.option, .shift], isEnabled: true),
            ShortcutBinding(action: .quickDisableOverlay, keyCode: 29, modifiers: [], isEnabled: true)
        ]

        let report = HotkeyManager.validate(bindings)

        XCTAssertFalse(report.isValid)
        XCTAssertEqual(report.duplicateSignatures, [ShortcutSignature(keyCode: 126, modifiers: [.option, .shift])])
        XCTAssertEqual(report.unsafeBindings, [
            ShortcutBinding(action: .quickDisableOverlay, keyCode: 29, modifiers: [], isEnabled: true)
        ])
    }

    func testManagerDoesNotRegisterInvalidBindings() {
        let backend = RecordingHotkeyRegistrationBackend()
        let manager = HotkeyManager(backend: backend) { _ in }
        let bindings = [
            ShortcutBinding(action: .brightnessUp, keyCode: 126, modifiers: [], isEnabled: true)
        ]

        XCTAssertThrowsError(try manager.start(bindings: bindings)) { error in
            XCTAssertEqual(
                error as? HotkeyManagerError,
                .validationFailed(HotkeyValidationReport(duplicateSignatures: [], unsafeBindings: bindings))
            )
        }
        XCTAssertNil(backend.registeredBindings)
    }

    func testManagerRegistersValidBindingsWithBackend() throws {
        let backend = RecordingHotkeyRegistrationBackend()
        let manager = HotkeyManager(backend: backend) { _ in }

        try manager.start(bindings: HotkeyManager.defaultBindings)

        XCTAssertEqual(backend.registeredBindings, HotkeyManager.defaultBindings)
    }

    func testShortcutActionsMapToMenuBarCommands() {
        XCTAssertEqual(ShortcutAction.brightnessUp.menuBarCommand, .brightnessUp)
        XCTAssertEqual(ShortcutAction.brightnessDown.menuBarCommand, .brightnessDown)
        XCTAssertEqual(ShortcutAction.blueReductionUp.menuBarCommand, .blueReductionUp)
        XCTAssertEqual(ShortcutAction.blueReductionDown.menuBarCommand, .blueReductionDown)
        XCTAssertEqual(ShortcutAction.quickDisableOverlay.menuBarCommand, .quickDisable)
        XCTAssertEqual(ShortcutAction.restorePreviousDimming.menuBarCommand, .restorePrevious)
    }

    func testShortcutActionDecodesLegacyWarmthNames() throws {
        let decoder = JSONDecoder()

        XCTAssertEqual(try decoder.decode(ShortcutAction.self, from: Data(#""warmthUp""#.utf8)), .blueReductionUp)
        XCTAssertEqual(try decoder.decode(ShortcutAction.self, from: Data(#""warmthDown""#.utf8)), .blueReductionDown)
    }
}

final class MenuBarHotkeyRoutingTests: XCTestCase {
    @MainActor
    func testMenuBarControllerRegistersDefaultHotkeysOnStart() throws {
        var state = BrightnessState.defaultState()
        state.display = .hotkeyTestDisplay
        let brightnessController = BrightnessController(state: state)
        let diagnosticsStore = DiagnosticsStore(maxEvents: 10)
        let backend = RecordingHotkeyRegistrationBackend()
        let menuBarController = MenuBarController(
            brightnessController: brightnessController,
            displayInventory: RecordingHotkeyDisplayInventory(displays: [.hotkeyTestDisplay]),
            displayTargetStore: try makePausedHotkeyStore(),
            diagnosticsStore: diagnosticsStore,
            hotkeyRegistrationBackend: backend,
            currentMinuteOfDay: { 0 }
        )

        menuBarController.start()

        XCTAssertEqual(backend.registeredBindings, HotkeyManager.defaultBindings)
        XCTAssertEqual(diagnosticsStore.latestEvent?.category, .shortcut)
        XCTAssertEqual(diagnosticsStore.latestEvent?.message, "Registered 6 shortcuts")
        XCTAssertEqual(diagnosticsStore.latestEvent?.severity, .info)
    }

    @MainActor
    func testMenuBarControllerRoutesHotkeysThroughSharedCommands() async throws {
        var state = BrightnessState.defaultState()
        state.display = .hotkeyTestDisplay
        let software = RecordingHotkeySoftwareDimmingStrategy()
        let brightnessController = BrightnessController(state: state, softwareStrategy: software)
        let backend = RecordingHotkeyRegistrationBackend()
        let menuBarController = MenuBarController(
            brightnessController: brightnessController,
            displayInventory: RecordingHotkeyDisplayInventory(displays: [.hotkeyTestDisplay]),
            displayTargetStore: try makePausedHotkeyStore(),
            hotkeyRegistrationBackend: backend,
            currentMinuteOfDay: { 0 }
        )
        menuBarController.start()
        software.reset()
        brightnessController.applyPreviewState(state)

        backend.trigger(.brightnessUp)
        await Task.yield()

        XCTAssertEqual(software.appliedCommands.map(\.brightness), [85])
        XCTAssertEqual(software.appliedCommands.map(\.blueReduction), [12])
        XCTAssertEqual(brightnessController.state.targetBrightness, 85)
        XCTAssertEqual(brightnessController.state.lastAppliedCommandSource, .hotkey)
        XCTAssertEqual(brightnessController.state.activeMode, .overlay)

        backend.trigger(.blueReductionDown)
        await Task.yield()

        XCTAssertEqual(software.appliedCommands.map(\.brightness), [85, 85])
        XCTAssertEqual(software.appliedCommands.map(\.blueReduction), [12, 7])
        XCTAssertEqual(brightnessController.state.targetBlueReduction, 7)
        XCTAssertEqual(brightnessController.state.lastAppliedCommandSource, .hotkey)
    }

    @MainActor
    func testMenuBarControllerRoutesQuickDisableAndRestoreHotkeys() async throws {
        var state = BrightnessState.defaultState()
        state.display = .hotkeyTestDisplay
        let software = RecordingHotkeySoftwareDimmingStrategy()
        let brightnessController = BrightnessController(state: state, softwareStrategy: software)
        let backend = RecordingHotkeyRegistrationBackend()
        let menuBarController = MenuBarController(
            brightnessController: brightnessController,
            displayInventory: RecordingHotkeyDisplayInventory(displays: [.hotkeyTestDisplay]),
            displayTargetStore: try makePausedHotkeyStore(),
            hotkeyRegistrationBackend: backend,
            currentMinuteOfDay: { 0 }
        )
        menuBarController.start()
        software.reset()
        brightnessController.applyPreviewState(state)

        backend.trigger(.quickDisableOverlay)
        await Task.yield()

        XCTAssertEqual(software.appliedCommands.map(\.brightness), [100])
        XCTAssertEqual(software.appliedCommands.map(\.blueReduction), [0])
        XCTAssertEqual(brightnessController.state.targetBlueReduction, 0)
        XCTAssertEqual(brightnessController.state.lastAppliedCommandSource, .hotkey)
        XCTAssertEqual(brightnessController.state.activeMode, .overlay)

        backend.trigger(.restorePreviousDimming)
        await Task.yield()

        XCTAssertEqual(software.appliedCommands.map(\.brightness), [100, 80])
        XCTAssertEqual(software.appliedCommands.map(\.blueReduction), [0, 12])
        XCTAssertEqual(brightnessController.state.targetBlueReduction, 12)
        XCTAssertEqual(brightnessController.state.lastAppliedCommandSource, .hotkey)
    }

    @MainActor
    func testMenuBarControllerRecordsHotkeyRegistrationFailure() throws {
        let backend = RecordingHotkeyRegistrationBackend()
        backend.errorToThrow = HotkeyManagerError.registrationFailed(status: -9876)
        let diagnosticsStore = DiagnosticsStore(maxEvents: 10)
        let menuBarController = MenuBarController(
            displayInventory: RecordingHotkeyDisplayInventory(displays: [.hotkeyTestDisplay]),
            displayTargetStore: try makePausedHotkeyStore(),
            diagnosticsStore: diagnosticsStore,
            hotkeyRegistrationBackend: backend,
            currentMinuteOfDay: { 0 }
        )

        menuBarController.start()

        XCTAssertEqual(diagnosticsStore.latestEvent?.category, .shortcut)
        XCTAssertEqual(diagnosticsStore.latestEvent?.severity, .warning)
        XCTAssertTrue(diagnosticsStore.latestEvent?.message.contains("Shortcut registration failed") == true)
    }
}

final class SettingsWindowShortcutCustomizationTests: XCTestCase {
    @MainActor
    func testSettingsWindowSavesCustomizedShortcutBindings() {
        var savedShortcuts: [ShortcutBinding]?
        let actions = SettingsActions(
            selectDisplay: { _ in .success(.defaultSnapshot()) },
            updateSchedule: { _ in .success(.defaultSnapshot()) },
            updateShortcuts: { shortcuts in
                savedShortcuts = shortcuts
                return .success(SettingsSnapshot.defaultSnapshot().replacingShortcuts(shortcuts))
            },
            setLaunchAtLogin: { _ in .success(.notRegistered) },
            exportDiagnostics: { .success(Data()) }
        )
        let controller = SettingsWindowController(actions: actions)
        controller.configure(
            snapshot: .defaultSnapshot(),
            displayCandidates: [],
            loginItemStatus: .notRegistered
        )

        controller.setShortcutForTesting(
            action: .brightnessUp,
            keyCode: 18,
            modifiers: [.control, .shift],
            isEnabled: true
        )
        let result = controller.saveShortcutsForTesting()

        guard case .success(let snapshot) = result else {
            XCTFail("Expected shortcut save to succeed")
            return
        }
        let expected = ShortcutBinding(
            action: .brightnessUp,
            keyCode: 18,
            modifiers: [.control, .shift],
            isEnabled: true
        )
        XCTAssertEqual(savedShortcuts?.first { $0.action == .brightnessUp }, expected)
        XCTAssertEqual(snapshot.shortcuts.first { $0.action == .brightnessUp }, expected)
        XCTAssertEqual(controller.shortcutForTesting(action: .brightnessUp), expected)
    }

    @MainActor
    func testSettingsWindowSavesHumanReadableShortcutKeyLabels() {
        var savedShortcuts: [ShortcutBinding]?
        let actions = SettingsActions(
            selectDisplay: { _ in .success(.defaultSnapshot()) },
            updateSchedule: { _ in .success(.defaultSnapshot()) },
            updateShortcuts: { shortcuts in
                savedShortcuts = shortcuts
                return .success(SettingsSnapshot.defaultSnapshot().replacingShortcuts(shortcuts))
            },
            setLaunchAtLogin: { _ in .success(.notRegistered) },
            exportDiagnostics: { .success(Data()) }
        )
        let controller = SettingsWindowController(actions: actions)
        controller.configure(
            snapshot: .defaultSnapshot(),
            displayCandidates: [],
            loginItemStatus: .notRegistered
        )
        controller.setShortcutForTesting(
            action: .brightnessUp,
            keyCode: 18,
            modifiers: [.control, .shift],
            isEnabled: true
        )
        controller.setShortcutKeyStringForTesting(action: .brightnessUp, keyCode: "R")

        let result = controller.saveShortcutsForTesting()

        guard case .success = result else {
            XCTFail("Expected shortcut save to succeed")
            return
        }
        XCTAssertEqual(savedShortcuts?.first { $0.action == .brightnessUp }?.keyCode, 15)
    }

    @MainActor
    func testSettingsWindowReportsInvalidCustomizedShortcutKey() {
        let controller = SettingsWindowController()
        controller.configure(
            snapshot: .defaultSnapshot(),
            displayCandidates: [],
            loginItemStatus: .notRegistered
        )
        controller.setShortcutForTesting(
            action: .brightnessUp,
            keyCode: 18,
            modifiers: [.control, .shift],
            isEnabled: true
        )
        controller.setShortcutKeyStringForTesting(action: .brightnessUp, keyCode: "not-a-key")

        let result = controller.saveShortcutsForTesting()

        guard case .failure(let error) = result else {
            XCTFail("Expected invalid key to fail")
            return
        }
        XCTAssertEqual(error.localizedDescription, "Brightness up needs a key code from 0 to 65535.")
    }
}

private final class RecordingHotkeyDisplayInventory: DisplayInventoryProviding {
    var displays: [DisplayIdentity]

    init(displays: [DisplayIdentity]) {
        self.displays = displays
    }

    func activeDisplays() -> [DisplayIdentity] {
        displays
    }

    func resolveSelectedDisplay(saved: DisplayIdentity?, candidates: [DisplayIdentity]) -> DisplayIdentity? {
        DisplayInventory.resolveSelectedDisplay(
            saved: saved,
            candidates: candidates,
            mainDisplayID: 999
        )
    }
}

private final class RecordingHotkeyRegistrationBackend: HotkeyRegistrationBackend {
    private(set) var registeredBindings: [ShortcutBinding]?
    var errorToThrow: Error?
    private var handler: ((ShortcutAction) -> Void)?

    func register(_ bindings: [ShortcutBinding], handler: @escaping (ShortcutAction) -> Void) throws {
        if let errorToThrow {
            throw errorToThrow
        }
        registeredBindings = bindings
        self.handler = handler
    }

    func unregisterAll() {
        registeredBindings = nil
        handler = nil
    }

    func trigger(_ action: ShortcutAction) {
        handler?(action)
    }
}

@MainActor
private final class RecordingHotkeySoftwareDimmingStrategy: SoftwareDimmingStrategy {
    private(set) var appliedCommands: [BrightnessCommand] = []

    func apply(_ command: BrightnessCommand) throws {
        appliedCommands.append(command)
    }

    func clear(display: DisplayIdentity) throws {}

    func reset() {
        appliedCommands.removeAll()
    }
}

private func makePausedHotkeyStore() throws -> DisplayTargetStore {
    let suiteName = "InnosDimmer.HotkeyBindingTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let store = DisplayTargetStore(defaults: defaults, key: "SettingsSnapshot")
    var state = BrightnessState.defaultState()
    state.display = .hotkeyTestDisplay
    state.automationPausedUntilNextBoundary = true
    state.automationPausedAtMinuteOfDay = 0
    state.automationResumeMinuteOfDay = 1_439
    var snapshot = SettingsSnapshot.defaultSnapshot().replacingSelectedDisplay(.hotkeyTestDisplay)
    snapshot.state = state
    try store.save(snapshot)
    return store
}

private extension DisplayIdentity {
    static let hotkeyTestDisplay = DisplayIdentity(
        cgDisplayID: 1,
        localizedName: "INNOS 27QA100M",
        vendorNumber: 1,
        modelNumber: 2,
        serialNumber: 3,
        frameDescription: "2560x1440"
    )
}
