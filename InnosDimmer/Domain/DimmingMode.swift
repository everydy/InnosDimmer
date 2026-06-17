import Foundation

enum DimmingMode: String, Codable, Equatable {
    case unknown
    case hardwareDDC
    case gamma
    case overlay
    case platformBlocked
}
