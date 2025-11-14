import APNSwift
import Fluent
import Foundation
import Vapor

struct SyncController {
    let db: Database
    let logger: Logger
    private let revisionService: RevisionService
    private let notifier: NotificationService

    init(db: Database, configuration: APNSwiftConfiguration?, logger: Logger, eventLoopGroup: EventLoopGroup) {
        self.db = db
        self.logger = logger
        self.revisionService = RevisionService(db: db)
        self.notifier = NotificationService(configuration: configuration, eventLoopGroup: eventLoopGroup, logger: logger)
    }

    func pull(_ req: Request) async throws -> SyncPullResponse {
        let since = req.query["since"] ?? Int64(0)
        let currentRevision = try await revisionService.currentRevision()

        async let members = HouseholdMemberModel.query(on: db)
            .filter(\.$syncRevision > since)
            .all()
        async let templates = TaskTemplateModel.query(on: db)
            .filter(\.$syncRevision > since)
            .all()
        async let occurrences = TaskOccurrenceModel.query(on: db)
            .filter(\.$syncRevision > since)
            .all()
        async let completions = CompletionEventModel.query(on: db)
            .filter(\.$syncRevision > since)
            .all()

        return SyncPullResponse(
            revision: currentRevision,
            members: try await members.map(HouseholdMemberDTO.init),
            templates: try await templates.map(TaskTemplateDTO.init),
            occurrences: try await occurrences.map(TaskOccurrenceDTO.init),
            completions: try await completions.map(CompletionEventDTO.init)
        )
    }

    func push(_ req: Request) async throws -> SyncPullResponse {
        let payload = try req.content.decode(SyncPushRequest.self)

        let jobs: [NotificationJob] = try await db.transaction { transaction in
            try await applyMembers(payload.members, on: transaction)
            try await applyTemplates(payload.templates, on: transaction)
            let occurrenceJobs = try await applyOccurrences(payload.occurrences, on: transaction)
            try await applyCompletions(payload.completions, on: transaction)
            return occurrenceJobs
        }

        await dispatchNotifications(jobs)

        return try await pullWithBaseRevision(payload.baseRevision)
    }

    private func pullWithBaseRevision(_ revision: Int64) async throws -> SyncPullResponse {
        let currentRevision = try await revisionService.currentRevision()

        async let members = HouseholdMemberModel.query(on: db)
            .filter(\.$syncRevision > revision)
            .all()
        async let templates = TaskTemplateModel.query(on: db)
            .filter(\.$syncRevision > revision)
            .all()
        async let occurrences = TaskOccurrenceModel.query(on: db)
            .filter(\.$syncRevision > revision)
            .all()
        async let completions = CompletionEventModel.query(on: db)
            .filter(\.$syncRevision > revision)
            .all()

        return SyncPullResponse(
            revision: currentRevision,
            members: try await members.map(HouseholdMemberDTO.init),
            templates: try await templates.map(TaskTemplateDTO.init),
            occurrences: try await occurrences.map(TaskOccurrenceDTO.init),
            completions: try await completions.map(CompletionEventDTO.init)
        )
    }

    private func applyMembers(_ members: [HouseholdMemberDTO], on database: Database) async throws {
        for dto in members {
            if let existing = try await HouseholdMemberModel.find(dto.id, on: database) {
                guard dto.syncRevision == 0 || dto.syncRevision > existing.syncRevision else { continue }
                let revision = try await revisionService.nextRevision()
                existing.apply(dto)
                existing.syncRevision = revision
                try await existing.update(on: database)
            } else {
                let revision = try await revisionService.nextRevision()
                let model = HouseholdMemberModel(
                    id: dto.id,
                    displayName: dto.displayName,
                    emojiSymbol: dto.emojiSymbol,
                    accentColorHex: dto.accentColorHex,
                    isSelf: dto.isSelf,
                    createdAt: dto.createdAt,
                    updatedAt: dto.updatedAt,
                    syncRevision: revision
                )
                try await model.create(on: database)
            }
        }
    }

    private func applyTemplates(_ templates: [TaskTemplateDTO], on database: Database) async throws {
        for dto in templates {
            if let existing = try await TaskTemplateModel.find(dto.id, on: database) {
                guard dto.syncRevision == 0 || dto.syncRevision > existing.syncRevision else { continue }
                let revision = try await revisionService.nextRevision()
                existing.apply(dto)
                existing.syncRevision = revision
                try await existing.update(on: database)
            } else {
                let revision = try await revisionService.nextRevision()
                let model = TaskTemplateModel(
                    id: dto.id,
                    title: dto.title,
                    details: dto.details,
                    cadenceUnitRaw: dto.cadenceUnitRaw,
                    cadenceValue: dto.cadenceValue,
                    leadTimeHours: dto.leadTimeHours,
                    isActive: dto.isActive,
                    createdAt: dto.createdAt,
                    updatedAt: dto.updatedAt,
                    startDate: dto.startDate ?? dto.createdAt,
                    lastGeneratedDate: dto.lastGeneratedDate,
                    syncRevision: revision
                )
                try await model.create(on: database)
            }
        }
    }

    private func applyOccurrences(_ occurrences: [TaskOccurrenceDTO], on database: Database) async throws -> [NotificationJob] {
        var jobs: [NotificationJob] = []

        for dto in occurrences {
            if let existing = try await TaskOccurrenceModel.find(dto.id, on: database) {
                guard dto.syncRevision == 0 || dto.syncRevision > existing.syncRevision else { continue }

                let previousAssignedID = existing.assignedMemberID
                let previousStatus = existing.statusRaw

                let revision = try await revisionService.nextRevision()
                existing.apply(dto)
                existing.syncRevision = revision
                try await existing.update(on: database)

                if let template = try await TaskTemplateModel.find(dto.templateID, on: database) {
                    if previousAssignedID != dto.assignedMemberID, let memberID = dto.assignedMemberID {
                        jobs.append(.assignment(memberID: memberID, occurrence: dto, template: template))
                    }

                    if previousStatus != dto.statusRaw, dto.statusRaw != "pending" {
                        jobs.append(.completion(template: template))
                    }
                }
            } else {
                let revision = try await revisionService.nextRevision()
                let model = TaskOccurrenceModel(
                    id: dto.id,
                    templateID: dto.templateID,
                    dueDate: dto.dueDate,
                    statusRaw: dto.statusRaw,
                    assignedMemberID: dto.assignedMemberID,
                    scheduledAt: dto.scheduledAt,
                    completedAt: dto.completedAt,
                    notes: dto.notes,
                    syncRevision: revision
                )
                try await model.create(on: database)
            }
        }

        return jobs
    }

    private func applyCompletions(_ completions: [CompletionEventDTO], on database: Database) async throws {
        for dto in completions {
            guard try await CompletionEventModel.find(dto.id, on: database) == nil else {
                continue
            }

            let revision = try await revisionService.nextRevision()
            let model = CompletionEventModel(
                id: dto.id,
                occurrenceID: dto.occurrenceID,
                memberID: dto.memberID,
                timestamp: dto.timestamp,
                notes: dto.notes,
                syncRevision: revision
            )
            try await model.create(on: database)
        }
    }

    private func dispatchNotifications(_ jobs: [NotificationJob]) async {
        guard !jobs.isEmpty else { return }

        for job in jobs {
            switch job {
            case let .assignment(memberID, occurrence, template):
                do {
                    let tokens = try await DeviceTokenModel.query(on: db)
                        .filter(\.$memberID == memberID)
                        .all()
                    await notifier.sendAssignmentNotification(to: tokens, occurrence: occurrence, template: template)
                } catch {
                    logger.error("Failed to load device tokens for assignment: \(error.localizedDescription)")
                }
            case let .completion(template):
                do {
                    let tokens = try await DeviceTokenModel.query(on: db).all()
                    await notifier.sendCompletionNotification(to: tokens, template: template)
                } catch {
                    logger.error("Failed to load device tokens for completion notice: \(error.localizedDescription)")
                }
            }
        }
    }
}
