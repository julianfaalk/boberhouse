import Vapor

enum NotificationJob {
    case assignment(memberID: UUID, occurrence: TaskOccurrenceDTO, template: TaskTemplateModel)
    case completion(template: TaskTemplateModel)
}
