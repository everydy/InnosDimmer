import AppKit

enum ModeStatusLabel {
    static func title(for mode: DimmingMode) -> String {
        switch mode {
        case .hardwareDDC:
            return "Hardware DDC"
        case .gamma:
            return "Gamma active"
        case .overlay:
            return "Overlay active"
        case .platformBlocked:
            return "Platform blocked"
        case .unknown:
            return "Not probed"
        }
    }
}

final class StatusBadgeView: NSTextField {
    init(mode: DimmingMode) {
        super.init(frame: .zero)
        isEditable = false
        isBordered = false
        drawsBackground = false
        font = .systemFont(ofSize: 12, weight: .semibold)
        stringValue = ModeStatusLabel.title(for: mode)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func update(mode: DimmingMode) {
        stringValue = ModeStatusLabel.title(for: mode)
    }
}
