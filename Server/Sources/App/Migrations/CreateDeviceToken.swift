import Fluent

struct CreateDeviceToken: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(DeviceTokenModel.schema)
            .id()
            .field("member_id", .uuid, .required, .references(HouseholdMemberModel.schema, .id, onDelete: .cascade))
            .field("token", .string, .required)
            .field("created_at", .datetime, .required)
            .unique(on: "token")
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(DeviceTokenModel.schema).delete()
    }
}
