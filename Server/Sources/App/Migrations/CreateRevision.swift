import Fluent

struct CreateRevision: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(ServerRevision.schema)
            .id()
            .field("value", .int64, .required)
            .unique(on: "value")
            .create()
            .flatMap {
                let seed = ServerRevision(value: 0)
                return seed.create(on: database)
            }
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(ServerRevision.schema).delete()
    }
}
