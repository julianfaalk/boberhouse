import Fluent
import Foundation
import Vapor

struct DeviceController {
    let db: Database
    let logger: Logger

    func registerToken(_ req: Request) async throws -> HTTPStatus {
        let payload = try req.content.decode(DeviceRegistrationRequest.self)

        guard try await HouseholdMemberModel.find(payload.memberID, on: db) != nil else {
            throw Abort(.badRequest, reason: "Unknown member")
        }

        if let existing = try await DeviceTokenModel.query(on: db)
            .filter(\.$token == payload.token)
            .first() {
            existing.memberID = payload.memberID
            existing.createdAt = Date()
            try await existing.update(on: db)
        } else {
            let token = DeviceTokenModel(memberID: payload.memberID, token: payload.token)
            try await token.create(on: db)
        }

        return .ok
    }

    func deleteToken(_ req: Request) async throws -> HTTPStatus {
        let payload = try req.content.decode(DeviceDeletionRequest.self)
        if let existing = try await DeviceTokenModel.query(on: db)
            .filter(\.$token == payload.token)
            .first() {
            try await existing.delete(on: db)
        }
        return .noContent
    }
}

struct DeviceRegistrationRequest: Content {
    var memberID: UUID
    var token: String
}

struct DeviceDeletionRequest: Content {
    var token: String
}
