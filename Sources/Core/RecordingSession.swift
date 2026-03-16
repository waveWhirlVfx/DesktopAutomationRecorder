import Foundation
import Combine
import CoreGraphics

// MARK: - RecordingSession
// Orchestrates all capture modules during a recording session

@MainActor
final class RecordingSession: ObservableObject {
    enum State { case idle, recording, paused }

    @Published var state: State = .idle
    @Published var eventCount: Int = 0
    @Published var elapsedSeconds: Int = 0

    private let mouseCaptor = MouseEventCaptor()
    private let keyboardCaptor = KeyboardEventCaptor()
    private let appMonitor = AppStateMonitor()
    private let fsWatcher = FileSystemWatcher()
    private nonisolated let uiCaptor = UIElementCaptor()
    private let builder = WorkflowBuilder()

    private var timerTask: Task<Void, Never>?
    private var startTime: Date = Date()
    private let contextQueue = DispatchQueue(label: "com.automationrecorder.context", qos: .userInteractive)

    func start() {
        guard state == .idle || state == .paused else { return }
        builder.reset()
        eventCount = 0
        startTime = Date()
        state = .recording

        // Wire capture → context resolution → builder
        mouseCaptor.onEvent = { [weak self] event in
            self?.resolveAndIngest(event)
        }
        keyboardCaptor.onEvent = { [weak self] event in
            self?.resolveAndIngest(event)
        }
        appMonitor.onEvent = { [weak self] event in
            Task { @MainActor in
                self?.builder.ingest(event)
                self?.eventCount += 1
            }
        }
        fsWatcher.onEvent = { [weak self] event in
            Task { @MainActor in
                self?.builder.ingest(event)
                self?.eventCount += 1
            }
        }

        mouseCaptor.start()
        keyboardCaptor.start()
        appMonitor.start()
        fsWatcher.start()

        startTimer()
    }

    func pause() {
        guard state == .recording else { return }
        state = .paused
        stopTimer()
    }

    func resume() {
        guard state == .paused else { return }
        state = .recording
        startTimer()
    }

    func stop(name: String) -> Workflow {
        state = .idle
        stopTimer()
        mouseCaptor.stop()
        keyboardCaptor.stop()
        appMonitor.stop()
        fsWatcher.stop()
        let workflow = builder.buildWorkflow(name: name)
        return workflow
    }

    // MARK: - Private

    private func resolveAndIngest(_ event: NormalizedEvent) {
        // Resolve AX context on background thread, then ingest on main
        contextQueue.async { [weak self] in
            guard let self = self else { return }
            var enriched = event
            if case .mouseClick(_, let point, _) = event.type {
                enriched.contextualInfo = self.uiCaptor.elementInfo(at: point)
            }
            Task { @MainActor [weak self] in
                self?.builder.ingest(enriched)
                self?.eventCount += 1
            }
        }
    }

    private func startTimer() {
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run { self?.elapsedSeconds += 1 }
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }
}
