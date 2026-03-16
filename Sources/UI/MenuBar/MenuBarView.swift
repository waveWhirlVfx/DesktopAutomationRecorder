import SwiftUI

// MARK: - MenuBarView

struct MenuBarView: View {
    @EnvironmentObject var store: WorkflowStore
    @EnvironmentObject var recorder: RecordingSession
    @EnvironmentObject var replayEngine: ReplayEngine
    @State private var showNameSheet = false
    @State private var recordedName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: recorder.state == .recording ? "record.circle.fill" : "record.circle")
                    .font(.title2)
                    .foregroundColor(recorder.state == .recording ? .red : .accent)
                    .modifier(recorder.state == .recording ? AnyViewModifier(PulseModifier()) : AnyViewModifier(EmptyModifier()))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Automation Recorder")
                        .font(.headline)
                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(14)
            .background(Color.secondaryBg)

            Divider()

            // Recording controls
            Group {
                switch recorder.state {
                case .idle:
                    menuButton("Start Recording", icon: "record.circle", color: .red) {
                        recorder.start()
                    }
                case .recording:
                    menuButton("Pause Recording", icon: "pause.circle", color: .orange) {
                        recorder.pause()
                    }
                    menuButton("Stop & Save", icon: "stop.circle", color: .red) {
                        showNameSheet = true
                    }
                case .paused:
                    menuButton("Resume Recording", icon: "play.circle", color: .green) {
                        recorder.resume()
                    }
                    menuButton("Stop & Save", icon: "stop.circle", color: .red) {
                        showNameSheet = true
                    }
                }
            }
            .padding(.vertical, 4)

            Divider()

            // Recent workflows
            if !store.workflows.isEmpty {
                Text("Recent Workflows")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.top, 8)

                ForEach(store.workflows.prefix(5)) { workflow in
                    menuButton(workflow.name, icon: "play.fill", color: .green) {
                        replayEngine.run(workflow: workflow)
                    }
                }
            }

            Divider()

            menuButton("Open Recorder", icon: "macwindow", color: .accent) {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.windows.first?.makeKeyAndOrderFront(nil)
            }
            menuButton("Quit", icon: "xmark.circle", color: .secondary) {
                NSApp.terminate(nil)
            }
            .padding(.bottom, 4)
        }
        .frame(width: 280)
        .background(Color.bg)
        .sheet(isPresented: $showNameSheet) {
            WorkflowNamingSheet { name in
                let wf = recorder.stop(name: name)
                store.save(wf)
            }
        }
    }

    private var statusText: String {
        switch recorder.state {
        case .idle: return "Ready to record"
        case .recording: return "● Recording · \(recorder.eventCount) events"
        case .paused: return "Paused"
        }
    }

    @ViewBuilder
    private func menuButton(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 20)
                Text(title)
                    .font(.callout)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.clear)
        .hoverEffect()
    }
}

// MARK: - WorkflowNamingSheet

struct WorkflowNamingSheet: View {
    let onSave: (String) -> Void
    @State private var name = "My Workflow"
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Save Workflow").font(.title2).fontWeight(.bold)
            TextField("Workflow name", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)
            HStack {
                Button("Discard") { dismiss() }
                Spacer()
                Button("Save") { onSave(name); dismiss() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty)
                    .keyboardShortcut(.return)
            }
        }
        .padding(24)
        .frame(width: 320)
    }
}

// MARK: - AnyViewModifier helper

struct AnyViewModifier: ViewModifier {
    private let modifier: (AnyView) -> AnyView
    init<M: ViewModifier>(_ m: M) { modifier = { AnyView($0.modifier(m)) } }
    func body(content: Content) -> some View { modifier(AnyView(content)) }
}

struct EmptyModifier: ViewModifier {
    func body(content: Content) -> some View { content }
}

// MARK: - Hover effect helper

extension View {
    func hoverEffect() -> some View {
        self.modifier(HoverHighlightModifier())
    }
}

struct HoverHighlightModifier: ViewModifier {
    @State private var isHovered = false
    func body(content: Content) -> some View {
        content
            .background(isHovered ? Color.accent.opacity(0.1) : Color.clear)
            .onHover { isHovered = $0 }
    }
}
