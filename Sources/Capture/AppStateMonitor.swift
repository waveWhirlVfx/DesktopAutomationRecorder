import AppKit

// MARK: - AppStateMonitor
// Monitors application launch, activation, termination via NSWorkspace

final class AppStateMonitor {
    var onEvent: ((NormalizedEvent) -> Void)?
    private var observers: [NSObjectProtocol] = []

    func start() {
        let nc = NSWorkspace.shared.notificationCenter

        observers.append(nc.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] note in
            if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                self?.emit(.appLaunched(bundleId: app.bundleIdentifier ?? "", name: app.localizedName ?? ""))
            }
        })

        observers.append(nc.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                self?.emit(.appActivated(bundleId: app.bundleIdentifier ?? "", name: app.localizedName ?? ""))
            }
        })
    }

    func stop() {
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        observers = []
    }

    private func emit(_ type: NormalizedEvent.EventType) {
        onEvent?(NormalizedEvent(type: type, timestamp: Date()))
    }
}
