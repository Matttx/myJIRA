import Foundation

struct Issue: Identifiable, Hashable, Sendable {
    let id: String
    var key: String
    var projectID: Project.ID
    var summary: String
    var status: String
    var sprintName: String?
    var sprintState: String?
    var parentID: String?
    var parentKey: String?
    var isSubtask: Bool
    var subtaskIDs: [String]
    var assigneeName: String?
    var updatedAt: Date

    init(
        id: String,
        key: String,
        projectID: Project.ID,
        summary: String,
        status: String,
        sprintName: String?,
        sprintState: String?,
        parentID: String? = nil,
        parentKey: String? = nil,
        isSubtask: Bool = false,
        subtaskIDs: [String] = [],
        assigneeName: String?,
        updatedAt: Date
    ) {
        self.id = id
        self.key = key
        self.projectID = projectID
        self.summary = summary
        self.status = status
        self.sprintName = sprintName
        self.sprintState = sprintState
        self.parentID = parentID
        self.parentKey = parentKey
        self.isSubtask = isSubtask
        self.subtaskIDs = subtaskIDs
        self.assigneeName = assigneeName
        self.updatedAt = updatedAt
    }
}
