import Fluent
import Foundation
import Vapor

final class DeviceTokenModel: Model {
    static let schema = "device_tokens"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "member_id")
    var memberID: UUID

    @Field(key: "token")
    var token: String

    @Field(key: "created_at")
    var createdAt: Date

    init() {}

    init(id: UUID? = nil, memberID: UUID, token: String, createdAt: Date = .init()) {
        self.id = id
        self.memberID = memberID
        self.token = token
        self.createdAt = createdAt
    }
}
