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
            ShortcutBinding(action: .warmthUp, keyCode: 126, modifiers: [.option, .shift], isEnabled: true)
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
            ShortcutBinding(action: .warmthUp, keyCode: 124, modifiers: [.option, .shift], isEnabled: true)
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
            ShortcutBinding(action: .warmthUp, keyCode: 126, modifiers: [.option, .shift], isEnabled: true),
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
        XCTAssertEqual(ShortcutAction.warmthUp.menuBarCommand, .warmthUp)
        XCTAssertEqual(ShortcutAction.warmthDown.menuBarCommand, .warmthDown)
        XCTAssertEqual(ShortcutAction.quickDisableOverlay.menuBarCommand, .quickDisable)
        XCTAssertEqual(ShortcutAction.restorePreviousDimming.menuBarCommand, .restorePrevious)
    }
}

final class MenuBarHotkeyRoutingTests: XCTestCase {
    @MainActor
    func testMenuBarControllerRegistersDefaultHotkeysOnStart() {
        var state = BrightnessState.defaultState()
        state.display = .hotkeyTestDisplay
        let brightnessController = BrightnessController(state: state)
        let diagnosticsStore = DiagnosticsStore(maxEvents: 10)
        let backend = RecordingHotkeyRegistrationBackend()
        let menuBarController = MenuBarController(
            brightnessController: brightnessController,
            diagnosticsStore: diagnosticsStore,
            hotkeyRegistrationBackend: backend
        )

        menuBarController.start()

        XCTAssertEqual(backend.registeredBindings, HotkeyManager.defaultBindings)
        XCTAssertEqual(diagnosticsStore.latestEvent?.category, .shortcut)
        XCTAssertEqual(diagnosticsStore.latestEvent?.message, "Registered 6 shortcuts")
        XCTAssertEqual(diagnosticsStore.latestEvent?.severity, .info)
    }

    @MainActor
    func testMenuBarControllerRoutesHotkeysThroughSharedCommands() async {
        var state = BrightnessState.defaultState()
        state.display = .hotkeyTestDisplay
        let brightnessController = BrightnessController(state: state)
        let backend = RecordingHotkeyRegistrationBackend()
        let menuBarController = MenuBarController(
            brightnessController: brightnessController,
            hotkeyRegistrationBackend: backend
        )
        menuBarController.start()

        backend.trigger(.brightnessUp)
        await Task.yield()

        XCTAssertEqual(brightnessController.pendingCommand?.brightness, 85)
        XCTAssertEqual(brightnessController.pendingCommand?.warmth, 12)
        XCTAssertEqual(brightnessController.pendingCommand?.source, .hotkey)
        XCTAssertEqual(brightnessController.state.targetBrightness, 85)

        backend.trigger(.warmthDown)
        await Task.yield()

        XCTAssertEqual(brightnessController.pendingCommand?.brightness, 85)
        XCTAssertEqual(brightnessController.pendingCommand?.warmth, 7)
        XCTAssertEqual(brightnessController.pendingCommand?.source, .hotkey)
        XCTAssertEqual(brightnessController.state.targetWarmth, 7)
    }

    @MainActor
    func testMenuBarControllerRoutesQuickDisableAndRestoreHotkeys() async {
        var state = BrightnessState.defaultState()
        state.display = .hotkeyTestDisplay
        let brightnessController = BrightnessController(state: state)
        let backend = RecordingHotkeyRegistrationBackend()
        let menuBarController = MenuBarController(
            brightnessController: brightnessController,
            hotkeyRegistrationBackend: backend
        )
        menuBarController.start()

        backend.trigger(.quickDisableOverlay)
        await Task.yield()

        XCTAssertEqual(brightnessController.pendingCommand?.brightness, 100)
        XCTAssertEqual(brightnessController.pendingCommand?.warmth, 12)
        XCTAssertEqual(brightnessController.pendingCommand?.source, .hotkey)

        backend.trigger(.restorePreviousDimming)
        await Task.yield()

        XCTAssertEqual(brightnessController.pendingCommand?.brightness, 80)
        XCTAssertEqual(brightnessController.pendingCommand?.warmth, 12)
        XCTAssertEqual(brightnessController.pendingCommand?.source, .hotkey)
    }

    @MainActor
    func testMenuBarControllerRecordsHotkeyRegistrationFailure() {
        let backend = RecordingHotkeyRegistrationBackend()
        backend.errorToThrow = HotkeyManagerError.registrationFailed(status: -9876)
        let diagnosticsStore = DiagnosticsStore(maxEvents: 10)
        let menuBarController = MenuBarController(
            diagnosticsStore: diagnosticsStore,
            hotkeyRegistrationBackend: backend
        )

        menuBarController.start()

        XCTAssertEqual(diagnosticsStore.latestEvent?.category, .shortcut)
        XCTAssertEqual(diagnosticsStore.latestEvent?.severity, .warning)
        XCTAssertTrue(diagnosticsStore.latestEvent?.message.contains("Shortcut registration failed") == true)
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
