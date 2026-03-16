import SwiftUI

// MARK: - WorkflowListView (Sidebar)

struct WorkflowListView: View {
    @EnvironmentObject var store: WorkflowStore
    @Binding var selectedWorkflow: Workflow?
    @State private var searchText = ""
    @State private var showNewSheet = false

    var filteredWorkflows: [Workflow] {
        if searchText.isEmpty { return store.workflows }
        return store.workflows.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Workflows")
                    .font(.headline)
                Spacer()
                Button { showNewSheet = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // Search
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("Search workflows…", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color.secondaryBg)
            .cornerRadius(8)
            .padding(.horizontal, 10)
            .padding(.top, 8)

            // List
            if filteredWorkflows.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "tray").font(.largeTitle).foregroundColor(.secondary)
                    Text("No workflows yet").font(.callout).foregroundColor(.secondary)
                }
                Spacer()
            } else {
                List(filteredWorkflows, selection: $selectedWorkflow) { workflow in
                    WorkflowRowView(workflow: workflow)
                        .tag(workflow)
                        .contextMenu { workflowContextMenu(workflow) }
                }
                .listStyle(.sidebar)
            }
        }
        .background(Color.bg)
        .sheet(isPresented: $showNewSheet) {
            NewWorkflowSheet { name in
                let wf = Workflow(name: name)
                store.save(wf)
                selectedWorkflow = wf
            }
        }
    }

    @ViewBuilder
    private func workflowContextMenu(_ wf: Workflow) -> some View {
        Button("Duplicate") { store.duplicate(wf) }
        Button("Export as JSON") {
            if let url = store.export(wf) {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
        Divider()
        Button("Delete", role: .destructive) {
            if selectedWorkflow?.id == wf.id { selectedWorkflow = nil }
            store.delete(wf)
        }
    }
}

// MARK: - WorkflowRowView

struct WorkflowRowView: View {
    let workflow: Workflow

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(workflow.name)
                .font(.system(.callout, weight: .medium))
                .lineLimit(1)
            HStack(spacing: 4) {
                Image(systemName: "list.bullet")
                    .font(.caption2)
                Text("\(workflow.steps.count) steps")
                    .font(.caption)
                Spacer()
                Text(workflow.lastModified.formatted(.relative(presentation: .named)))
                    .font(.caption)
            }
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}
