import APNSwift
import Vapor
import Foundation

struct NotificationService {
    let configuration: APNSwiftConfiguration?
    let eventLoopGroup: EventLoopGroup
    let logger: Logger

    func sendAssignmentNotification(to tokens: [DeviceTokenModel], occurrence: TaskOccurrenceDTO, template: TaskTemplateModel) async {
        for token in tokens {
            let dueDescription = formattedDueDate(from: occurrence.dueDate)
            await send(
                token: token.token,
                title: template.title,
                body: "New assignment due \(dueDescription)"
            )
        }
    }

    func sendCompletionNotification(to tokens: [DeviceTokenModel], template: TaskTemplateModel) async {
        for token in tokens {
            await send(
                token: token.token,
                title: "Task updated",
                body: "\(template.title) status changed."
            )
        }
    }

    private func send(token: String, title: String, body: String) async {
        guard let configuration else {
            logger.debug("APNS not configured; skipping push to token \(token)")
            return
        }

        do {
            let client = try await waitFor(
                APNSwiftConnection.connect(configuration: configuration, on: eventLoopGroup.next(), logger: logger)
            )
            defer {
                client.close().whenFailure { error in
                    logger.warning("APNS client close failure: \(error.localizedDescription)")
                }
            }

            let payload = APNSwiftPayload(alert: .init(title: title, body: body), sound: .normal("default"))
            try await waitFor(client.send(payload, pushType: .alert, to: token))
        } catch {
            logger.error("APNS failure: \(error.localizedDescription)")
        }
    }

    private func formattedDueDate(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func waitFor<T>(_ future: EventLoopFuture<T>) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            future.whenComplete { result in
                continuation.resume(with: result)
            }
        }
    }
}
