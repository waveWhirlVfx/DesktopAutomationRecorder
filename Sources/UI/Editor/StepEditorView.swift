import SwiftUI

// MARK: - WorkflowDetailView

struct WorkflowDetailView: View {
    @Binding var workflow: Workflow
    @State private var selectedStepId: UUID?

    var selectedStep: Binding<WorkflowStep>? {
        guard let id = selectedStepId,
              let idx = workflow.steps.firstIndex(where: { $0.id == id }) else { return nil }
        return $workflow.steps[idx]
    }

    var body: some View {
        HSplitView {
            // Variables panel
            VariablePanel(variables: $workflow.variables)
                .frame(minWidth: 200, idealWidth: 220)

            // Step editor
            Group {
                if let step = selectedStep {
                    StepEditorView(step: step)
                } else {
                    DetailPlaceholderView()
                }
            }
            .frame(minWidth: 300)
        }
        .onReceive(NotificationCenter.default.publisher(for: .stepSelected)) { note in
            selectedStepId = note.object as? UUID
        }
    }
}

// MARK: - DetailPlaceholderView

struct DetailPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.4))
            Text("Select a step to edit")
                .font(.title3)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bg)
    }
}

// MARK: - StepEditorView

struct StepEditorView: View {
    @Binding var step: WorkflowStep

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Image(systemName: step.action.iconName)
                        .font(.title2)
                        .foregroundColor(.accent)
                    Text(step.action.typeName)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Spacer()
                    Toggle("Enabled", isOn: $step.isEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                Divider()

                // Label
                VStack(alignment: .leading, spacing: 4) {
                    Label("Step Label", systemImage: "tag")
                        .font(.caption).foregroundColor(.secondary)
                    TextField("Label", text: $step.label)
                        .textFieldStyle(.roundedBorder)
                }

                // Action-specific fields
                actionEditor

                Divider()

                // Delay
                VStack(alignment: .leading, spacing: 4) {
                    Label("Delay Before Step", systemImage: "clock")
                        .font(.caption).foregroundColor(.secondary)
                    HStack {
                        Slider(value: $step.delay, in: 0...30, step: 0.5)
                        Text("\(step.delay, specifier: "%.1f")s")
                            .font(.system(.callout, design: .monospaced))
                            .frame(width: 44)
                    }
                }

                // Retry
                VStack(alignment: .leading, spacing: 4) {
                    Label("Retry Policy", systemImage: "arrow.counterclockwise")
                        .font(.caption).foregroundColor(.secondary)
                    Stepper("Max attempts: \(step.retryPolicy.maxAttempts)",
                            value: $step.retryPolicy.maxAttempts, in: 1...10)
                }

                // Notes
                VStack(alignment: .leading, spacing: 4) {
                    Label("Notes", systemImage: "text.bubble")
                        .font(.caption).foregroundColor(.secondary)
                    TextEditor(text: $step.notes)
                        .frame(height: 60)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2)))
                }
            }
            .padding(16)
        }
        .background(Color.bg)
    }

    @ViewBuilder
    private var actionEditor: some View {
        Group {
            switch step.action {
            case .wait(let seconds):
                waitEditor(seconds: seconds)
            case .typeText(let text):
                typeTextEditor(text: text)
            case .keyShortcut(let mods, let key):
                shortcutEditor(mods: mods, key: key)
            case .openURL(let url):
                urlEditor(url: url)
            case .launchApp(let bundleId, let name):
                appEditor(bundleId: bundleId, name: name)
            case .click(let target), .doubleClick(let target), .rightClick(let target):
                targetEditor(target: target)
            case .moveFile(let from, let to):
                fileEditor(from: from, to: to)
            case .comment(let text):
                commentEditor(text: text)
            default:
                Text("No additional configuration required.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Sub-editors

    private func waitEditor(seconds: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Wait Duration", systemImage: "clock").font(.caption).foregroundColor(.secondary)
            HStack {
                Slider(value: Binding(
                    get: { seconds },
                    set: { step.action = .wait(seconds: $0) }
                ), in: 0.1...120, step: 0.5)
                Text("\(seconds, specifier: "%.1f")s")
                    .font(.system(.callout, design: .monospaced))
                    .frame(width: 52)
            }
        }
    }

    private func typeTextEditor(text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Text to Type", systemImage: "keyboard").font(.caption).foregroundColor(.secondary)
            TextEditor(text: Binding(
                get: { text },
                set: { step.action = .typeText(text: $0) }
            ))
            .frame(height: 80)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
        }
    }

    private func shortcutEditor(mods: [KeyModifier], key: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Modifiers", systemImage: "command").font(.caption).foregroundColor(.secondary)
            HStack {
                ForEach(KeyModifier.allCases, id: \.self) { mod in
                    Toggle(mod.symbol, isOn: Binding(
                        get: { mods.contains(mod) },
                        set: { on in
                            var newMods = mods
                            on ? newMods.append(mod) : newMods.removeAll { $0 == mod }
                            step.action = .keyShortcut(modifiers: newMods, key: key)
                        }
                    ))
                    .toggleStyle(.button)
                    .buttonStyle(.bordered)
                }
            }
            Label("Key", systemImage: "keyboard").font(.caption).foregroundColor(.secondary)
            TextField("Key (e.g. c, v, Return)", text: Binding(
                get: { key },
                set: { step.action = .keyShortcut(modifiers: mods, key: $0) }
            ))
            .textFieldStyle(.roundedBorder)
        }
    }

    private func urlEditor(url: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("URL", systemImage: "globe").font(.caption).foregroundColor(.secondary)
            TextField("https://", text: Binding(
                get: { url },
                set: { step.action = .openURL(url: $0) }
            ))
            .textFieldStyle(.roundedBorder)
        }
    }

    private func appEditor(bundleId: String, name: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Bundle Identifier", systemImage: "app.badge").font(.caption).foregroundColor(.secondary)
            TextField("com.apple.Safari", text: Binding(
                get: { bundleId },
                set: { step.action = .launchApp(bundleId: $0, appName: name) }
            ))
            .textFieldStyle(.roundedBorder)
        }
    }

    private func targetEditor(target: ElementTarget) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Element Target", systemImage: "viewfinder").font(.caption).foregroundColor(.secondary)
            switch target {
            case .semantic(let bundleId, let role, let label, _):
                Group {
                    TextField("App Bundle ID", text: .constant(bundleId))
                    TextField("AX Role (e.g. AXButton)", text: .constant(role))
                    TextField("Label / Title", text: .constant(label))
                }
                .textFieldStyle(.roundedBorder)
            case .coordinate(let x, let y, _):
                Text("Screen coordinate: (\(Int(x)), \(Int(y)))")
                    .font(.callout)
                    .foregroundColor(.secondary)
            case .ocrText(let text, _):
                TextField("OCR Text", text: .constant(text)).textFieldStyle(.roundedBorder)
            }
        }
    }

    private func fileEditor(from: String, to: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Source Path", systemImage: "folder").font(.caption).foregroundColor(.secondary)
            TextField("~/Downloads/file.pdf", text: Binding(
                get: { from },
                set: { step.action = .moveFile(from: $0, to: to) }
            ))
            .textFieldStyle(.roundedBorder)

            Label("Destination Path", systemImage: "folder.fill").font(.caption).foregroundColor(.secondary)
            TextField("~/Documents/", text: Binding(
                get: { to },
                set: { step.action = .moveFile(from: from, to: $0) }
            ))
            .textFieldStyle(.roundedBorder)
        }
    }

    private func commentEditor(text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Comment Text", systemImage: "text.bubble").font(.caption).foregroundColor(.secondary)
            TextEditor(text: Binding(
                get: { text },
                set: { step.action = .comment(text: $0) }
            ))
            .frame(height: 80)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
        }
    }
}

extension Notification.Name {
    static let stepSelected = Notification.Name("com.automationrecorder.stepSelected")
}
