import Foundation
import SwiftData

struct SchedulerService {
    private let alternationEngine = AlternationEngine()

    @MainActor
    func ensureOccurrences(
        for template: TaskTemplate,
        members: [HouseholdMember],
        in context: ModelContext,
        through horizon: Date
    ) throws {
        guard template.isActive, template.cadenceValue > 0 else { return }

        let templateID = template.id
        let occurrenceDescriptor = FetchDescriptor<TaskOccurrence>(
            predicate: #Predicate { $0.templateID == templateID },
            sortBy: [SortDescriptor(\.dueDate)]
        )
        let templateOccurrences = try context.fetch(occurrenceDescriptor)

        var existingDueDates = Set(templateOccurrences.map(\.dueDate))
        let calendar = Calendar.current
        let anchorDate = template.startDate ?? template.createdAt

        var workingDate = templateOccurrences.map(\.dueDate).max() ?? anchorDate
        var pendingAssignments: [UUID: Int] = [:]
        for occurrence in templateOccurrences where occurrence.status == .pending {
            if let memberID = occurrence.assignedMemberID {
                pendingAssignments[memberID, default: 0] += 1
            }
        }

        let occurrenceIDs = Set(templateOccurrences.map(\.id))
        let completionDescriptor = FetchDescriptor<CompletionEvent>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        let completionHistory = try context.fetch(completionDescriptor).filter { occurrenceIDs.contains($0.occurrenceID) }

        if templateOccurrences.isEmpty {
            let firstDate = anchorDate
            if firstDate <= horizon && !existingDueDates.contains(firstDate) {
                let assignee = alternationEngine.nextAssignee(
                    for: template,
                    members: members,
                    history: completionHistory,
                    upcomingLoad: pendingAssignments
                )

                let occurrence = TaskOccurrence(
                    dueDate: firstDate,
                    status: .pending,
                    assignedMemberID: assignee?.id,
                    templateID: template.id
                )
                context.insert(occurrence)
                existingDueDates.insert(firstDate)
                template.lastGeneratedDate = firstDate
                template.updatedAt = .now
                template.syncRevision = 0

                if let memberID = assignee?.id {
                    pendingAssignments[memberID, default: 0] += 1
                }

                workingDate = firstDate
            }
        }

        while let generatedDate = calendar.date(byAdding: template.cadenceInterval, to: workingDate),
              generatedDate <= horizon {
            workingDate = generatedDate

            if existingDueDates.contains(generatedDate) {
                continue
            }

            let assignee = alternationEngine.nextAssignee(
                for: template,
                members: members,
                history: completionHistory,
                upcomingLoad: pendingAssignments
            )

            let occurrence = TaskOccurrence(
                dueDate: generatedDate,
                status: .pending,
                assignedMemberID: assignee?.id,
                templateID: template.id
            )
            context.insert(occurrence)

            if let memberID = assignee?.id {
                pendingAssignments[memberID, default: 0] += 1
            }

            template.lastGeneratedDate = generatedDate
            template.updatedAt = .now
            template.syncRevision = 0
            existingDueDates.insert(generatedDate)
        }

        try context.save()
    }
}
