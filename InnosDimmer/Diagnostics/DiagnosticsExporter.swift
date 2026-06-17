import Foundation

enum DiagnosticsExporter {
    static func export(_ result: ProbeResult) throws -> Data {
        try JSONEncoder().encode(result)
    }
}
