import Foundation
import GRDB

final class SeedDataProvider: @unchecked Sendable {
    func populate(database: AppDatabase) async throws {
        let now = Date()
        let workspace = Workspace(
            id: "local-demo",
            name: "Demo Jira Workspace",
            baseURL: URL(string: "https://example.atlassian.net")!,
            projects: []
        )
        let projects = [
            Project(id: "proj-app", key: "APP", name: "Mac App", workspaceID: workspace.id),
            Project(id: "proj-platform", key: "PLAT", name: "Platform", workspaceID: workspace.id)
        ]
        let issues = [
            Issue(id: "issue-app-1", key: "APP-1", projectID: "proj-app", summary: "Connecter OAuth Jira Cloud", status: "In Progress", sprintName: "Sprint 1", sprintState: "active", assigneeName: "Matteo", updatedAt: now),
            Issue(id: "issue-app-2", key: "APP-2", projectID: "proj-app", summary: "Persister les projets dans le cache local", status: "To Do", sprintName: "Sprint 1", sprintState: "active", assigneeName: nil, updatedAt: now.addingTimeInterval(-1800)),
            Issue(id: "issue-app-3", key: "APP-3", projectID: "proj-app", summary: "Afficher un backlog minimaliste", status: "Blocked", sprintName: nil, sprintState: nil, assigneeName: "Matteo", updatedAt: now.addingTimeInterval(-3600)),
            Issue(id: "issue-platform-1", key: "PLAT-1", projectID: "proj-platform", summary: "Préparer le polling incrémental", status: "To Do", sprintName: nil, sprintState: nil, assigneeName: nil, updatedAt: now.addingTimeInterval(-7200))
        ]

        try await database.writer.write { db in
            try WorkspaceRecord(workspace: workspace).upsert(db)
            for project in projects {
                try ProjectRecord(project: project).upsert(db)
            }
            for issue in issues {
                try IssueRecord(issue: issue).upsert(db)
            }
        }
    }
}
