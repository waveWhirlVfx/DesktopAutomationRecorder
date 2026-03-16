import SwiftUI

// MARK: - VariablePanel

struct VariablePanel: View {
    @Binding var variables: [WorkflowVariable]
    @State private var showAddSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Variables", systemImage: "square.and.pencil")
                    .font(.callout).fontWeight(.medium)
                Spacer()
                Button { showAddSheet = true } label: {
                    Image(systemName: "plus.circle").foregroundColor(.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(10)

            Divider()

            if variables.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "x.circle").foregroundColor(.secondary.opacity(0.4))
                    Text("No variables").font(.caption).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                List($variables) { $variable in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("{{" + variable.name + "}}")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.accent)
                            Spacer()
                            Text(variable.type.displayName)
                                .font(.system(size: 10))
                                .padding(.horizontal, 4)
                                .background(Color.secondary.opacity(0.15))
                                .cornerRadius(3)
                        }
                        TextField("Default value", text: $variable.defaultValue)
                            .font(.caption)
                            .textFieldStyle(.roundedBorder)
                        Toggle("Prompt on run", isOn: $variable.promptOnRun)
                            .font(.caption)
                            .toggleStyle(.checkbox)
                    }
                    .padding(.vertical, 2)
                    .swipeActions { Button("Delete", role: .destructive) {
                        variables.removeAll { $0.id == variable.id }
                    }}
                }
                .listStyle(.plain)
            }
        }
        .background(Color.secondaryBg)
        .sheet(isPresented: $showAddSheet) {
            AddVariableSheet { variable in
                variables.append(variable)
            }
        }
    }
}

// MARK: - AddVariableSheet

struct AddVariableSheet: View {
    let onAdd: (WorkflowVariable) -> Void
    @State private var name = ""
    @State private var defaultValue = ""
    @State private var type: VariableType = .string
    @State private var promptOnRun = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Variable").font(.title2).fontWeight(.bold)

            Form {
                TextField("Variable name", text: $name)
                TextField("Default value", text: $defaultValue)
                Picker("Type", selection: $type) {
                    ForEach(VariableType.allCases, id: \.self) { t in
                        Text(t.displayName).tag(t)
                    }
                }
                Toggle("Prompt user on run", isOn: $promptOnRun)
            }

            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.escape)
                Spacer()
                Button("Add") {
                    let v = WorkflowVariable(name: name, defaultValue: defaultValue, type: type, promptOnRun: promptOnRun)
                    onAdd(v)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty)
                .keyboardShortcut(.return)
            }
        }
        .padding(24)
        .frame(width: 340)
    }
}
