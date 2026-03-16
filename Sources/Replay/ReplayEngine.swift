import Foundation
import Combine
import AppKit

// MARK: - ReplayEngine

@MainActor
final class ReplayEngine: ObservableObject {
    enum ReplayState {
        case idle, running, paused, completed, failed(String)
    }

    @Published var state: ReplayState = .idle
    @Published var currentStepIndex: Int = 0
    @Published var totalSteps: Int = 0
    @Published var currentStepLabel: String = ""
    @Published var errorMessage: String?

    private let finder = UIElementFinder()
    private let synthesizer = CGEventSynthesizer()
    private let waiter = SmartWaitEngine()
    private var workflow: Workflow?
    private var replayTask: Task<Void, Never>?

    var variables: [String: String] = [:]

    func run(workflow: Workflow, variables: [String: String] = [:]) {
        self.workflow = workflow
        self.variables = variables
        self.totalSteps = workflow.steps.count
        self.currentStepIndex = 0
        self.state = .running

        replayTask = Task { [weak self] in
            await self?.executeSteps(workflow.steps.filter { $0.isEnabled })
        }
    }

    func pause() {
        guard case .running = state else { return }
        state = .paused
    }

    func resume() {
        guard case .paused = state else { return }
        state = .running
    }

    func cancel() {
        replayTask?.cancel()
        replayTask = nil
        state = .idle
    }

    // MARK: - Step Execution

    private func executeSteps(_ steps: [WorkflowStep]) async {
        for step in steps {
            guard !Task.isCancelled else { state = .idle; return }

            // Pause support
            while case .paused = state {
                try? await Task.sleep(nanoseconds: 200_000_000)
            }

            currentStepIndex = step.order
            currentStepLabel = step.label

            // Check pre-condition
            if let condition = step.condition, !evaluate(condition) {
                continue
            }

            // Pre-step delay
            if step.delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(step.delay * 1_000_000_000))
            }

            // Execute with retry
            var success = false
            for attempt in 0..<step.retryPolicy.maxAttempts {
                do {
                    try await execute(step)
                    success = true
                    break
                } catch {
                    if attempt < step.retryPolicy.maxAttempts - 1 {
                        let delay = step.retryPolicy.backoffSeconds * pow(2.0, Double(attempt))
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    }
                }
            }

            if !success {
                errorMessage = "Step \(step.order) failed: \(step.label)"
                state = .failed("Step failed: \(step.label)")
                return
            }
        }
        state = .completed
    }

    private func execute(_ step: WorkflowStep) async throws {
        let s = synthesizer
        switch step.action {

        case .launchApp(let bundleId, _):
            if NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleId }) == nil {
                if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                    let config = NSWorkspace.OpenConfiguration()
                    try? await NSWorkspace.shared.openApplication(at: appURL, configuration: config)
                }
            }
            _ = await waiter.waitForApp(bundleId: bundleId, timeout: 10)

        case .activateApp(let bundleId, _):
            NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first?.activate(options: .activateAllWindows)
            try? await Task.sleep(nanoseconds: 300_000_000)

        case .openURL(let url):
            let expanded = expandVariables(url)
            if let u = URL(string: expanded) { NSWorkspace.shared.open(u) }
            try? await Task.sleep(nanoseconds: 1_000_000_000)

        case .click(let target):
            let point = try await resolvePoint(target)
            await Task.detached(priority: .userInitiated) { s.click(at: point) }.value

        case .doubleClick(let target):
            let point = try await resolvePoint(target)
            await Task.detached(priority: .userInitiated) { s.doubleClick(at: point) }.value

        case .rightClick(let target):
            let point = try await resolvePoint(target)
            await Task.detached(priority: .userInitiated) { s.click(at: point, button: .right) }.value

        case .drag(let from, let to):
            let fromPoint = try await resolvePoint(from)
            let toPoint = try await resolvePoint(to)
            await Task.detached(priority: .userInitiated) { s.drag(from: fromPoint, to: toPoint) }.value

        case .scroll(let target, let dx, let dy):
            let point = try await resolvePoint(target)
            await Task.detached(priority: .userInitiated) { s.scroll(at: point, deltaX: dx, deltaY: dy) }.value

        case .typeText(let text):
            let expanded = expandVariables(text)
            await Task.detached(priority: .userInitiated) { s.typeText(expanded) }.value

        case .keyShortcut(let mods, let key):
            await Task.detached(priority: .userInitiated) { s.sendShortcut(modifiers: mods, key: key) }.value

        case .wait(let seconds):
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))

        case .waitForElement(let target, let timeout):
            let found = await waiter.waitForElement(target: target, finder: finder, timeout: timeout)
            if !found { throw ReplayError.elementNotFound }

        case .waitForWindow(let title, let bundleId, let timeout):
            let found = await waiter.waitForWindow(title: title, bundleId: bundleId, timeout: timeout)
            if !found { throw ReplayError.windowNotFound }

        case .moveFile(let from, let to):
            let src = URL(fileURLWithPath: expandVariables(from))
            let dst = URL(fileURLWithPath: expandVariables(to))
            try FileManager.default.moveItem(at: src, to: dst)

        case .copyFile(let from, let to):
            let src = URL(fileURLWithPath: expandVariables(from))
            let dst = URL(fileURLWithPath: expandVariables(to))
            try FileManager.default.copyItem(at: src, to: dst)

        case .deleteFile(let path):
            try FileManager.default.removeItem(atPath: expandVariables(path))

        case .createFolder(let path):
            try FileManager.default.createDirectory(atPath: expandVariables(path), withIntermediateDirectories: true)

        case .setVariable(let name, let value):
            variables[name] = expandVariables(value)

        case .comment:
            break // no-op

        default: break
        }
    }

    // MARK: - Helpers

    private func resolvePoint(_ target: ElementTarget) async throws -> CGPoint {
        guard let point = await finder.resolve(target) else {
            throw ReplayError.elementNotFound
        }
        return point
    }

    private func expandVariables(_ string: String) -> String {
        var result = string
        for (key, value) in variables {
            result = result.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        return result
    }

    private func evaluate(_ condition: StepCondition) -> Bool {
        let lhsValue = variables[condition.lhs] ?? condition.lhs
        switch condition.op {
        case .equals: return lhsValue == condition.rhs
        case .notEquals: return lhsValue != condition.rhs
        case .contains: return lhsValue.contains(condition.rhs)
        case .notContains: return !lhsValue.contains(condition.rhs)
        case .exists: return !lhsValue.isEmpty
        case .notExists: return lhsValue.isEmpty
        }
    }
}

// MARK: - ReplayError

enum ReplayError: Error {
    case elementNotFound
    case windowNotFound
    case timeout
}

// MARK: - SmartWaitEngine

final class SmartWaitEngine {
    private let pollInterval: TimeInterval = 0.3

    func waitForApp(bundleId: String, timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first != nil { return true }
            try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }
        return false
    }

    func waitForElement(target: ElementTarget, finder: UIElementFinder, timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await finder.resolve(target) != nil { return true }
            try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }
        return false
    }

    func waitForWindow(title: String, bundleId: String, timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first,
               app.isActive {
                if checkWindowTitle(title, for: app) { return true }
            }
            try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }
        return false
    }

    private func checkWindowTitle(_ title: String, for app: NSRunningApplication) -> Bool {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var windows: AnyObject?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windows) == .success,
              let windowList = windows as? [AXUIElement] else { return false }
        for window in windowList {
            var titleValue: AnyObject?
            if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue) == .success,
               let windowTitle = titleValue as? String,
               windowTitle.contains(title) {
                return true
            }
        }
        return false
    }
}
