import Fluent

struct CreateTaskTemplate: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(TaskTemplateModel.schema)
            .id()
            .field("title", .string, .required)
            .field("details", .string)
            .field("cadence_unit_raw", .string, .required)
            .field("cadence_value", .int, .required)
            .field("lead_time_hours", .int, .required)
            .field("is_active", .bool, .required)
            .field("created_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .field("last_generated_date", .datetime)
            .field("sync_revision", .int64, .required)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(TaskTemplateModel.schema).delete()
    }
}
