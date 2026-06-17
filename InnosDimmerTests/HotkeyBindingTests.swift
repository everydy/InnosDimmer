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
}

private final class RecordingHotkeyRegistrationBackend: HotkeyRegistrationBackend {
    private(set) var registeredBindings: [ShortcutBinding]?

    func register(_ bindings: [ShortcutBinding], handler: @escaping (ShortcutAction) -> Void) throws {
        _ = handler
        registeredBindings = bindings
    }

    func unregisterAll() {
        registeredBindings = nil
    }
}
