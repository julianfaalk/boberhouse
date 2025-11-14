import Foundation
import UserNotifications

struct LocalNotificationScheduler {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorizationIfNeeded() async {
        let status = await center.notificationSettings()
        guard status.authorizationStatus == .notDetermined else { return }
        do {
            try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            NSLog("Notification authorization failed: \(error.localizedDescription)")
        }
    }

    func reschedule(
        occurrences: [TaskOccurrence],
        templates: [UUID: TaskTemplate],
        members: [UUID: HouseholdMember]
    ) async {
        await requestAuthorizationIfNeeded()

        let identifiers = occurrences.map { "occurrence-\($0.id.uuidString)" }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        let now = Date()

        for occurrence in occurrences where occurrence.status == .pending {
            guard let template = templates[occurrence.templateID] else { continue }

            let leadSeconds = TimeInterval(template.leadTimeHours * 3600)
            let fireDate = occurrence.dueDate.addingTimeInterval(-leadSeconds)

            guard fireDate > now else { continue }

            let content = UNMutableNotificationContent()
            content.title = template.title
            if let memberID = occurrence.assignedMemberID, let member = members[memberID] {
                content.subtitle = "Assigned to \(member.displayName)"
            }
            if let notes = occurrence.notes, !notes.isEmpty {
                content.body = notes
            } else {
                content.body = "Due at \(occurrence.dueDate.formatted(date: .abbreviated, time: .shortened))"
            }
            content.sound = .default

            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let request = UNNotificationRequest(
                identifier: "occurrence-\(occurrence.id.uuidString)",
                content: content,
                trigger: trigger
            )

            center.add(request) { error in
                if let error {
                    NSLog("Failed to schedule notification: \(error.localizedDescription)")
                }
            }
        }
    }
}
