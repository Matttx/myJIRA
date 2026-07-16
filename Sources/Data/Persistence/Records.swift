import Foundation
import GRDB

struct WorkspaceRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "workspaces"

    var id: String
    var name: String
    var baseURL: String
}

struct ProjectRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "projects"

    var id: String
    var key: String
    var name: String
    var workspaceID: String
}

struct IssueRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "issues"

    var id: String
    var key: String
    var projectID: String
    var summary: String
    var status: String
    var statusCategoryKey: String?
    var descriptionText: String?
    var commentsJSON: String
    var changesJSON: String
    var issueTypeName: String?
    var priorityName: String?
    var reporterName: String?
    var labelsJSON: String
    var storyPointsFieldID: String?
    var storyPoints: Double?
    var sprintID: Int?
    var sprintName: String?
    var sprintState: String?
    var parentID: String?
    var parentKey: String?
    var isSubtask: Bool
    var subtaskIDsJSON: String
    var assigneeName: String?
    var createdAt: Date?
    var updatedAt: Date
}

struct KanbanColumnOrderRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "kanbanColumnOrders"

    var projectID: String
    var status: String
    var position: Int
}

struct ProjectDisplayOrderRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "projectDisplayOrders"

    var workspaceID: String
    var projectID: String
    var position: Int
}

struct BacklogSprintOrderRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "backlogSprintOrders"

    var projectID: String
    var groupID: String
    var position: Int
}

struct BacklogCollapsedGroupRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "backlogCollapsedGroups"

    var projectID: String
    var groupID: String
}

struct BacklogSelectedSprintFilterRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "backlogSelectedSprintFilters"

    var projectID: String
    var filterID: String
}

extension WorkspaceRecord {
    init(workspace: Workspace) {
        id = workspace.id
        name = workspace.name
        baseURL = workspace.baseURL.absoluteString
    }
}

extension ProjectRecord {
    init(project: Project) {
        id = project.id
        key = project.key
        name = project.name
        workspaceID = project.workspaceID
    }

    var domainValue: Project {
        Project(id: id, key: key, name: name, workspaceID: workspaceID)
    }
}

extension IssueRecord {
    init(issue: Issue) {
        id = issue.id
        key = issue.key
        projectID = issue.projectID
        summary = issue.summary
        status = issue.status
        statusCategoryKey = issue.statusCategoryKey
        descriptionText = issue.descriptionText
        commentsJSON = (try? String(data: JSONEncoder().encode(issue.comments), encoding: .utf8)) ?? "[]"
        changesJSON = (try? String(data: JSONEncoder().encode(issue.changes), encoding: .utf8)) ?? "[]"
        issueTypeName = issue.issueTypeName
        priorityName = issue.priorityName
        reporterName = issue.reporterName
        labelsJSON = (try? String(data: JSONEncoder().encode(issue.labels), encoding: .utf8)) ?? "[]"
        storyPointsFieldID = issue.storyPointsFieldID
        storyPoints = issue.storyPoints
        sprintID = issue.sprintID
        sprintName = issue.sprintName
        sprintState = issue.sprintState
        parentID = issue.parentID
        parentKey = issue.parentKey
        isSubtask = issue.isSubtask
        subtaskIDsJSON = (try? String(data: JSONEncoder().encode(issue.subtaskIDs), encoding: .utf8)) ?? "[]"
        assigneeName = issue.assigneeName
        createdAt = issue.createdAt
        updatedAt = issue.updatedAt
    }

    var domainValue: Issue {
        let subtaskIDs = (try? JSONDecoder().decode([String].self, from: Data(subtaskIDsJSON.utf8))) ?? []
        let comments = (try? JSONDecoder().decode([IssueComment].self, from: Data(commentsJSON.utf8))) ?? []
        let changes = (try? JSONDecoder().decode([IssueChange].self, from: Data(changesJSON.utf8))) ?? []
        let labels = (try? JSONDecoder().decode([String].self, from: Data(labelsJSON.utf8))) ?? []

        return Issue(
            id: id,
            key: key,
            projectID: projectID,
            summary: summary,
            status: status,
            statusCategoryKey: statusCategoryKey,
            descriptionText: descriptionText,
            comments: comments,
            changes: changes,
            issueTypeName: issueTypeName,
            priorityName: priorityName,
            reporterName: reporterName,
            labels: labels,
            storyPointsFieldID: storyPointsFieldID,
            storyPoints: storyPoints,
            sprintID: sprintID,
            sprintName: sprintName,
            sprintState: sprintState,
            parentID: parentID,
            parentKey: parentKey,
            isSubtask: isSubtask,
            subtaskIDs: subtaskIDs,
            assigneeName: assigneeName,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
