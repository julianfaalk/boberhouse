import Foundation
import SwiftData

@MainActor
final class HouseholdStore: ObservableObject {
    @Published private(set) var members: [HouseholdMember] = []
    @Published private(set) var templates: [TaskTemplate] = []
    @Published private(set) var occurrences: [TaskOccurrence] = []
    @Published private(set) var completions: [CompletionEvent] = []
    @Published var selectedDate: Date = .now
    @Published private(set) var isSyncing: Bool = false
    @Published private(set) var dataVersion: Int = 0

    private var modelContext: ModelContext?
    private let scheduler = SchedulerService()
    private let syncCoordinator = SyncCoordinator.shared
    private let notificationScheduler = LocalNotificationScheduler()

    var isReady: Bool {
        modelContext != nil
    }

    func attachIfNeeded(modelContext: ModelContext) async {
        if let existingContext = self.modelContext, existingContext === modelContext {
            await refreshSnapshots()
            await syncCoordinator.pullIfNeeded()
            return
        }

        self.modelContext = modelContext
        syncCoordinator.attach(context: modelContext)

        seedHouseholdIfNeeded(in: modelContext)
        await refreshSnapshots()

        await syncCoordinator.pullIfNeeded()
        await refreshSnapshots()
        try? await generateUpcomingOccurrences()
        await scheduleReminders()
        PushRegistrationManager.shared.attach(store: self)
    }

    func refreshSnapshots() async {
        guard let modelContext else { return }

        do {
            let memberDescriptor = FetchDescriptor<HouseholdMember>(
                sortBy: [SortDescriptor(\.createdAt)]
            )
            members = try modelContext.fetch(memberDescriptor)

            let templateDescriptor = FetchDescriptor<TaskTemplate>(
                predicate: #Predicate { $0.isActive == true },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
            templates = try modelContext.fetch(templateDescriptor)

            let occurrenceDescriptor = FetchDescriptor<TaskOccurrence>(
                sortBy: [SortDescriptor(\.dueDate)]
            )
            occurrences = try modelContext.fetch(occurrenceDescriptor)

            let completionDescriptor = FetchDescriptor<CompletionEvent>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            completions = try modelContext.fetch(completionDescriptor)
        } catch {
            assertionFailure("Fetch failed: \(error)")
        }
        await scheduleReminders()
        dataVersion &+= 1
    }

    func addTemplate(
        title: String,
        cadenceValue: Int,
        cadenceUnit: CadenceUnit,
        details: String?,
        leadTimeHours: Int,
        startDate: Date
    ) async {
        guard let modelContext else { return }

        let template = TaskTemplate(
            title: title,
            details: details,
            cadenceUnit: cadenceUnit,
            cadenceValue: cadenceValue,
            leadTimeHours: leadTimeHours,
            startDate: startDate
        )

        modelContext.insert(template)

        do {
            try modelContext.save()
            await refreshSnapshots()
            try await generateUpcomingOccurrences()
            await performSync(reason: "template-add")
        } catch {
            assertionFailure("Failed to add template: \(error)")
        }
    }

    func markOccurrence(_ occurrence: TaskOccurrence, as status: TaskOccurrenceStatus, notes: String? = nil) async {
        guard let modelContext else { return }

        occurrence.status = status
        occurrence.syncRevision = 0

        if status == .completed, let member = members.first(where: { $0.id == occurrence.assignedMemberID }) {
            let completion = CompletionEvent(memberID: member.id, occurrenceID: occurrence.id, notes: notes)
            occurrence.completedAt = .now
            modelContext.insert(completion)
        } else if status != .completed {
            occurrence.completedAt = nil
        }

        do {
            try modelContext.save()
            await refreshSnapshots()
            try await generateUpcomingOccurrences()
            await performSync(reason: "occurrence-update")
        } catch {
            assertionFailure("Failed to update occurrence: \(error)")
        }
    }

    func updateTemplate(
        _ template: TaskTemplate,
        title: String,
        details: String?,
        cadenceValue: Int,
        cadenceUnit: CadenceUnit,
        leadTimeHours: Int,
        isActive: Bool,
        startDate: Date
    ) async {
        guard let modelContext else { return }

        template.title = title
        template.details = details
        template.cadenceValue = cadenceValue
        template.cadenceUnit = cadenceUnit
        template.leadTimeHours = leadTimeHours
        template.isActive = isActive
        template.updatedAt = .now
        template.syncRevision = 0
        let previousStartDate = template.startDate ?? template.createdAt
        template.startDate = startDate

        if previousStartDate != startDate {
            // Reset generation markers so the scheduler re-evaluates future occurrences
            template.lastGeneratedDate = nil
            removePendingOccurrences(for: template)
        }

        do {
            try modelContext.save()
            await refreshSnapshots()
            try await generateUpcomingOccurrences()
            await performSync(reason: "template-update")
        } catch {
            assertionFailure("Failed to update template: \(error)")
        }
    }

    func archiveTemplate(_ template: TaskTemplate) async {
        await updateTemplate(
            template,
            title: template.title,
            details: template.details,
            cadenceValue: template.cadenceValue,
            cadenceUnit: template.cadenceUnit,
            leadTimeHours: template.leadTimeHours,
            isActive: false,
            startDate: template.startDate ?? template.createdAt
        )
    }

    func deleteTemplate(_ template: TaskTemplate) async {
        guard let modelContext else { return }

        let occurrenceDescriptor = FetchDescriptor<TaskOccurrence>()
        if let occurrences = try? modelContext.fetch(occurrenceDescriptor).filter({ $0.templateID == template.id }) {
            occurrences.forEach { modelContext.delete($0) }

            let occurrenceIDs = Set(occurrences.map(\.id))
            if !occurrenceIDs.isEmpty {
                let completionDescriptor = FetchDescriptor<CompletionEvent>()
                if let relatedCompletions = try? modelContext.fetch(completionDescriptor) {
                    relatedCompletions
                        .filter { occurrenceIDs.contains($0.occurrenceID) }
                        .forEach { modelContext.delete($0) }
                }
            }
        }

        modelContext.delete(template)

        do {
            try modelContext.save()
            await refreshSnapshots()
            await performSync(reason: "template-delete")
        } catch {
            assertionFailure("Failed to delete template: \(error)")
        }
    }

    func assign(_ occurrence: TaskOccurrence, to member: HouseholdMember?) async {
        guard let modelContext else { return }

        occurrence.assignedMemberID = member?.id
        occurrence.syncRevision = 0

        do {
            try modelContext.save()
            await refreshSnapshots()
            try await generateUpcomingOccurrences()
            await performSync(reason: "assignment-change")
        } catch {
            assertionFailure("Failed to reassign occurrence: \(error)")
        }
    }

    func updateDueDate(for occurrence: TaskOccurrence, to newDate: Date) async {
        guard let modelContext else { return }
        guard occurrence.dueDate != newDate else { return }

        occurrence.dueDate = newDate
        occurrence.syncRevision = 0

        do {
            try modelContext.save()
            await refreshSnapshots()
            try await generateUpcomingOccurrences()
            await performSync(reason: "occurrence-due-date")
        } catch {
            assertionFailure("Failed to update due date: \(error)")
        }
    }

    func updateNotes(for occurrence: TaskOccurrence, notes: String?) async {
        guard let modelContext else { return }

        occurrence.notes = notes
        occurrence.syncRevision = 0

        do {
            try modelContext.save()
            await refreshSnapshots()
            await performSync(reason: "occurrence-notes")
        } catch {
            assertionFailure("Failed to update notes: \(error)")
        }
    }

    func addMember(displayName: String, emojiSymbol: String, accentColorHex: String, isSelf: Bool) async {
        guard let modelContext else { return }

        let member = HouseholdMember(
            displayName: displayName,
            emojiSymbol: emojiSymbol,
            accentColorHex: accentColorHex,
            isSelf: isSelf
        )

        if isSelf {
            members.filter { $0.isSelf && $0.id != member.id }.forEach {
                $0.isSelf = false
                $0.syncRevision = 0
            }
        }

        modelContext.insert(member)

        do {
            try modelContext.save()
            await refreshSnapshots()
            await performSync(reason: "member-add")
        } catch {
            assertionFailure("Failed to add member: \(error)")
        }
    }

    func updateMember(_ member: HouseholdMember, displayName: String, emojiSymbol: String, accentColorHex: String, isSelf: Bool) async {
        guard let modelContext else { return }

        member.displayName = displayName
        member.emojiSymbol = emojiSymbol
        member.accentColorHex = accentColorHex
        member.isSelf = isSelf
        member.updatedAt = .now

        if isSelf {
            members.filter { $0.id != member.id }.forEach {
                $0.isSelf = false
                $0.syncRevision = 0
            }
        }

        do {
            try modelContext.save()
            await refreshSnapshots()
            await performSync(reason: "member-update")
        } catch {
            assertionFailure("Failed to update member: \(error)")
        }
    }

    func removeMember(_ member: HouseholdMember) async {
        guard let modelContext else { return }
        guard members.count > 1 else { return }

        modelContext.delete(member)

        do {
            try modelContext.save()
            await refreshSnapshots()
            await performSync(reason: "member-remove")
        } catch {
            assertionFailure("Failed to remove member: \(error)")
        }
    }

    private func seedHouseholdIfNeeded(in context: ModelContext) {
        let descriptor = FetchDescriptor<HouseholdMember>()
        if let count = try? context.fetchCount(descriptor), count > 0 {
            return
        }

        let selfMember = HouseholdMember(
            displayName: "You",
            emojiSymbol: "🧑",
            accentColorHex: "#5B8DEF",
            isSelf: true
        )

        let partner = HouseholdMember(
            displayName: "Partner",
            emojiSymbol: "❤️",
            accentColorHex: "#EF6F5B",
            isSelf: false
        )

        context.insert(selfMember)
        context.insert(partner)

        do {
            try context.save()
        } catch {
            assertionFailure("Failed to seed household: \(error)")
        }
    }

    private func generateUpcomingOccurrences(horizonDays: Int = 60) async throws {
        guard let modelContext else { return }
        let horizon = Calendar.current.date(byAdding: .day, value: horizonDays, to: .now) ?? .now
        let currentMembers = members

        for template in templates {
            try scheduler.ensureOccurrences(
                for: template,
                members: currentMembers,
                in: modelContext,
                through: horizon
            )
        }

        await refreshSnapshots()
    }

    private func performSync(reason: String) async {
        guard !isSyncing else { return }
        isSyncing = true
        await syncCoordinator.syncNow(reason: reason)
        isSyncing = false
        await refreshSnapshots()
        PushRegistrationManager.shared.attach(store: self)
    }

    private func removePendingOccurrences(for template: TaskTemplate) {
        guard let modelContext else { return }
        let descriptor = FetchDescriptor<TaskOccurrence>()
        if let pending = try? modelContext.fetch(descriptor) {
            pending
                .filter { $0.templateID == template.id && $0.status == .pending }
                .forEach { modelContext.delete($0) }
        }
    }

    private func scheduleReminders() async {
        await notificationScheduler.reschedule(
            occurrences: occurrences,
            templates: templatesByID,
            members: membersByID
        )
    }

    var templatesByID: [UUID: TaskTemplate] {
        Dictionary(uniqueKeysWithValues: templates.map { ($0.id, $0) })
    }

    var membersByID: [UUID: HouseholdMember] {
        Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0) })
    }

    func completions(for occurrence: TaskOccurrence) -> [CompletionEvent] {
        completions.filter { $0.occurrenceID == occurrence.id }
    }

    func performManualSync() async {
        await performSync(reason: "manual-trigger")
    }
}
