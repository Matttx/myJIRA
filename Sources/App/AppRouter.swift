import Foundation

@Observable
final class AppRouter {
    var selectedProjectID: Project.ID?
    var selectedIssueID: Issue.ID?

    func select(project: Project) {
        selectedProjectID = project.id
        selectedIssueID = nil
    }
}

extension Notification.Name {
    static let refreshRequested = Notification.Name("myJIRA.refreshRequested")
}
