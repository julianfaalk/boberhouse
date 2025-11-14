import Vapor

func routes(_ app: Application) throws {
    let validator = TokenValidator()
    let syncController = SyncController(
        db: app.db,
        configuration: app.apnsConfiguration,
        logger: app.logger,
        eventLoopGroup: app.eventLoopGroup
    )
    let deviceController = DeviceController(db: app.db, logger: app.logger)

    app.get("sync") { req async throws -> SyncPullResponse in
        try validator.requireToken(on: req)
        return try await syncController.pull(req)
    }

    app.post("sync") { req async throws -> SyncPullResponse in
        try validator.requireToken(on: req)
        return try await syncController.push(req)
    }

    app.post("devices") { req async throws -> HTTPStatus in
        try validator.requireToken(on: req)
        return try await deviceController.registerToken(req)
    }

    app.delete("devices") { req async throws -> HTTPStatus in
        try validator.requireToken(on: req)
        return try await deviceController.deleteToken(req)
    }
}
