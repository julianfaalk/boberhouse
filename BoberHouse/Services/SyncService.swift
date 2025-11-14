import Foundation

protocol Syncing {
    func pull(since revision: Int64) async throws -> SyncPullResponse
    func push(_ request: SyncPushRequest) async throws -> SyncPullResponse
}

struct SyncPullResponse: Codable {
    var revision: Int64
    var members: [HouseholdMemberDTO]
    var templates: [TaskTemplateDTO]
    var occurrences: [TaskOccurrenceDTO]
    var completions: [CompletionEventDTO]
}

struct SyncPushRequest: Codable {
    var baseRevision: Int64
    var members: [HouseholdMemberDTO]
    var templates: [TaskTemplateDTO]
    var occurrences: [TaskOccurrenceDTO]
    var completions: [CompletionEventDTO]
}

struct HouseholdMemberDTO: Codable, Identifiable {
    var id: UUID
    var displayName: String
    var emojiSymbol: String
    var accentColorHex: String
    var isSelf: Bool
    var createdAt: Date
    var updatedAt: Date
    var syncRevision: Int64
}

struct TaskTemplateDTO: Codable, Identifiable {
    var id: UUID
    var title: String
    var details: String?
    var cadenceUnitRaw: String
    var cadenceValue: Int
    var leadTimeHours: Int
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
    var startDate: Date?
    var lastGeneratedDate: Date?
    var syncRevision: Int64
}

struct TaskOccurrenceDTO: Codable, Identifiable {
    var id: UUID
    var templateID: UUID
    var dueDate: Date
    var statusRaw: String
    var assignedMemberID: UUID?
    var scheduledAt: Date
    var completedAt: Date?
    var notes: String?
    var syncRevision: Int64
}

struct CompletionEventDTO: Codable, Identifiable {
    var id: UUID
    var occurrenceID: UUID
    var memberID: UUID
    var timestamp: Date
    var notes: String?
    var syncRevision: Int64
}
