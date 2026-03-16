import Foundation

// MARK: - WorkflowStore
// JSON-based persistence for workflows

@MainActor
final class WorkflowStore: ObservableObject {
    static let shared = WorkflowStore()
    
    @Published var workflows: [Workflow] = []
    
    private let storeDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("DesktopAutomationRecorder/Workflows", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private init() {
        loadAll()
    }

    // MARK: - CRUD

    func save(_ workflow: Workflow) {
        var wf = workflow
        wf.lastModified = Date()
        if let idx = workflows.firstIndex(where: { $0.id == wf.id }) {
            workflows[idx] = wf
        } else {
            workflows.append(wf)
        }
        persistToDisk(wf)
    }

    func delete(_ workflow: Workflow) {
        workflows.removeAll { $0.id == workflow.id }
        let file = storeDirectory.appendingPathComponent("\(workflow.id.uuidString).json")
        try? FileManager.default.removeItem(at: file)
    }

    func duplicate(_ workflow: Workflow) {
        var copy = workflow
        copy.id = UUID()
        copy.name = workflow.name + " (Copy)"
        copy.createdAt = Date()
        copy.lastModified = Date()
        save(copy)
    }

    /// Export as JSON to a user-chosen location
    func export(_ workflow: Workflow) -> URL? {
        do {
            let data = try encoder.encode(workflow)
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(workflow.name.sanitized).json")
            try data.write(to: tmp)
            return tmp
        } catch {
            print("[WorkflowStore] Export error: \(error)")
            return nil
        }
    }

    /// Import a workflow from a JSON URL
    func importWorkflow(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            var wf = try decoder.decode(Workflow.self, from: data)
            wf.id = UUID()          // new identity for imported workflow
            wf.name += " (Imported)"
            save(wf)
        } catch {
            print("[WorkflowStore] Import error: \(error)")
        }
    }

    // MARK: - Persistence

    private func persistToDisk(_ workflow: Workflow) {
        do {
            let data = try encoder.encode(workflow)
            let file = storeDirectory.appendingPathComponent("\(workflow.id.uuidString).json")
            try data.write(to: file)
        } catch {
            print("[WorkflowStore] Save error: \(error)")
        }
    }

    private func loadAll() {
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: storeDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" }
            workflows = try files.compactMap { url -> Workflow? in
                let data = try Data(contentsOf: url)
                return try? decoder.decode(Workflow.self, from: data)
            }.sorted { $0.lastModified > $1.lastModified }
        } catch {
            print("[WorkflowStore] Load error: \(error)")
        }
    }
}

private extension String {
    var sanitized: String {
        self.replacingOccurrences(of: "[^a-zA-Z0-9_\\-]", with: "_", options: .regularExpression)
    }
}
