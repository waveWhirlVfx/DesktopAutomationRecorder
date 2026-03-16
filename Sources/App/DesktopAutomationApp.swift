import SwiftUI
import AppKit

// MARK: - App Entry Point

@main
struct DesktopAutomationApp: App {
    @StateObject private var store = WorkflowStore.shared
    @StateObject private var recorder = RecordingSession()
    @StateObject private var replayEngine = ReplayEngine()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Main window
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(recorder)
                .environmentObject(replayEngine)
                .frame(minWidth: 900, minHeight: 620)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Workflow") {
                    NotificationCenter.default.post(name: .newWorkflow, object: nil)
                }.keyboardShortcut("n")
            }
        }

        // Menu bar extra
        MenuBarExtra("Automation Recorder", systemImage: recorder.state == .recording ? "record.circle.fill" : "record.circle") {
            MenuBarView()
                .environmentObject(store)
                .environmentObject(recorder)
                .environmentObject(replayEngine)
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request permissions on first launch
        PermissionsManager.shared.checkAll()
        NSApp.setActivationPolicy(.regular)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

// MARK: - Notifications

extension Notification.Name {
    static let newWorkflow = Notification.Name("com.automationrecorder.newWorkflow")
}

// MARK: - PermissionsManager

final class PermissionsManager {
    static let shared = PermissionsManager()

    var hasAccessibility: Bool {
        AXIsProcessTrusted()
    }

    var hasScreenRecording: Bool {
        if #available(macOS 14.4, *) {
            return CGPreflightScreenCaptureAccess()
        }
        return true
    }

    func checkAll() {
        if !hasAccessibility {
            // Prompt user to enable in System Settings
            let opts = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(opts)
        }
    }

    func requestScreenRecording() {
        if #available(macOS 14.4, *) {
            CGRequestScreenCaptureAccess()
        }
    }
}
