import Foundation
import CoreGraphics

// MARK: - WorkflowBuilder
// Converts a stream of NormalizedEvents into WorkflowSteps

@MainActor
final class WorkflowBuilder: ObservableObject {
    private var steps: [WorkflowStep] = []
    private var stepCounter = 0
    private var lastEventTime: Date = .distantPast
    private let delayThreshold: TimeInterval = 1.5

    func reset() {
        steps = []
        stepCounter = 0
        lastEventTime = .distantPast
    }

    func ingest(_ event: NormalizedEvent) {
        let gap = lastEventTime == .distantPast ? 0 : event.timestamp.timeIntervalSince(lastEventTime)
        lastEventTime = event.timestamp

        switch event.type {
        case .appLaunched(let bundleId, let name):
            add(action: .launchApp(bundleId: bundleId, appName: name),
                label: "Launch \(name)",
                delay: gap)

        case .appActivated(let bundleId, let name):
            // Only add if different from previous app step
            if let last = steps.last, case .activateApp(let prevId, _) = last.action, prevId == bundleId { break }
            add(action: .activateApp(bundleId: bundleId, appName: name),
                label: "Switch to \(name)",
                delay: gap)

        case .mouseClick(let button, let point, let clickCount):
            let target = makeTarget(from: event.contextualInfo, fallback: point)
            let label = labelForClick(target: target, button: button, clickCount: clickCount, context: event.contextualInfo)
            if clickCount >= 2 {
                add(action: .doubleClick(target: target), label: label, delay: gap)
            } else if button == 1 {
                add(action: .rightClick(target: target), label: "Right-click \(target.displayDescription)", delay: gap)
            } else {
                add(action: .click(target: target), label: label, delay: gap)
            }

        case .mouseDrag(let from, let to):
            let fromTarget = makeTarget(from: nil, fallback: from)
            let toTarget = makeTarget(from: nil, fallback: to)
            add(action: .drag(from: fromTarget, to: toTarget),
                label: "Drag from (\(Int(from.x)),\(Int(from.y))) to (\(Int(to.x)),\(Int(to.y)))",
                delay: gap)

        case .mouseScroll(let point, let dx, let dy):
            let target = makeTarget(from: event.contextualInfo, fallback: point)
            add(action: .scroll(target: target, deltaX: dx, deltaY: dy),
                label: "Scroll \(dy > 0 ? "up" : "down")",
                delay: gap)

        case .keyDown(let keyCode, let chars, let modifiers):
            if modifiers != 0 {
                // Shortcut
                let mods = decodeModifiers(modifiers)
                let label = mods.map(\.symbol).joined() + chars
                add(action: .keyShortcut(modifiers: mods, key: chars),
                    label: "Shortcut \(label)",
                    delay: gap)
            } else {
                // Regular text — merge into previous typeText if adjacent and gap is small
                if let lastIdx = steps.indices.last,
                   case .typeText(let existing) = steps[lastIdx].action,
                   gap < 1.5 {
                    steps[lastIdx].action = .typeText(text: existing + chars)
                    steps[lastIdx].label = "Type \"\(existing + chars)\""
                    return
                }
                if keyCode == 36 { // Return key
                    add(action: .keyShortcut(modifiers: [], key: "Return"), label: "Press Return", delay: gap)
                } else {
                    add(action: .typeText(text: chars), label: "Type \"\(chars)\"", delay: gap)
                }
            }

        case .fileCreated(let path):
            add(action: .moveFile(from: path, to: path), label: "File created: \(URL(fileURLWithPath: path).lastPathComponent)", delay: gap)

        case .fileMoved(let from, let to):
            add(action: .moveFile(from: from, to: to),
                label: "Move \(URL(fileURLWithPath: from).lastPathComponent) → \(URL(fileURLWithPath: to).deletingLastPathComponent().lastPathComponent)/",
                delay: gap)

        case .fileDeleted(let path):
            add(action: .deleteFile(path: path),
                label: "Delete \(URL(fileURLWithPath: path).lastPathComponent)",
                delay: gap)

        case .fileRenamed(let from, let to):
            add(action: .moveFile(from: from, to: to),
                label: "Rename \(URL(fileURLWithPath: from).lastPathComponent) → \(URL(fileURLWithPath: to).lastPathComponent)",
                delay: gap)

        default: break
        }
    }

    func buildWorkflow(name: String) -> Workflow {
        var wf = Workflow(name: name)
        wf.steps = steps
        wf.metadata.stepCount = steps.count
        return wf
    }

    // MARK: - Helpers

    private func add(action: StepAction, label: String, delay: TimeInterval = 0) {
        stepCounter += 1
        steps.append(WorkflowStep(order: stepCounter, action: action, label: label, delay: delay))
    }

    private func makeTarget(from context: ContextualInfo?, fallback: CGPoint) -> ElementTarget {
        if let ctx = context,
           let role = ctx.axRole, !role.isEmpty,
           let label = ctx.axLabel, !label.isEmpty,
           let bundleId = ctx.appBundleId {
            return .semantic(appBundleId: bundleId, axRole: role, axLabel: label, axIdentifier: ctx.axIdentifier)
        }
        return .coordinate(x: fallback.x, y: fallback.y, relativeTo: .screen)
    }

    private func labelForClick(target: ElementTarget, button: Int, clickCount: Int, context: ContextualInfo?) -> String {
        switch target {
        case .semantic(_, _, let label, _):
            return "Click \"\(label)\""
        case .ocrText(let text, _):
            return "Click text: \"\(text)\""
        case .coordinate(let x, let y, _):
            return "Click at (\(Int(x)), \(Int(y)))"
        }
    }

    private func decodeModifiers(_ rawFlags: UInt64) -> [KeyModifier] {
        var mods: [KeyModifier] = []
        if rawFlags & UInt64(CGEventFlags.maskCommand.rawValue) != 0 { mods.append(.command) }
        if rawFlags & UInt64(CGEventFlags.maskShift.rawValue) != 0 { mods.append(.shift) }
        if rawFlags & UInt64(CGEventFlags.maskAlternate.rawValue) != 0 { mods.append(.option) }
        if rawFlags & UInt64(CGEventFlags.maskControl.rawValue) != 0 { mods.append(.control) }
        return mods
    }
}
