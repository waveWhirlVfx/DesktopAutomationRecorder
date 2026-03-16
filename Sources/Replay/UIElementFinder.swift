import Cocoa
import ApplicationServices

// MARK: - UIElementFinder
// Resolves ElementTarget → AXUIElement or CGPoint for replay

final class UIElementFinder {

    /// Find a CGPoint for a target, resolving via AX tree first
    func resolve(_ target: ElementTarget) async -> CGPoint? {
        switch target {
        case .semantic(let bundleId, let role, let label, let identifier):
            return await resolveSemanticTarget(bundleId: bundleId, role: role, label: label, identifier: identifier)
        case .ocrText(let text, let region):
            return await resolveOCRTarget(text: text, region: region?.rect)
        case .coordinate(let x, let y, _):
            return CGPoint(x: x, y: y)
        }
    }

    /// Return the AXUIElement for a semantic target (for non-click actions)
    func resolveElement(_ target: ElementTarget) async -> AXUIElement? {
        guard case .semantic(let bundleId, let role, let label, let identifier) = target else { return nil }
        return await findAXElement(bundleId: bundleId, role: role, label: label, identifier: identifier)
    }

    // MARK: - Semantic Resolve

    private func resolveSemanticTarget(bundleId: String, role: String, label: String, identifier: String?) async -> CGPoint? {
        guard let element = await findAXElement(bundleId: bundleId, role: role, label: label, identifier: identifier) else {
            return nil
        }
        return midpoint(of: element)
    }

    private func findAXElement(bundleId: String, role: String, label: String, identifier: String?) async -> AXUIElement? {
        return await Task.detached(priority: .userInitiated) {
            guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first else { return nil }
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            return self.searchElement(in: appElement, role: role, label: label, identifier: identifier, depth: 0)
        }.value
    }

    private func searchElement(in element: AXUIElement, role: String, label: String, identifier: String?, depth: Int) -> AXUIElement? {
        guard depth < 20 else { return nil }

        let elementRole: String? = value(element, kAXRoleAttribute as CFString)
        let elementLabel: String? = value(element, kAXDescriptionAttribute as CFString)
                                 ?? value(element, kAXTitleAttribute as CFString)
        let elementId: String? = value(element, kAXIdentifierAttribute as CFString)

        let roleMatch = elementRole == role
        let labelMatch = elementLabel?.lowercased().contains(label.lowercased()) == true
        let idMatch = identifier.map { elementId == $0 } ?? true

        if roleMatch && labelMatch && idMatch { return element }

        // Recurse into children
        var childrenRef: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement] else { return nil }

        for child in children {
            if let found = searchElement(in: child, role: role, label: label, identifier: identifier, depth: depth + 1) {
                return found
            }
        }
        return nil
    }

    private func midpoint(of element: AXUIElement) -> CGPoint? {
        var posValue: AnyObject?
        var sizeValue: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success else { return nil }
        var pos: CGPoint = .zero
        var size: CGSize = .zero
        AXValueGetValue(posValue as! AXValue, .cgPoint, &pos)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        // Convert AX (bottom-left origin) back to CG (top-left)
        let screen = NSScreen.main?.frame ?? .zero
        let flippedY = screen.height - pos.y - size.height / 2
        return CGPoint(x: pos.x + size.width / 2, y: flippedY)
    }

    // MARK: - OCR Resolve

    private func resolveOCRTarget(text: String, region: CGRect?) async -> CGPoint? {
        // Delegate to VisionBridge
        return await VisionBridge.shared.findText(text, in: region)
    }

    // MARK: - Helper

    private func value<T>(_ element: AXUIElement, _ attribute: CFString) -> T? {
        var ref: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute, &ref) == .success else { return nil }
        return ref as? T
    }
}
