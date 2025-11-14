import Fluent
import Vapor

struct RevisionService {
    let db: Database

    func currentRevision() async throws -> Int64 {
        if let revision = try await ServerRevision.query(on: db).first() {
            return revision.value
        }
        let seed = ServerRevision(value: 0)
        try await seed.create(on: db)
        return 0
    }

    func nextRevision() async throws -> Int64 {
        if let existing = try await ServerRevision.query(on: db).first() {
            existing.value += 1
            try await existing.save(on: db)
            return existing.value
        } else {
            let revision = ServerRevision(value: 1)
            try await revision.create(on: db)
            return 1
        }
    }
}
