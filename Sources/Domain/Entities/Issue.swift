import Foundation

struct IssueComment: Hashable, Sendable, Codable {
    var id: String
    var authorName: String?
    var authorAccountID: String?
    var bodyText: String
    var createdAt: Date
    var updatedAt: Date?
    var parentID: String?
}

struct IssueChange: Hashable, Sendable, Codable {
    var id: String
    var authorName: String?
    var createdAt: Date
    var fieldName: String
    var fromValue: String?
    var toValue: String?
}

struct Issue: Identifiable, Hashable, Sendable {
    let id: String
    var key: String
    var projectID: Project.ID
    var summary: String
    var status: String
    var statusCategoryKey: String?
    var descriptionText: String?
    var comments: [IssueComment]
    var changes: [IssueChange]
    var issueTypeName: String?
    var priorityName: String?
    var reporterName: String?
    var labels: [String]
    var storyPointsFieldID: String?
    var storyPoints: Double?
    var sprintID: Int?
    var sprintName: String?
    var sprintState: String?
    var parentID: String?
    var parentKey: String?
    var isSubtask: Bool
    var subtaskIDs: [String]
    var assigneeName: String?
    var createdAt: Date?
    var updatedAt: Date

    init(
        id: String,
        key: String,
        projectID: Project.ID,
        summary: String,
        status: String,
        statusCategoryKey: String? = nil,
        descriptionText: String? = nil,
        comments: [IssueComment] = [],
        changes: [IssueChange] = [],
        issueTypeName: String? = nil,
        priorityName: String? = nil,
        reporterName: String? = nil,
        labels: [String] = [],
        storyPointsFieldID: String? = nil,
        storyPoints: Double? = nil,
        sprintID: Int? = nil,
        sprintName: String?,
        sprintState: String?,
        parentID: String? = nil,
        parentKey: String? = nil,
        isSubtask: Bool = false,
        subtaskIDs: [String] = [],
        assigneeName: String?,
        createdAt: Date? = nil,
        updatedAt: Date
    ) {
        self.id = id
        self.key = key
        self.projectID = projectID
        self.summary = summary
        self.status = status
        self.statusCategoryKey = statusCategoryKey
        self.descriptionText = descriptionText
        self.comments = comments
        self.changes = changes
        self.issueTypeName = issueTypeName
        self.priorityName = priorityName
        self.reporterName = reporterName
        self.labels = labels
        self.storyPointsFieldID = storyPointsFieldID
        self.storyPoints = storyPoints
        self.sprintID = sprintID
        self.sprintName = sprintName
        self.sprintState = sprintState
        self.parentID = parentID
        self.parentKey = parentKey
        self.isSubtask = isSubtask
        self.subtaskIDs = subtaskIDs
        self.assigneeName = assigneeName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
