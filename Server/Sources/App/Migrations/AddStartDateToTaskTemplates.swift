import Fluent

struct AddStartDateToTaskTemplates: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(TaskTemplateModel.schema)
            .field("start_date", .datetime)
            .update()
            .flatMap {
                TaskTemplateModel.query(on: database).all()
            }
            .flatMap { templates in
                templates.reduce(database.eventLoop.makeSucceededFuture(())) { result, template in
                    result.flatMap {
                        template.startDate = template.createdAt
                        return template.update(on: database)
                    }
                }
            }
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(TaskTemplateModel.schema)
            .deleteField("start_date")
            .update()
    }
}
