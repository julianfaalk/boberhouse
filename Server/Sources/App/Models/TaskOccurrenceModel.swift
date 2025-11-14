import Fluent
import Foundation
import Vapor

final class TaskOccurrenceModel: Model, Content {
    static let schema = "task_occurrences"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "template_id")
    var templateID: UUID

    @Field(key: "due_date")
    var dueDate: Date

    @Field(key: "status_raw")
    var statusRaw: String

    @OptionalField(key: "assigned_member_id")
    var assignedMemberID: UUID?

    @Field(key: "scheduled_at")
    var scheduledAt: Date

    @OptionalField(key: "completed_at")
    var completedAt: Date?

    @OptionalField(key: "notes")
    var notes: String?

    @Field(key: "sync_revision")
    var syncRevision: Int64

    init() {}

    init(
        id: UUID?,
        templateID: UUID,
        dueDate: Date,
        statusRaw: String,
        assignedMemberID: UUID?,
        scheduledAt: Date,
        completedAt: Date?,
        notes: String?,
        syncRevision: Int64
    ) {
        self.id = id
        self.templateID = templateID
        self.dueDate = dueDate
        self.statusRaw = statusRaw
        self.assignedMemberID = assignedMemberID
        self.scheduledAt = scheduledAt
        self.completedAt = completedAt
        self.notes = notes
        self.syncRevision = syncRevision
    }
}
