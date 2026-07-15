import Foundation

protocol JiraDataService: Sendable {
    func projects(for resource: JiraAccessibleResource) async throws -> [Project]
    func issues(for project: Project) async throws -> [Issue]
    func issueTypes(for project: Project) async throws -> [IssueTypeMetadata]
    func creationMetadata(for project: Project, issueTypeID: IssueTypeMetadata.ID) async throws -> IssueCreationMetadata
    func createIssue(in project: Project, draft: IssueCreationDraft) async throws -> CreatedIssue
    func currentUser(cloudID: String) async throws -> JiraUser
    func assignIssueToCurrentUser(issue: Issue) async throws -> JiraUser
    func changelog(for issue: Issue) async throws -> [IssueChange]
    func transition(issue: Issue, toStatus status: String) async throws
    func updateSprint(issue: Issue, sprintName: String?) async throws -> IssueSprintValue
    func updateStoryPoints(issue: Issue, storyPoints: Double?) async throws
}
