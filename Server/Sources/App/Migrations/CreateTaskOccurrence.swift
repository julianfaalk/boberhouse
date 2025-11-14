import Fluent

struct CreateTaskOccurrence: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(TaskOccurrenceModel.schema)
            .id()
            .field("template_id", .uuid, .required, .references(TaskTemplateModel.schema, .id, onDelete: .cascade))
            .field("due_date", .datetime, .required)
            .field("status_raw", .string, .required)
            .field("assigned_member_id", .uuid)
            .field("scheduled_at", .datetime, .required)
            .field("completed_at", .datetime)
            .field("notes", .string)
            .field("sync_revision", .int64, .required)
            .unique(on: "id")
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(TaskOccurrenceModel.schema).delete()
    }
}
