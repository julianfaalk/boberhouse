import Foundation

@MainActor
final class TaskTemplateListViewModel: ObservableObject {
    struct Row: Identifiable, Equatable {
        let id: UUID
        let title: String
        let details: String?
        let cadenceDescription: String
        let leadTimeDescription: String?
    }

    @Published private(set) var rows: [Row] = []

    private var rebuildTask: Task<Void, Never>?

    func rebuild(templates: [TaskTemplate]) {
        let snapshots = templates.map(TemplateSnapshot.init)
        rebuildTask?.cancel()
        rebuildTask = Task.detached(priority: .userInitiated) { [weak self, snapshots] in
            guard let self else { return }
            let rows = snapshots.map { template in
                Row(
                    id: template.id,
                    title: template.title,
                    details: template.details,
                    cadenceDescription: "Every \(template.cadenceValue) \(template.cadenceLabel)",
                    leadTimeDescription: template.leadTimeHours > 0 ? "Remind \(template.leadTimeHours)h before" : nil
                )
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.rows = rows
            }
        }
    }

    func cancelWork() {
        rebuildTask?.cancel()
        rebuildTask = nil
    }
}

private struct TemplateSnapshot: Sendable {
    let id: UUID
    let title: String
    let details: String?
    let cadenceValue: Int
    let cadenceLabel: String
    let leadTimeHours: Int

    init(model: TaskTemplate) {
        id = model.id
        title = model.title
        details = model.details
        cadenceValue = model.cadenceValue
        cadenceLabel = model.cadenceUnit.localizedLabel.lowercased()
        leadTimeHours = model.leadTimeHours
    }
}
