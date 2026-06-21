import AppKit

final class ShortcutKeyField: NSTextField {
    private(set) var capturedKeyCode: UInt16?

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 48, 53:
            super.keyDown(with: event)
        case 51, 117:
            setKeyCode(nil)
            sendAction(action, to: target)
        default:
            setKeyCode(event.keyCode)
            sendAction(action, to: target)
        }
    }

    func setKeyCode(_ keyCode: UInt16?) {
        capturedKeyCode = keyCode
        stringValue = keyCode.map { Self.keyLabel(for: $0) } ?? ""
    }

    func setRawString(_ value: String) {
        capturedKeyCode = nil
        stringValue = value
    }

    func parsedKeyCode() -> UInt16? {
        let input = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if let capturedKeyCode, input == Self.keyLabel(for: capturedKeyCode) {
            return capturedKeyCode
        }
        if let numeric = UInt16(input) {
            return numeric
        }
        return Self.keyCode(for: input)
    }

    private static func keyCode(for label: String) -> UInt16? {
        switch label.lowercased() {
        case "up":
            return 126
        case "down":
            return 125
        case "right":
            return 124
        case "left":
            return 123
        case "0":
            return 29
        case "r":
            return 15
        case "p":
            return 35
        default:
            let normalized = label.lowercased().replacingOccurrences(of: "key ", with: "")
            return UInt16(normalized)
        }
    }

    private static func keyLabel(for keyCode: UInt16) -> String {
        switch keyCode {
        case 126:
            return "Up"
        case 125:
            return "Down"
        case 124:
            return "Right"
        case 123:
            return "Left"
        case 29:
            return "0"
        case 15:
            return "R"
        case 35:
            return "P"
        default:
            return "Key \(keyCode)"
        }
    }
}
