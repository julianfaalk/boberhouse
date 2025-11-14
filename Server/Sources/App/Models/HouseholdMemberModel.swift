import Fluent
import Foundation
import Vapor

final class HouseholdMemberModel: Model, Content {
    static let schema = "household_members"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "display_name")
    var displayName: String

    @Field(key: "emoji_symbol")
    var emojiSymbol: String

    @Field(key: "accent_color_hex")
    var accentColorHex: String

    @Field(key: "is_self")
    var isSelf: Bool

    @Field(key: "created_at")
    var createdAt: Date

    @Field(key: "updated_at")
    var updatedAt: Date

    @Field(key: "sync_revision")
    var syncRevision: Int64

    init() {}

    init(
        id: UUID?,
        displayName: String,
        emojiSymbol: String,
        accentColorHex: String,
        isSelf: Bool,
        createdAt: Date,
        updatedAt: Date,
        syncRevision: Int64
    ) {
        self.id = id
        self.displayName = displayName
        self.emojiSymbol = emojiSymbol
        self.accentColorHex = accentColorHex
        self.isSelf = isSelf
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncRevision = syncRevision
    }
}
