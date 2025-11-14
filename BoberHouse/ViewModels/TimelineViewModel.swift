import Foundation

@MainActor
final class TimelineViewModel: ObservableObject {
    struct Section: Identifiable, Equatable {
        let date: Date
        let title: String
        let subtitle: String
        let rows: [Row]

        var id: Date { date }
    }

    struct Row: Identifiable, Equatable {
        let id: UUID
        let title: String
        let time: String
        let memberName: String?
        let memberEmoji: String?
        let status: TaskOccurrenceStatus
        let statusDescription: String
    }

    @Published private(set) var sections: [Section] = []

    private var rebuildTask: Task<Void, Never>?

    func rebuild(
        occurrences: [TaskOccurrence],
        templates: [TaskTemplate],
        members: [HouseholdMember],
        includeCompleted: Bool
    ) {
        let occurrenceSnapshots = occurrences.map(OccurrenceSnapshot.init)
        let templateSnapshots = Dictionary(
            uniqueKeysWithValues: templates.map { ($0.id, TemplateSnapshot(model: $0)) }
        )
        let memberSnapshots = Dictionary(
            uniqueKeysWithValues: members.map { ($0.id, MemberSnapshot(model: $0)) }
        )

        rebuildTask?.cancel()
        rebuildTask = Task.detached(
            priority: .userInitiated
        ) { [weak self, occurrenceSnapshots, templateSnapshots, memberSnapshots, includeCompleted] in
            guard let self else { return }
            let sections = Self.buildSections(
                occurrences: occurrenceSnapshots,
                templates: templateSnapshots,
                members: memberSnapshots,
                includeCompleted: includeCompleted
            )
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.sections = sections
            }
        }
    }

    func cancelWork() {
        rebuildTask?.cancel()
        rebuildTask = nil
    }
}

private extension TimelineViewModel {
    struct OccurrenceSnapshot: Sendable {
        let id: UUID
        let dueDate: Date
        let status: TaskOccurrenceStatus
        let assignedMemberID: UUID?
        let templateID: UUID
        let completedAt: Date?

        init(model: TaskOccurrence) {
            id = model.id
            dueDate = model.dueDate
            status = model.status
            assignedMemberID = model.assignedMemberID
            templateID = model.templateID
            completedAt = model.completedAt
        }
    }

    struct TemplateSnapshot: Sendable {
        let id: UUID
        let title: String

        init(model: TaskTemplate) {
            id = model.id
            title = model.title
        }
    }

    struct MemberSnapshot: Sendable {
        let id: UUID
        let displayName: String
        let emojiSymbol: String

        init(model: HouseholdMember) {
            id = model.id
            displayName = model.displayName
            emojiSymbol = model.emojiSymbol
        }
    }

    nonisolated static func buildSections(
        occurrences: [OccurrenceSnapshot],
        templates: [UUID: TemplateSnapshot],
        members: [UUID: MemberSnapshot],
        includeCompleted: Bool
    ) -> [Section] {
        let calendar = Calendar.current
        let filteredOccurrences = includeCompleted
            ? occurrences
            : occurrences.filter { $0.status == .pending }
        let grouped = Dictionary(grouping: filteredOccurrences) { calendar.startOfDay(for: $0.dueDate) }

        return grouped
            .map { day, occurrences in
                let sorted = occurrences.sorted { $0.dueDate < $1.dueDate }
                let rows = sorted.map { occurrence in
                    let templateTitle = templates[occurrence.templateID]?.title ?? "Task"
                    let member = occurrence.assignedMemberID.flatMap { members[$0] }
                    return Row(
                        id: occurrence.id,
                        title: templateTitle,
                        time: occurrence.dueDate.formatted(date: .omitted, time: .shortened),
                        memberName: member?.displayName,
                        memberEmoji: member?.emojiSymbol,
                        status: occurrence.status,
                        statusDescription: statusDescription(for: occurrence)
                    )
                }

                return Section(
                    date: day,
                    title: sectionTitle(for: day, calendar: calendar),
                    subtitle: day.formatted(date: .complete, time: .omitted),
                    rows: rows
                )
            }
            .sorted { $0.date < $1.date }
    }

    nonisolated static func sectionTitle(for date: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else if let weekday = calendar.dateComponents([.weekday], from: date).weekday {
            let symbols = calendar.weekdaySymbols
            if symbols.indices.contains(weekday - 1) {
                return symbols[weekday - 1]
            }
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    nonisolated static func statusDescription(for occurrence: OccurrenceSnapshot) -> String {
        let timeDescription = occurrence.dueDate.formatted(date: .omitted, time: .shortened)
        switch occurrence.status {
        case .pending:
            return "Scheduled for \(timeDescription)"
        case .completed:
            if let completedAt = occurrence.completedAt {
                return "Completed \(completedAt.formatted(date: .abbreviated, time: .shortened))"
            } else {
                return "Completed"
            }
        case .skipped:
            return "Skipped"
        }
    }
}
