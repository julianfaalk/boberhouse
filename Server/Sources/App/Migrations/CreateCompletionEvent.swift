import Fluent

struct CreateCompletionEvent: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(CompletionEventModel.schema)
            .id()
            .field("occurrence_id", .uuid, .required, .references(TaskOccurrenceModel.schema, .id, onDelete: .cascade))
            .field("member_id", .uuid, .required, .references(HouseholdMemberModel.schema, .id, onDelete: .cascade))
            .field("timestamp", .datetime, .required)
            .field("notes", .string)
            .field("sync_revision", .int64, .required)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(CompletionEventModel.schema).delete()
    }
}
