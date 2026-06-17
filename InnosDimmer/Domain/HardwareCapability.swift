import Foundation

enum HardwareCapability: Codable, Equatable {
    case notProbed
    case probing(startedAt: Date)
    case readSupported(current: Int)
    case writeReadbackSupported(range: ClosedRange<Int>)
    case unsupported(reason: String)
    case blockedByPlatform(reason: String)
    case failedWithError(message: String)

    var allowsHardwareWrites: Bool {
        if case .writeReadbackSupported = self {
            return true
        }
        return false
    }

    var isExhaustedFailure: Bool {
        switch self {
        case .unsupported, .blockedByPlatform, .failedWithError:
            return true
        case .notProbed, .probing, .readSupported, .writeReadbackSupported:
            return false
        }
    }
}
