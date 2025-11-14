import Vapor

extension HouseholdMemberDTO {
    init(model: HouseholdMemberModel) throws {
        guard let id = model.id else { throw Abort(.internalServerError, reason: "Member missing identifier") }
        self.init(
            id: id,
            displayName: model.displayName,
            emojiSymbol: model.emojiSymbol,
            accentColorHex: model.accentColorHex,
            isSelf: model.isSelf,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt,
            syncRevision: model.syncRevision
        )
    }
}

extension TaskTemplateDTO {
    init(model: TaskTemplateModel) throws {
        guard let id = model.id else { throw Abort(.internalServerError, reason: "Template missing identifier") }
        self.init(
            id: id,
            title: model.title,
            details: model.details,
            cadenceUnitRaw: model.cadenceUnitRaw,
            cadenceValue: model.cadenceValue,
            leadTimeHours: model.leadTimeHours,
            isActive: model.isActive,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt,
            startDate: model.startDate ?? model.createdAt,
            lastGeneratedDate: model.lastGeneratedDate,
            syncRevision: model.syncRevision
        )
    }
}

extension TaskOccurrenceDTO {
    init(model: TaskOccurrenceModel) throws {
        guard let id = model.id else { throw Abort(.internalServerError, reason: "Occurrence missing identifier") }
        self.init(
            id: id,
            templateID: model.templateID,
            dueDate: model.dueDate,
            statusRaw: model.statusRaw,
            assignedMemberID: model.assignedMemberID,
            scheduledAt: model.scheduledAt,
            completedAt: model.completedAt,
            notes: model.notes,
            syncRevision: model.syncRevision
        )
    }
}

extension CompletionEventDTO {
    init(model: CompletionEventModel) throws {
        guard let id = model.id else { throw Abort(.internalServerError, reason: "Completion event missing identifier") }
        self.init(
            id: id,
            occurrenceID: model.occurrenceID,
            memberID: model.memberID,
            timestamp: model.timestamp,
            notes: model.notes,
            syncRevision: model.syncRevision
        )
    }
}

extension HouseholdMemberModel {
    func apply(_ dto: HouseholdMemberDTO) {
        displayName = dto.displayName
        emojiSymbol = dto.emojiSymbol
        accentColorHex = dto.accentColorHex
        isSelf = dto.isSelf
        createdAt = dto.createdAt
        updatedAt = dto.updatedAt
        syncRevision = dto.syncRevision
    }
}

extension TaskTemplateModel {
    func apply(_ dto: TaskTemplateDTO) {
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
}

extension TaskOccurrenceModel {
    func apply(_ dto: TaskOccurrenceDTO) {
        templateID = dto.templateID
        dueDate = dto.dueDate
        statusRaw = dto.statusRaw
        assignedMemberID = dto.assignedMemberID
        scheduledAt = dto.scheduledAt
        completedAt = dto.completedAt
        notes = dto.notes
        syncRevision = dto.syncRevision
    }
}

extension CompletionEventModel {
    func apply(_ dto: CompletionEventDTO) {
        occurrenceID = dto.occurrenceID
        memberID = dto.memberID
        timestamp = dto.timestamp
        notes = dto.notes
        syncRevision = dto.syncRevision
    }
}
