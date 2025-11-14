import Foundation
import SwiftData

@MainActor
let previewContainer: ModelContainer = {
    do {
        let schema = Schema([
            HouseholdMember.self,
            TaskTemplate.self,
            TaskOccurrence.self,
            CompletionEvent.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        PreviewDataBootstrapper(seedCount: 6).seed(into: container.mainContext)
        return container
    } catch {
        fatalError("Failed to create preview container: \(error)")
    }
}()

struct PreviewDataBootstrapper {
    var seedCount: Int

    @MainActor
    func seed(into context: ModelContext) {
        let members = [
            HouseholdMember(displayName: "Julian", emojiSymbol: "🧑‍💻", accentColorHex: "#5B8DEF", isSelf: true),
            HouseholdMember(displayName: "Partner", emojiSymbol: "🧘‍♀️", accentColorHex: "#EF6F5B", isSelf: false)
        ]

        members.forEach(context.insert)

        let bathroom = TaskTemplate(
            title: "Clean Bathroom",
            details: "Scrub sink, shower, toilet.",
            cadenceUnit: .weeks,
            cadenceValue: 1,
            lastGeneratedDate: .now.addingTimeInterval(-14 * 86400)
        )
        bathroom.startDate = .now.addingTimeInterval(-14 * 86400)

        let windows = TaskTemplate(
            title: "Clean Windows",
            details: "Inside & outside if weather allows.",
            cadenceUnit: .months,
            cadenceValue: 3,
            lastGeneratedDate: .now.addingTimeInterval(-200 * 86400)
        )
        windows.startDate = .now.addingTimeInterval(-200 * 86400)

        [bathroom, windows].forEach(context.insert)

        let scheduler = SchedulerService()
        let horizon = Calendar.current.date(byAdding: .day, value: seedCount * 7, to: .now) ?? .now

        do {
            try scheduler.ensureOccurrences(for: bathroom, members: members, in: context, through: horizon)
            try scheduler.ensureOccurrences(for: windows, members: members, in: context, through: horizon)
            try context.save()
        } catch {
            assertionFailure("Preview generation failed: \(error)")
        }
    }
}
