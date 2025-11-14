import Fluent

struct CreateHouseholdMember: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(HouseholdMemberModel.schema)
            .id()
            .field("display_name", .string, .required)
            .field("emoji_symbol", .string, .required)
            .field("accent_color_hex", .string, .required)
            .field("is_self", .bool, .required)
            .field("created_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .field("sync_revision", .int64, .required)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(HouseholdMemberModel.schema).delete()
    }
}
