import Fluent
import Foundation
import Vapor

final class TaskTemplateModel: Model, Content {
    static let schema = "task_templates"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "title")
    var title: String

    @OptionalField(key: "details")
    var details: String?

    @Field(key: "cadence_unit_raw")
    var cadenceUnitRaw: String

    @Field(key: "cadence_value")
    var cadenceValue: Int

    @Field(key: "lead_time_hours")
    var leadTimeHours: Int

    @Field(key: "is_active")
    var isActive: Bool

    @Field(key: "created_at")
    var createdAt: Date

    @Field(key: "updated_at")
    var updatedAt: Date

    @OptionalField(key: "start_date")
    var startDate: Date?

    @OptionalField(key: "last_generated_date")
    var lastGeneratedDate: Date?

    @Field(key: "sync_revision")
    var syncRevision: Int64

    init() {}

    init(
        id: UUID?,
        title: String,
        details: String?,
        cadenceUnitRaw: String,
        cadenceValue: Int,
        leadTimeHours: Int,
        isActive: Bool,
        createdAt: Date,
        updatedAt: Date,
        startDate: Date?,
        lastGeneratedDate: Date?,
        syncRevision: Int64
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.cadenceUnitRaw = cadenceUnitRaw
        self.cadenceValue = cadenceValue
        self.leadTimeHours = leadTimeHours
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.startDate = startDate
        self.lastGeneratedDate = lastGeneratedDate
        self.syncRevision = syncRevision
    }
}
