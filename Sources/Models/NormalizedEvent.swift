import Foundation
import CoreGraphics

// MARK: - Normalised event produced by capture layer

struct NormalizedEvent {
    enum EventType {
        case mouseClick(button: Int, point: CGPoint, clickCount: Int)
        case mouseDrag(from: CGPoint, to: CGPoint)
        case mouseScroll(point: CGPoint, deltaX: CGFloat, deltaY: CGFloat)
        case keyDown(keyCode: UInt16, characters: String, modifiers: UInt64)
        case appLaunched(bundleId: String, name: String)
        case appActivated(bundleId: String, name: String)
        case windowChanged(title: String, appBundleId: String)
        case fileCreated(path: String)
        case fileRenamed(from: String, to: String)
        case fileMoved(from: String, to: String)
        case fileDeleted(path: String)
    }
    let type: EventType
    let timestamp: Date
    var contextualInfo: ContextualInfo?
}

// MARK: - Contextual info resolved from AX layer

struct ContextualInfo {
    var appBundleId: String?
    var appName: String?
    var windowTitle: String?
    var axRole: String?
    var axLabel: String?
    var axIdentifier: String?
    var screenPoint: CGPoint?
}
