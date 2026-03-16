import Foundation
import CoreGraphics

// MARK: - WorkflowStep

struct WorkflowStep: Codable, Identifiable {
    var id: UUID = UUID()
    var order: Int
    var action: StepAction
    var label: String
    var delay: TimeInterval = 0
    var retryPolicy: RetryPolicy = RetryPolicy()
    var condition: StepCondition?
    var loopConfig: LoopConfig?
    var isEnabled: Bool = true
    var notes: String = ""
}

// MARK: - StepAction

enum StepAction: Codable {
    case launchApp(bundleId: String, appName: String)
    case activateApp(bundleId: String, appName: String)
    case openURL(url: String)
    case click(target: ElementTarget)
    case doubleClick(target: ElementTarget)
    case rightClick(target: ElementTarget)
    case drag(from: ElementTarget, to: ElementTarget)
    case scroll(target: ElementTarget, deltaX: CGFloat, deltaY: CGFloat)
    case typeText(text: String)
    case keyShortcut(modifiers: [KeyModifier], key: String)
    case wait(seconds: TimeInterval)
    case waitForElement(target: ElementTarget, timeout: TimeInterval)
    case waitForWindow(title: String, appBundleId: String, timeout: TimeInterval)
    case moveFile(from: String, to: String)
    case copyFile(from: String, to: String)
    case deleteFile(path: String)
    case createFolder(path: String)
    case setVariable(name: String, value: String)
    case ifCondition(condition: StepCondition, thenLabel: String, elseLabel: String)
    case loop(count: Int?, steps: [WorkflowStep])
    case comment(text: String)

    // MARK: Display helpers
    var typeName: String {
        switch self {
        case .launchApp: return "Launch App"
        case .activateApp: return "Activate App"
        case .openURL: return "Open URL"
        case .click: return "Click"
        case .doubleClick: return "Double Click"
        case .rightClick: return "Right Click"
        case .drag: return "Drag"
        case .scroll: return "Scroll"
        case .typeText: return "Type Text"
        case .keyShortcut: return "Key Shortcut"
        case .wait: return "Wait"
        case .waitForElement: return "Wait for Element"
        case .waitForWindow: return "Wait for Window"
        case .moveFile: return "Move File"
        case .copyFile: return "Copy File"
        case .deleteFile: return "Delete File"
        case .createFolder: return "Create Folder"
        case .setVariable: return "Set Variable"
        case .ifCondition: return "If Condition"
        case .loop: return "Loop"
        case .comment: return "Comment"
        }
    }

    var iconName: String {
        switch self {
        case .launchApp, .activateApp: return "app.badge"
        case .openURL: return "globe"
        case .click: return "cursorarrow.click"
        case .doubleClick: return "cursorarrow.click.2"
        case .rightClick: return "contextualmenu.and.cursorarrow"
        case .drag: return "hand.draw"
        case .scroll: return "scroll"
        case .typeText: return "keyboard"
        case .keyShortcut: return "command"
        case .wait: return "clock"
        case .waitForElement: return "viewfinder"
        case .waitForWindow: return "macwindow"
        case .moveFile, .copyFile: return "document.on.document"
        case .deleteFile: return "trash"
        case .createFolder: return "folder.badge.plus"
        case .setVariable: return "square.and.pencil"
        case .ifCondition: return "arrow.triangle.branch"
        case .loop: return "repeat"
        case .comment: return "text.bubble"
        }
    }
}

// MARK: - KeyModifier

enum KeyModifier: String, Codable, CaseIterable {
    case command, shift, option, control, function
    var symbol: String {
        switch self {
        case .command: return "⌘"
        case .shift: return "⇧"
        case .option: return "⌥"
        case .control: return "⌃"
        case .function: return "fn"
        }
    }
}

// MARK: - ElementTarget

enum ElementTarget: Codable {
    /// Preferred: Accessibility tree targeting
    case semantic(appBundleId: String, axRole: String, axLabel: String, axIdentifier: String?)
    /// Fallback: OCR text on screen
    case ocrText(text: String, searchRegion: CodableCGRect?)
    /// Last resort: raw screen coordinate
    case coordinate(x: CGFloat, y: CGFloat, relativeTo: CoordinateSpace)

    var displayDescription: String {
        switch self {
        case .semantic(_, let role, let label, _):
            return "\(label) (\(role))"
        case .ocrText(let text, _):
            return "Text: \"\(text)\""
        case .coordinate(let x, let y, _):
            return "(\(Int(x)), \(Int(y)))"
        }
    }
}

enum CoordinateSpace: String, Codable {
    case screen
    case windowPercent
}

/// Codable wrapper for CGRect (needed because CGRect doesn't automatically conform)
struct CodableCGRect: Codable {
    var x, y, width, height: CGFloat
    var rect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
    init(_ rect: CGRect) { x = rect.minX; y = rect.minY; width = rect.width; height = rect.height }
}
