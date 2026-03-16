import Cocoa
import Carbon

// MARK: - MouseEventCaptor
// Captures mouse clicks, drags, and scrolls via CGEventTap

final class MouseEventCaptor {
    private var eventTap: CFMachPort?
    var onEvent: ((NormalizedEvent) -> Void)?

    private var dragStartPoint: CGPoint?

    func start() {
        let mask: CGEventMask =
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.rightMouseUp.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.scrollWheel.rawValue) |
            (1 << CGEventType.otherMouseDown.rawValue)

        let selfPtr = Unmanaged.passRetained(self)
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let captor = Unmanaged<MouseEventCaptor>.fromOpaque(refcon).takeUnretainedValue()
                captor.handle(type: type, event: event)
                return Unmanaged.passRetained(event)
            },
            userInfo: selfPtr.toOpaque()
        )

        if let tap = eventTap {
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        } else {
            print("[MouseEventCaptor] ⚠️ Failed to create event tap. Check Accessibility permissions.")
        }
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }
    }

    private func handle(type: CGEventType, event: CGEvent) {
        let point = event.location
        switch type {
        case .leftMouseDown:
            dragStartPoint = point
        case .leftMouseUp:
            let clickCount = event.getIntegerValueField(.mouseEventClickState)
            if let start = dragStartPoint, distance(start, point) > 10 {
                emit(.mouseDrag(from: start, to: point))
            } else {
                emit(.mouseClick(button: 0, point: point, clickCount: Int(clickCount)))
            }
            dragStartPoint = nil
        case .rightMouseUp:
            emit(.mouseClick(button: 1, point: point, clickCount: 1))
        case .scrollWheel:
            let dx = CGFloat(event.getDoubleValueField(.scrollWheelEventDeltaAxis2))
            let dy = CGFloat(event.getDoubleValueField(.scrollWheelEventDeltaAxis1))
            if abs(dx) > 0.5 || abs(dy) > 0.5 {
                emit(.mouseScroll(point: point, deltaX: dx, deltaY: dy))
            }
        default: break
        }
    }

    private func emit(_ type: NormalizedEvent.EventType) {
        onEvent?(NormalizedEvent(type: type, timestamp: Date()))
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2))
    }
}

// MARK: - KeyboardEventCaptor

final class KeyboardEventCaptor {
    private var eventTap: CFMachPort?
    var onEvent: ((NormalizedEvent) -> Void)?

    // Keystroke aggregation
    private var pendingText = ""
    private var lastKeystrokeTime: Date = .distantPast
    private let aggregationThreshold: TimeInterval = 0.5

    func start() {
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)
        let selfPtr = Unmanaged.passRetained(self)
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let captor = Unmanaged<KeyboardEventCaptor>.fromOpaque(refcon).takeUnretainedValue()
                captor.handle(type: type, event: event)
                return Unmanaged.passRetained(event)
            },
            userInfo: selfPtr.toOpaque()
        )
        if let tap = eventTap {
            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    func stop() {
        flushPendingText()
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }
    }

    private func handle(type: CGEventType, event: CGEvent) {
        guard type == .keyDown else { return }
        let flags = event.flags
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let chars = event.characters ?? ""
        let now = Date()

        // Check for modifier shortcuts
        let hasModifier = flags.contains(.maskCommand) ||
                          flags.contains(.maskControl) ||
                          flags.contains(.maskAlternate)

        if hasModifier {
            flushPendingText()
            var modifiers: [KeyModifier] = []
            if flags.contains(.maskCommand) { modifiers.append(.command) }
            if flags.contains(.maskShift) { modifiers.append(.shift) }
            if flags.contains(.maskAlternate) { modifiers.append(.option) }
            if flags.contains(.maskControl) { modifiers.append(.control) }
            let rawKey = KeyboardHelper.keyCodeToString(keyCode) ?? chars
            onEvent?(NormalizedEvent(type: .keyDown(keyCode: keyCode, characters: rawKey, modifiers: flags.rawValue), timestamp: now))
            return
        }

        // Aggregate regular text
        if now.timeIntervalSince(lastKeystrokeTime) > aggregationThreshold && !pendingText.isEmpty {
            flushPendingText()
        }
        pendingText += chars
        lastKeystrokeTime = now
    }

    private func flushPendingText() {
        guard !pendingText.isEmpty else { return }
        let text = pendingText
        pendingText = ""
        onEvent?(NormalizedEvent(type: .keyDown(keyCode: 0, characters: text, modifiers: 0), timestamp: Date()))
    }
}

// MARK: - KeyboardHelper

enum KeyboardHelper {
    static func keyCodeToString(_ keyCode: UInt16) -> String? {
        let map: [UInt16: String] = [
            36: "Return", 48: "Tab", 49: "Space", 51: "Delete",
            53: "Escape", 122: "F1", 120: "F2", 99: "F3",
            118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8",
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H",
            5: "G", 6: "Z", 7: "X", 8: "C", 9: "V"
        ]
        return map[keyCode]
    }
}

private extension CGEvent {
    var characters: String? {
        let maxLength = 4
        var length = 0
        var chars = [UniChar](repeating: 0, count: maxLength)
        self.keyboardGetUnicodeString(maxStringLength: maxLength, actualStringLength: &length, unicodeString: &chars)
        return length > 0 ? String(utf16CodeUnits: Array(chars.prefix(length)), count: length) : nil
    }
}
