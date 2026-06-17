import Foundation

enum VerificationStatus: String, Codable, Equatable {
    case notTested
    case pass
    case partial
    case platformBlocked
    case fail
}

enum VerificationScenario: String, Codable, Equatable, CaseIterable {
    case generalDesktop
    case fullScreenSpaces
    case presentation
    case browserFullScreenVideo
    case drmProtectedPlayback
    case screenSharingOrRecording
    case sleepWake
    case hdmiReconnect
    case shortcutConflict
    case scheduleBoundary
}

struct VerificationRow: Codable, Equatable, Identifiable {
    var id: VerificationScenario
    var status: VerificationStatus
    var lastCheckedAt: Date?
    var note: String
}

enum VerificationMatrix {
    static let defaultRows: [VerificationRow] = VerificationScenario.allCases.map { scenario in
        VerificationRow(id: scenario, status: .notTested, lastCheckedAt: nil, note: "")
    }

    static func update(
        _ rows: [VerificationRow],
        scenario: VerificationScenario,
        status: VerificationStatus,
        note: String,
        checkedAt: Date
    ) -> [VerificationRow] {
        rows.map { row in
            guard row.id == scenario else {
                return row
            }
            return VerificationRow(id: scenario, status: status, lastCheckedAt: checkedAt, note: note)
        }
    }

    static func canClaimAllRequestedContextsHandled(_ rows: [VerificationRow]) -> Bool {
        guard Set(rows.map(\.id)) == Set(VerificationScenario.allCases), rows.count == VerificationScenario.allCases.count else {
            return false
        }

        return rows.allSatisfy { row in
            switch row.status {
            case .pass, .partial, .platformBlocked:
                return !row.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case .notTested, .fail:
                return false
            }
        }
    }

    static func summary(for rows: [VerificationRow]) -> String {
        let handled = rows.filter { row in
            switch row.status {
            case .pass, .partial, .platformBlocked:
                return !row.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case .notTested, .fail:
                return false
            }
        }.count
        return "Verification: \(handled)/\(VerificationScenario.allCases.count) handled"
    }
}
