import Fluent
import Foundation
import Vapor

final class CompletionEventModel: Model, Content {
    static let schema = "completion_events"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "occurrence_id")
    var occurrenceID: UUID

    @Field(key: "member_id")
    var memberID: UUID

    @Field(key: "timestamp")
    var timestamp: Date

    @OptionalField(key: "notes")
    var notes: String?

    @Field(key: "sync_revision")
    var syncRevision: Int64

    init() {}

    init(
        id: UUID?,
        occurrenceID: UUID,
        memberID: UUID,
        timestamp: Date,
        notes: String?,
        syncRevision: Int64
    ) {
        self.id = id
        self.occurrenceID = occurrenceID
        self.memberID = memberID
        self.timestamp = timestamp
        self.notes = notes
        self.syncRevision = syncRevision
    }
}
