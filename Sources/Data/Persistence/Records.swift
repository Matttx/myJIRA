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
    var sprintName: String?
    var sprintState: String?
    var assigneeName: String?
    var updatedAt: Date
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
        sprintName = issue.sprintName
        sprintState = issue.sprintState
        assigneeName = issue.assigneeName
        updatedAt = issue.updatedAt
    }

    var domainValue: Issue {
        Issue(
            id: id,
            key: key,
            projectID: projectID,
            summary: summary,
            status: status,
            sprintName: sprintName,
            sprintState: sprintState,
            assigneeName: assigneeName,
            updatedAt: updatedAt
        )
    }
}
