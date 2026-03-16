import Foundation
import CoreGraphics
import ApplicationServices

// MARK: - CGEventSynthesizer
// Synthesizes mouse and keyboard CGEvents for replay

final class CGEventSynthesizer {
    private let source = CGEventSource(stateID: .hidSystemState)

    func click(at point: CGPoint, button: CGMouseButton = .left) {
        let down = CGEvent(mouseEventSource: source, mouseType: button == .left ? .leftMouseDown : .rightMouseDown, mouseCursorPosition: point, mouseButton: button)
        let up = CGEvent(mouseEventSource: source, mouseType: button == .left ? .leftMouseUp : .rightMouseUp, mouseCursorPosition: point, mouseButton: button)
        down?.post(tap: .cghidEventTap)
        usleep(50_000) // 50ms between down/up
        up?.post(tap: .cghidEventTap)
    }

    func doubleClick(at point: CGPoint) {
        click(at: point)
        usleep(100_000)
        let down2 = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
        down2?.setIntegerValueField(.mouseEventClickState, value: 2)
        let up2 = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
        up2?.setIntegerValueField(.mouseEventClickState, value: 2)
        down2?.post(tap: .cghidEventTap)
        usleep(50_000)
        up2?.post(tap: .cghidEventTap)
    }

    func drag(from: CGPoint, to: CGPoint) {
        let steps = 20
        let dx = (to.x - from.x) / CGFloat(steps)
        let dy = (to.y - from.y) / CGFloat(steps)

        CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: from, mouseButton: .left)?.post(tap: .cghidEventTap)
        usleep(50_000)
        for i in 1..<steps {
            let pt = CGPoint(x: from.x + dx * CGFloat(i), y: from.y + dy * CGFloat(i))
            CGEvent(mouseEventSource: source, mouseType: .leftMouseDragged, mouseCursorPosition: pt, mouseButton: .left)?.post(tap: .cghidEventTap)
            usleep(20_000)
        }
        CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: to, mouseButton: .left)?.post(tap: .cghidEventTap)
    }

    func scroll(at point: CGPoint, deltaX: CGFloat, deltaY: CGFloat) {
        moveMouse(to: point)
        let event = CGEvent(scrollWheelEvent2Source: source, units: .pixel, wheelCount: 2,
                            wheel1: Int32(deltaY * 10), wheel2: Int32(deltaX * 10), wheel3: 0)
        event?.post(tap: .cghidEventTap)
    }

    func moveMouse(to point: CGPoint) {
        CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
    }

    func typeText(_ text: String) {
        // Use AXUIElement approach for reliable text input
        for char in text {
            let str = String(char)
            if #available(macOS 14, *) {
                if let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) {
                    down.keyboardSetUnicodeString(stringLength: str.utf16.count, unicodeString: Array(str.utf16))
                    down.post(tap: .cghidEventTap)
                }
                if let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
                    up.keyboardSetUnicodeString(stringLength: str.utf16.count, unicodeString: Array(str.utf16))
                    up.post(tap: .cghidEventTap)
                }
            }
            usleep(20_000)
        }
    }

    func sendShortcut(modifiers: [KeyModifier], key: String) {
        var flags = CGEventFlags()
        modifiers.forEach {
            switch $0 {
            case .command: flags.insert(.maskCommand)
            case .shift: flags.insert(.maskShift)
            case .option: flags.insert(.maskAlternate)
            case .control: flags.insert(.maskControl)
            case .function: flags.insert(.maskSecondaryFn)
            }
        }
        // Map common key names to virtual key codes
        let keyCode = virtualKeyCode(for: key)
        if let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true) {
            down.flags = flags
            down.post(tap: .cghidEventTap)
        }
        usleep(50_000)
        if let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) {
            up.flags = flags
            up.post(tap: .cghidEventTap)
        }
    }

    private func virtualKeyCode(for key: String) -> CGKeyCode {
        let map: [String: CGKeyCode] = [
            "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
            "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17,
            "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25,
            "7": 26, "-": 27, "8": 28, "0": 29, "]": 30, "o": 31, "u": 32, "[": 33,
            "i": 34, "p": 35, "Return": 36, "l": 37, "j": 38, "'": 39, "k": 40,
            ";": 41, ",": 43, "/": 44, "n": 45, "m": 46, ".": 47,
            "Tab": 48, "Space": 49, "`": 50, "Delete": 51, "Escape": 53
        ]
        return map[key] ?? 0
    }
}
