import Fluent
import Foundation

final class ServerRevision: Model {
    static let schema = "server_revisions"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "value")
    var value: Int64

    init() {}

    init(value: Int64) {
        self.value = value
    }
}
