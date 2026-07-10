import Foundation

protocol IssueRepository: Sendable {
    func issues(projectID: Project.ID) async throws -> [Issue]
    func issue(id: Issue.ID) async throws -> Issue?
    func refreshIssues(projectID: Project.ID) async throws
    func replaceIssues(projectID: Project.ID, issues: [Issue]) async throws
    func updateStatus(issueID: Issue.ID, status: String) async throws
    func updateSprint(issueID: Issue.ID, sprintID: Int?, sprintName: String?, sprintState: String?) async throws
    func updateStoryPoints(issueID: Issue.ID, storyPoints: Double?) async throws
    func updateChanges(issueID: Issue.ID, changes: [IssueChange]) async throws
}
