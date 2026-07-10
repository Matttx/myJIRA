import Foundation

protocol JiraDataService: Sendable {
    func projects(for resource: JiraAccessibleResource) async throws -> [Project]
    func issues(for project: Project) async throws -> [Issue]
    func changelog(for issue: Issue) async throws -> [IssueChange]
    func transition(issue: Issue, toStatus status: String) async throws
    func updateSprint(issue: Issue, sprintName: String?) async throws -> IssueSprintValue
    func updateStoryPoints(issue: Issue, storyPoints: Double?) async throws
}
