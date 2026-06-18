import Foundation
import ServiceManagement

enum LoginItemStatus: Codable, Equatable {
    case enabled
    case disabled
    case requiresApproval
    case notRegistered
    case unsupported(reason: String)
}

protocol LoginItemControlling: AnyObject {
    func status() -> LoginItemStatus
    func setEnabled(_ isEnabled: Bool) throws
}

final class LoginItemController: LoginItemControlling {
    func status() -> LoginItemStatus {
        guard #available(macOS 13.0, *) else {
            return .unsupported(reason: "SMAppService requires macOS 13 or later")
        }

        switch SMAppService.mainApp.status {
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notRegistered:
            return .notRegistered
        case .notFound:
            return .disabled
        @unknown default:
            return .unsupported(reason: "Unknown login item status")
        }
    }

    func setEnabled(_ isEnabled: Bool) throws {
        guard #available(macOS 13.0, *) else {
            return
        }

        if isEnabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
