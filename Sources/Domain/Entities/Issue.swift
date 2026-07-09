import Foundation

struct Issue: Identifiable, Hashable, Sendable {
    let id: String
    var key: String
    var projectID: Project.ID
    var summary: String
    var status: String
    var sprintName: String?
    var sprintState: String?
    var assigneeName: String?
    var updatedAt: Date
}
