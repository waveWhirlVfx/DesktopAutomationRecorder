import Cocoa
import ApplicationServices

// MARK: - UIElementCaptor
// Resolves AXUIElement info at a screen point

final class UIElementCaptor {
    /// Synchronously queries AX tree at a given screen point.
    /// Must be called off main thread to avoid blocking.
    func elementInfo(at point: CGPoint) -> ContextualInfo? {
        // Flip coordinate: AX uses bottom-left origin, CG uses top-left
        guard let screen = NSScreen.main else { return nil }
        let flippedY = screen.frame.height - point.y

        var elementRef: AXUIElement?
        let systemElement = AXUIElementCreateSystemWide()
        let result = AXUIElementCopyElementAtPosition(systemElement, Float(point.x), Float(flippedY), &elementRef)
        guard result == .success, let element = elementRef else { return nil }

        var info = ContextualInfo()
        info.screenPoint = point

        // App info
        if let pid = pid(for: element),
           let app = NSRunningApplication(processIdentifier: pid) {
            info.appBundleId = app.bundleIdentifier
            info.appName = app.localizedName
        }

        // Window title
        info.windowTitle = ancestorWindowTitle(element)

        // Element role
        if let role: String = attributeValue(element, kAXRoleAttribute as CFString) {
            info.axRole = role
        }
        // Description / label
        if let label: String = attributeValue(element, kAXDescriptionAttribute as CFString) {
            info.axLabel = label
        } else if let title: String = attributeValue(element, kAXTitleAttribute as CFString) {
            info.axLabel = title
        }
        // Identifier
        if let ident: String = attributeValue(element, kAXIdentifierAttribute as CFString) {
            info.axIdentifier = ident
        }

        return info
    }

    // MARK: - Helpers

    private func pid(for element: AXUIElement) -> pid_t? {
        var pid: pid_t = 0
        return AXUIElementGetPid(element, &pid) == .success ? pid : nil
    }

    private func attributeValue<T>(_ element: AXUIElement, _ attribute: CFString) -> T? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
        return value as? T
    }

    private func ancestorWindowTitle(_ element: AXUIElement) -> String? {
        var current: AXUIElement? = element
        for _ in 0..<10 {
            guard let el = current else { break }
            if let role: String = attributeValue(el, kAXRoleAttribute as CFString), role == "AXWindow" {
                return attributeValue(el, kAXTitleAttribute as CFString)
            }
            var parent: AnyObject?
            guard AXUIElementCopyAttributeValue(el, kAXParentAttribute as CFString, &parent) == .success else { break }
            current = parent as! AXUIElement?
        }
        return nil
    }
}
