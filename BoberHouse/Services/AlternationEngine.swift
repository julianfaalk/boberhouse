import Foundation

struct AlternationEngine {
    func nextAssignee(
        for _: TaskTemplate,
        members: [HouseholdMember],
        history: [CompletionEvent],
        upcomingLoad: [UUID: Int] = [:]
    ) -> HouseholdMember? {
        guard !members.isEmpty else { return nil }

        guard let lastMemberID = history.first?.memberID else {
            return preferredMember(from: members, basedOn: upcomingLoad)
        }

        let eligible = members.filter { $0.id != lastMemberID }

        if eligible.isEmpty {
            return preferredMember(from: members, basedOn: upcomingLoad)
        }

        return preferredMember(from: eligible, basedOn: upcomingLoad)
    }

    private func preferredMember(from members: [HouseholdMember], basedOn upcomingLoad: [UUID: Int]) -> HouseholdMember? {
        members.min { lhs, rhs in
            let lhsLoad = upcomingLoad[lhs.id, default: 0]
            let rhsLoad = upcomingLoad[rhs.id, default: 0]

            if lhsLoad == rhsLoad {
                return lhs.displayName.localizedCompare(rhs.displayName) == .orderedAscending
            }

            return lhsLoad < rhsLoad
        }
    }
}
