import Foundation

enum ProbeStepKind: String, Codable, Equatable {
    case identifyDisplay
    case readBrightness
    case chooseReversibleValue
    case writeTestValue
    case readBackTestValue
    case restoreOriginalValue
    case classifyFailure
}

enum ProbeStepOutcome: Codable, Equatable {
    case pending
    case success(note: String)
    case skipped(reason: String)
    case failed(reason: String)
}

struct ProbeStep: Codable, Equatable {
    var kind: ProbeStepKind
    var startedAt: Date
    var finishedAt: Date?
    var outcome: ProbeStepOutcome
}
