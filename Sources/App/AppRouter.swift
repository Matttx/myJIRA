import Foundation

@Observable
final class AppRouter {
    var selectedWorkspaceID: Workspace.ID?
    var selectedProjectID: Project.ID?
    var selectedIssueID: Issue.ID?

    func select(workspace: Workspace) {
        selectedWorkspaceID = workspace.id
        selectedProjectID = workspace.projects.first?.id
        selectedIssueID = nil
    }

    func select(project: Project) {
        selectedProjectID = project.id
        selectedIssueID = nil
    }

    func select(issue: Issue) {
        selectedIssueID = issue.id
    }
}

extension Notification.Name {
    static let refreshRequested = Notification.Name("myJIRA.refreshRequested")
}
