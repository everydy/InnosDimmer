import Foundation

enum Clamped {
    static func percent(_ value: Int) -> Int {
        max(0, min(100, value))
    }
}
