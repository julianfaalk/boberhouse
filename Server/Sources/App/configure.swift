import Fluent
import FluentSQLiteDriver
import Vapor

public func configure(_ app: Application) throws {
    app.databases.use(.sqlite(.file(Environment.databasePath)), as: .sqlite)

    app.routes.defaultMaxBodySize = "25mb"

    app.migrations.add(CreateRevision())
    app.migrations.add(CreateHouseholdMember())
    app.migrations.add(CreateTaskTemplate())
    app.migrations.add(AddStartDateToTaskTemplates())
    app.migrations.add(CreateTaskOccurrence())
    app.migrations.add(CreateCompletionEvent())
    app.migrations.add(CreateDeviceToken())

    if let configuration = APNSConfigurationFactory.makeFromEnvironment() {
        app.apnsConfiguration = configuration
    } else {
        app.logger.warning("APNS configuration not found in environment; pushes disabled.")
    }

    try app.autoMigrate().wait()

    try routes(app)
}

extension Environment {
    static var databasePath: String {
        Environment.get("SQLITE_PATH") ?? "boberhouse.sqlite"
    }
}
