import Foundation

enum DiagnosticsExporter {
    static func export(_ result: ProbeResult) throws -> Data {
        try JSONEncoder().encode(result)
    }

    static func export(_ snapshot: DiagnosticsSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(snapshot)
    }
}
