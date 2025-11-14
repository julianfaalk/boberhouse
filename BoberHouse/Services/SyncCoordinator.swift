import Foundation
import SwiftData

@MainActor
final class SyncCoordinator {
    static let shared = SyncCoordinator()

    private let syncService: Syncing
    private let stateStore: SyncStateStore
    private weak var context: ModelContext?
    private var isSyncing = false

    init(
        syncService: Syncing = RemoteSyncService(),
        stateStore: SyncStateStore = .shared
    ) {
        self.syncService = syncService
        self.stateStore = stateStore
    }

    func attach(context: ModelContext) {
        self.context = context
    }

    func syncNow(reason: String = "manual") async {
        guard !isSyncing else { return }
        guard let context else { return }

        isSyncing = true
        defer { isSyncing = false }

        do {
            let baseRevision = stateStore.revision
            let snapshot = try captureSnapshot(in: context, baseRevision: baseRevision)
            let response: SyncPullResponse

            if snapshot.hasLocalChanges {
                response = try await syncService.push(snapshot.request)
            } else {
                response = try await syncService.pull(since: baseRevision)
            }
            try apply(response: response, in: context)
            stateStore.revision = response.revision
        } catch {
            NSLog("Sync failed (\(reason)): \(error.localizedDescription)")
        }
    }

    func pullIfNeeded() async {
        guard !isSyncing else { return }
        guard let context else { return }

        isSyncing = true
        defer { isSyncing = false }

        do {
            let response = try await syncService.pull(since: stateStore.revision)
            try apply(response: response, in: context)
            stateStore.revision = response.revision
        } catch {
            NSLog("Pull failed: \(error.localizedDescription)")
        }
    }

    private func captureSnapshot(in context: ModelContext, baseRevision: Int64) throws -> SyncSnapshot {
        let members = try context.fetch(FetchDescriptor<HouseholdMember>())
        let templates = try context.fetch(FetchDescriptor<TaskTemplate>())
        let occurrences = try context.fetch(FetchDescriptor<TaskOccurrence>())
        let completions = try context.fetch(FetchDescriptor<CompletionEvent>())

        let memberDTOs = members.map { $0.toDTO() }
        let templateDTOs = templates.map { $0.toDTO() }
        let occurrenceDTOs = occurrences.map { $0.toDTO() }
        let completionDTOs = completions.map { $0.toDTO() }

        let hasLocalChanges = memberDTOs.contains(where: { $0.syncRevision == 0 })
            || templateDTOs.contains(where: { $0.syncRevision == 0 })
            || occurrenceDTOs.contains(where: { $0.syncRevision == 0 })
            || completionDTOs.contains(where: { $0.syncRevision == 0 })

        return SyncSnapshot(
            request: SyncPushRequest(
                baseRevision: baseRevision,
                members: memberDTOs,
                templates: templateDTOs,
                occurrences: occurrenceDTOs,
                completions: completionDTOs
            ),
            hasLocalChanges: hasLocalChanges
        )
    }

    private func apply(response: SyncPullResponse, in context: ModelContext) throws {
        guard !response.members.isEmpty
            || !response.templates.isEmpty
            || !response.occurrences.isEmpty
            || !response.completions.isEmpty else {
            return
        }

        let existingMembers = try context.fetch(FetchDescriptor<HouseholdMember>())
        var membersByID = Dictionary(uniqueKeysWithValues: existingMembers.map { ($0.id, $0) })

        for dto in response.members {
            if let member = membersByID[dto.id] {
                member.syncRevision = dto.syncRevision
                member.displayName = dto.displayName
                member.emojiSymbol = dto.emojiSymbol
                member.accentColorHex = dto.accentColorHex
                member.isSelf = dto.isSelf
                member.createdAt = dto.createdAt
                member.updatedAt = dto.updatedAt
            } else {
                let member = HouseholdMember(dto: dto)
                context.insert(member)
                membersByID[dto.id] = member
            }
        }

        let existingTemplates = try context.fetch(FetchDescriptor<TaskTemplate>())
        var templatesByID = Dictionary(uniqueKeysWithValues: existingTemplates.map { ($0.id, $0) })

        for dto in response.templates {
            if let template = templatesByID[dto.id] {
                template.apply(dto: dto)
            } else {
                let template = TaskTemplate(dto: dto)
                context.insert(template)
                templatesByID[dto.id] = template
            }
        }

        let existingOccurrences = try context.fetch(FetchDescriptor<TaskOccurrence>())
        var occurrencesByID = Dictionary(uniqueKeysWithValues: existingOccurrences.map { ($0.id, $0) })

        for dto in response.occurrences {
            if let occurrence = occurrencesByID[dto.id] {
                occurrence.apply(dto: dto)
            } else {
                let occurrence = TaskOccurrence(dto: dto)
                context.insert(occurrence)
                occurrencesByID[dto.id] = occurrence
            }
        }

        let existingCompletions = try context.fetch(FetchDescriptor<CompletionEvent>())
        var completionsByID = Set(existingCompletions.map { $0.id })

        for dto in response.completions where !completionsByID.contains(dto.id) {
            let completion = CompletionEvent(dto: dto)
            context.insert(completion)
            completionsByID.insert(dto.id)
        }

        try context.save()
    }
}

private extension HouseholdMember {
    convenience init(dto: HouseholdMemberDTO) {
        self.init(
            id: dto.id,
            displayName: dto.displayName,
            emojiSymbol: dto.emojiSymbol,
            accentColorHex: dto.accentColorHex,
            isSelf: dto.isSelf,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt,
            syncRevision: dto.syncRevision
        )
    }

    func toDTO() -> HouseholdMemberDTO {
        HouseholdMemberDTO(
            id: id,
            displayName: displayName,
            emojiSymbol: emojiSymbol,
            accentColorHex: accentColorHex,
            isSelf: isSelf,
            createdAt: createdAt,
            updatedAt: updatedAt,
            syncRevision: syncRevision
        )
    }
}

private extension TaskTemplate {
    convenience init(dto: TaskTemplateDTO) {
        self.init(
            id: dto.id,
            title: dto.title,
            details: dto.details,
            cadenceUnit: CadenceUnit(rawValue: dto.cadenceUnitRaw) ?? .weeks,
            cadenceValue: dto.cadenceValue,
            leadTimeHours: dto.leadTimeHours,
            isActive: dto.isActive,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt,
            startDate: dto.startDate ?? dto.createdAt,
            lastGeneratedDate: dto.lastGeneratedDate,
            syncRevision: dto.syncRevision
        )
    }

    func apply(dto: TaskTemplateDTO) {
        title = dto.title
        details = dto.details
        cadenceUnitRaw = dto.cadenceUnitRaw
        cadenceValue = dto.cadenceValue
        leadTimeHours = dto.leadTimeHours
        isActive = dto.isActive
        createdAt = dto.createdAt
        updatedAt = dto.updatedAt
        startDate = dto.startDate ?? dto.createdAt
        lastGeneratedDate = dto.lastGeneratedDate
        syncRevision = dto.syncRevision
    }

    func toDTO() -> TaskTemplateDTO {
        TaskTemplateDTO(
            id: id,
            title: title,
            details: details,
            cadenceUnitRaw: cadenceUnitRaw,
            cadenceValue: cadenceValue,
            leadTimeHours: leadTimeHours,
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt,
            startDate: startDate,
            lastGeneratedDate: lastGeneratedDate,
            syncRevision: syncRevision
        )
    }
}

private extension TaskOccurrence {
    convenience init(dto: TaskOccurrenceDTO) {
        self.init(
            id: dto.id,
            dueDate: dto.dueDate,
            status: TaskOccurrenceStatus(rawValue: dto.statusRaw) ?? .pending,
            assignedMemberID: dto.assignedMemberID,
            templateID: dto.templateID,
            scheduledAt: dto.scheduledAt,
            completedAt: dto.completedAt,
            notes: dto.notes,
            syncRevision: dto.syncRevision
        )
    }

    func apply(dto: TaskOccurrenceDTO) {
        dueDate = dto.dueDate
        statusRaw = dto.statusRaw
        assignedMemberID = dto.assignedMemberID
        scheduledAt = dto.scheduledAt
        completedAt = dto.completedAt
        notes = dto.notes
        syncRevision = dto.syncRevision
    }

    func toDTO() -> TaskOccurrenceDTO {
        TaskOccurrenceDTO(
            id: id,
            templateID: templateID,
            dueDate: dueDate,
            statusRaw: statusRaw,
            assignedMemberID: assignedMemberID,
            scheduledAt: scheduledAt,
            completedAt: completedAt,
            notes: notes,
            syncRevision: syncRevision
        )
    }
}

private extension CompletionEvent {
    convenience init(dto: CompletionEventDTO) {
        self.init(
            id: dto.id,
            timestamp: dto.timestamp,
            memberID: dto.memberID,
            occurrenceID: dto.occurrenceID,
            notes: dto.notes,
            syncRevision: dto.syncRevision
        )
    }

    func toDTO() -> CompletionEventDTO {
        CompletionEventDTO(
            id: id,
            occurrenceID: occurrenceID,
            memberID: memberID,
            timestamp: timestamp,
            notes: notes,
            syncRevision: syncRevision
        )
    }
}
private struct SyncSnapshot {
    var request: SyncPushRequest
    var hasLocalChanges: Bool
}
