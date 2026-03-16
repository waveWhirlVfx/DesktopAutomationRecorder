import SwiftUI

// MARK: - ContentView (3-pane layout)

struct ContentView: View {
    @EnvironmentObject var store: WorkflowStore
    @EnvironmentObject var recorder: RecordingSession
    @EnvironmentObject var replayEngine: ReplayEngine
    @State private var selectedWorkflow: Workflow?
    @State private var showNewWorkflowSheet = false
    @State private var showPermissionsAlert = false
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // SIDEBAR
            WorkflowListView(selectedWorkflow: $selectedWorkflow)
                .navigationSplitViewColumnWidth(min: 220, ideal: 250)
        } content: {
            // STEP TIMELINE
            if let workflow = selectedWorkflow {
                StepTimelineView(workflow: workflowBinding(for: workflow))
            } else {
                emptyState
            }
        } detail: {
            // DETAIL / EDITOR PANEL
            if let workflow = selectedWorkflow {
                WorkflowDetailView(workflow: workflowBinding(for: workflow))
            } else {
                DetailPlaceholderView()
            }
        }
        .background(Color.bg)
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                recordingButton
                if recorder.state == .recording {
                    recordingIndicator
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newWorkflow)) { _ in
            showNewWorkflowSheet = true
        }
        .sheet(isPresented: $showNewWorkflowSheet) {
            NewWorkflowSheet { name in
                let wf = Workflow(name: name)
                store.save(wf)
                selectedWorkflow = wf
            }
        }
        .alert("Permissions Required", isPresented: $showPermissionsAlert) {
            Button("Open System Settings") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Desktop Automation Recorder needs Accessibility and Input Monitoring permissions to record and replay actions.")
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var recordingButton: some View {
        switch recorder.state {
        case .idle:
            Button {
                if !PermissionsManager.shared.hasAccessibility {
                    showPermissionsAlert = true
                } else {
                    recorder.start()
                }
            } label: {
                Label("Start Recording", systemImage: "record.circle")
                    .foregroundColor(.red)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red.opacity(0.15))
            .foregroundColor(.red)

        case .recording:
            Button {
                stopRecording()
            } label: {
                Label("Stop", systemImage: "stop.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)

        case .paused:
            HStack(spacing: 8) {
                Button("Resume") { recorder.resume() }
                    .buttonStyle(.bordered)
                Button("Stop") { stopRecording() }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
            }
        }
    }

    @ViewBuilder
    private var recordingIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .modifier(PulseModifier())
            Text(formatTime(recorder.elapsedSeconds))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
            Text("·  \(recorder.eventCount) events")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "wand.and.rays")
                .font(.system(size: 60))
                .foregroundColor(.accent.opacity(0.6))
            Text("Select or Create a Workflow")
                .font(.title2).fontWeight(.semibold)
            Text("Click + to create a new workflow, or select one from the sidebar.")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bg)
    }

    // MARK: - Helpers

    private func workflowBinding(for workflow: Workflow) -> Binding<Workflow> {
        Binding(
            get: { store.workflows.first { $0.id == workflow.id } ?? workflow },
            set: { store.save($0) }
        )
    }

    private func stopRecording() {
        let wf = recorder.stop(name: "Recorded Workflow \(Date().formatted(date: .abbreviated, time: .shortened))")
        store.save(wf)
        selectedWorkflow = wf
    }

    private func formatTime(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

// MARK: - PulseModifier

struct PulseModifier: ViewModifier {
    @State private var animating = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(animating ? 1.4 : 0.8)
            .opacity(animating ? 0.6 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: animating)
            .onAppear { animating = true }
    }
}

// MARK: - NewWorkflowSheet

struct NewWorkflowSheet: View {
    let onCreate: (String) -> Void
    @State private var name = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("New Workflow").font(.title2).fontWeight(.bold)
            TextField("Workflow name", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 280)
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.escape)
                Spacer()
                Button("Create") {
                    guard !name.isEmpty else { return }
                    onCreate(name)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
                .disabled(name.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 340)
    }
}
