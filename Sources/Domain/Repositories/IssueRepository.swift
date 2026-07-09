import Foundation

protocol IssueRepository: Sendable {
    func issues(projectID: Project.ID) async throws -> [Issue]
    func issue(id: Issue.ID) async throws -> Issue?
    func refreshIssues(projectID: Project.ID) async throws
    func replaceIssues(projectID: Project.ID, issues: [Issue]) async throws
}
