import SwiftUI

// MARK: - StepTimelineView

struct StepTimelineView: View {
    @Binding var workflow: Workflow
    @EnvironmentObject var replayEngine: ReplayEngine
    @State private var selectedStep: UUID?
    @State private var showAddStep = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(workflow.name)
                        .font(.headline)
                    Text("\(workflow.steps.count) steps")
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                replayControls
            }
            .padding(12)
            .background(Color.secondaryBg)

            Divider()

            // Replay progress
            if case .running = replayEngine.state {
                ReplayProgressBar(engine: replayEngine, totalSteps: workflow.steps.count)
            }

            // Step list
            if workflow.steps.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "list.clipboard")
                        .font(.system(size: 40)).foregroundColor(.secondary.opacity(0.5))
                    Text("No steps recorded yet")
                        .font(.callout).foregroundColor(.secondary)
                    Text("Start recording to capture actions")
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
            } else {
                List(selection: $selectedStep) {
                    ForEach(Array(workflow.steps.enumerated()), id: \.element.id) { index, step in
                        StepRowView(step: step, index: index + 1,
                                    isActive: replayEngine.currentStepIndex == step.order,
                                    isSelected: selectedStep == step.id)
                            .tag(step.id)
                            .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                    }
                    .onMove { from, to in
                        workflow.steps.move(fromOffsets: from, toOffset: to)
                        for (i, _) in workflow.steps.enumerated() {
                            workflow.steps[i].order = i + 1
                        }
                    }
                    .onDelete { offsets in
                        workflow.steps.remove(atOffsets: offsets)
                    }
                }
                .listStyle(.plain)
            }

            Divider()

            // Bottom add-step bar
            HStack {
                Button {
                    showAddStep = true
                } label: {
                    Label("Add Step", systemImage: "plus")
                        .font(.callout)
                }
                .buttonStyle(.plain)
                .foregroundColor(.accent)
                Spacer()
                Text("\(workflow.steps.filter(\.isEnabled).count) active steps")
                    .font(.caption).foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .sheet(isPresented: $showAddStep) {
            AddStepSheet { step in
                workflow.steps.append(step)
            }
        }
    }

    @ViewBuilder
    private var replayControls: some View {
        HStack(spacing: 6) {
            switch replayEngine.state {
            case .idle, .completed, .failed:
                Button {
                    replayEngine.run(workflow: workflow)
                } label: {
                    Label("Run", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(workflow.steps.isEmpty)

            case .running:
                Button { replayEngine.pause() } label: {
                    Image(systemName: "pause.fill")
                }
                .buttonStyle(.bordered)
                Button { replayEngine.cancel() } label: {
                    Image(systemName: "stop.fill")
                }
                .buttonStyle(.bordered)
                .tint(.red)

            case .paused:
                Button { replayEngine.resume() } label: {
                    Image(systemName: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                Button { replayEngine.cancel() } label: {
                    Image(systemName: "stop.fill")
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
    }
}

// MARK: - StepRowView

struct StepRowView: View {
    let step: WorkflowStep
    let index: Int
    let isActive: Bool
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            // Step number
            ZStack {
                Circle()
                    .fill(isActive ? Color.green : (step.isEnabled ? Color.accent.opacity(0.15) : Color.gray.opacity(0.15)))
                    .frame(width: 28, height: 28)
                if isActive {
                    ProgressView().scaleEffect(0.6)
                } else {
                    Text("\(index)")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundColor(step.isEnabled ? .accent : .secondary)
                }
            }

            // Action icon
            Image(systemName: step.action.iconName)
                .font(.callout)
                .foregroundColor(.secondary)
                .frame(width: 20)

            // Label
            VStack(alignment: .leading, spacing: 2) {
                Text(step.label)
                    .font(.callout)
                    .lineLimit(1)
                    .foregroundColor(step.isEnabled ? .primary : .secondary)
                    .strikethrough(!step.isEnabled)
                HStack(spacing: 6) {
                    Text(step.action.typeName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if step.delay > 0 {
                        Label("\(step.delay, specifier: "%.1f")s delay", systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.orange.opacity(0.8))
                    }
                }
            }

            Spacer()

            // Type badge
            Text(step.action.typeName)
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color.accent.opacity(0.12))
                .foregroundColor(.accent)
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? Color.green.opacity(0.12) : (isSelected ? Color.accent.opacity(0.08) : Color.clear))
        )
    }
}

// MARK: - ReplayProgressBar

struct ReplayProgressBar: View {
    @ObservedObject var engine: ReplayEngine
    let totalSteps: Int

    var progress: Double {
        totalSteps > 0 ? Double(engine.currentStepIndex) / Double(totalSteps) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "play.fill").foregroundColor(.green).font(.caption)
                Text(engine.currentStepLabel)
                    .font(.caption)
                    .lineLimit(1)
                Spacer()
                Text("\(engine.currentStepIndex)/\(totalSteps)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(.green)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.green.opacity(0.06))
    }
}

// MARK: - AddStepSheet

struct AddStepSheet: View {
    let onAdd: (WorkflowStep) -> Void
    @State private var selectedAction = 0
    @State private var label = ""
    @Environment(\.dismiss) private var dismiss

    let actionTypes: [(String, String)] = [
        ("Wait", "clock"),
        ("Type Text", "keyboard"),
        ("Key Shortcut", "command"),
        ("Launch App", "app.badge"),
        ("Open URL", "globe"),
        ("Move File", "document.on.document"),
        ("Comment", "text.bubble")
    ]

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Step").font(.title2).fontWeight(.bold)

            Picker("Action", selection: $selectedAction) {
                ForEach(Array(actionTypes.enumerated()), id: \.offset) { i, type in
                    Label(type.0, systemImage: type.1).tag(i)
                }
            }
            .pickerStyle(.menu)

            TextField("Step label (optional)", text: $label)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.escape)
                Spacer()
                Button("Add") {
                    let action = makeDefaultAction()
                    let step = WorkflowStep(order: 0, action: action,
                                           label: label.isEmpty ? actionTypes[selectedAction].0 : label)
                    onAdd(step)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
            }
        }
        .padding(24)
        .frame(width: 340)
    }

    private func makeDefaultAction() -> StepAction {
        switch selectedAction {
        case 0: return .wait(seconds: 1)
        case 1: return .typeText(text: "")
        case 2: return .keyShortcut(modifiers: [.command], key: "c")
        case 3: return .launchApp(bundleId: "com.apple.Safari", appName: "Safari")
        case 4: return .openURL(url: "https://")
        case 5: return .moveFile(from: "", to: "")
        default: return .comment(text: "")
        }
    }
}
