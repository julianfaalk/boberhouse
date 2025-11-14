import Foundation
import SwiftData

enum CadenceUnit: String, Codable, CaseIterable {
    case days
    case weeks
    case months

    var localizedLabel: String {
        switch self {
        case .days: return "Days"
        case .weeks: return "Weeks"
        case .months: return "Months"
        }
    }
}

enum TaskOccurrenceStatus: String, Codable, CaseIterable {
    case pending
    case skipped
    case completed

    var isTerminal: Bool {
        switch self {
        case .pending: return false
        case .skipped, .completed: return true
        }
    }
}

@Model
final class HouseholdMember {
    @Attribute(.unique) var id: UUID
    var displayName: String
    var emojiSymbol: String
    var accentColorHex: String
    var createdAt: Date
    var updatedAt: Date
    var isSelf: Bool
    var syncRevision: Int64

    init(
        id: UUID = UUID(),
        displayName: String,
        emojiSymbol: String,
        accentColorHex: String,
        isSelf: Bool,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        syncRevision: Int64 = 0
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

@Model
final class TaskTemplate {
    @Attribute(.unique) var id: UUID
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

    var cadenceUnit: CadenceUnit {
        get { CadenceUnit(rawValue: cadenceUnitRaw) ?? .weeks }
        set { cadenceUnitRaw = newValue.rawValue }
    }

    var cadenceInterval: DateComponents {
        switch cadenceUnit {
        case .days:
            return DateComponents(day: cadenceValue)
        case .weeks:
            return DateComponents(day: cadenceValue * 7)
        case .months:
            return DateComponents(month: cadenceValue)
        }
    }

    init(
        id: UUID = UUID(),
        title: String,
        details: String? = nil,
        cadenceUnit: CadenceUnit,
        cadenceValue: Int,
        leadTimeHours: Int = 12,
        isActive: Bool = true,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        startDate: Date? = nil,
        lastGeneratedDate: Date? = nil,
        syncRevision: Int64 = 0
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.cadenceUnitRaw = cadenceUnit.rawValue
        self.cadenceValue = cadenceValue
        self.leadTimeHours = leadTimeHours
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.startDate = startDate
        self.lastGeneratedDate = lastGeneratedDate
        self.syncRevision = syncRevision
    }
}

@Model
final class TaskOccurrence {
    @Attribute(.unique) var id: UUID
    var dueDate: Date
    var statusRaw: String
    var assignedMemberID: UUID?
    var templateID: UUID
    var scheduledAt: Date
    var completedAt: Date?
    var notes: String?
    var syncRevision: Int64

    var status: TaskOccurrenceStatus {
        get { TaskOccurrenceStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        dueDate: Date,
        status: TaskOccurrenceStatus = .pending,
        assignedMemberID: UUID? = nil,
        templateID: UUID,
        scheduledAt: Date = .now,
        completedAt: Date? = nil,
        notes: String? = nil,
        syncRevision: Int64 = 0
    ) {
        self.id = id
        self.dueDate = dueDate
        self.statusRaw = status.rawValue
        self.assignedMemberID = assignedMemberID
        self.templateID = templateID
        self.scheduledAt = scheduledAt
        self.completedAt = completedAt
        self.notes = notes
        self.syncRevision = syncRevision
    }
}

@Model
final class CompletionEvent {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var memberID: UUID
    var notes: String?
    var syncRevision: Int64

    var occurrenceID: UUID

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        memberID: UUID,
        occurrenceID: UUID,
        notes: String? = nil,
        syncRevision: Int64 = 0
    ) {
        self.id = id
        self.timestamp = timestamp
        self.memberID = memberID
        self.occurrenceID = occurrenceID
        self.notes = notes
        self.syncRevision = syncRevision
    }
}
