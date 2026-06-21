import Foundation

struct SettingsActions {
    var selectDisplay: @MainActor (DisplayIdentity?) -> Result<SettingsSnapshot, Error>
    var openScheduleEditor: @MainActor () -> Void
    var updateShortcuts: @MainActor ([ShortcutBinding]) -> Result<SettingsSnapshot, Error>
    var setLaunchAtLogin: @MainActor (Bool) -> Result<LoginItemStatus, Error>
    var exportDiagnostics: @MainActor () -> Result<Data, Error>

    static let noop = SettingsActions(
        selectDisplay: { _ in .success(.defaultSnapshot()) },
        openScheduleEditor: {},
        updateShortcuts: { _ in .success(.defaultSnapshot()) },
        setLaunchAtLogin: { _ in .success(.notRegistered) },
        exportDiagnostics: { .success(Data()) }
    )
}
