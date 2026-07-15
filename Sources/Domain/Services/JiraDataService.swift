import Foundation

protocol JiraDataService: Sendable {
    func projects(for resource: JiraAccessibleResource) async throws -> [Project]
    func issues(for project: Project) async throws -> [Issue]
    func issueTypes(for project: Project) async throws -> [IssueTypeMetadata]
    func creationMetadata(for project: Project, issueTypeID: IssueTypeMetadata.ID) async throws -> IssueCreationMetadata
    func createIssue(in project: Project, draft: IssueCreationDraft) async throws -> CreatedIssue
    func currentUser(cloudID: String) async throws -> JiraUser
    func assignableUsers(for project: Project) async throws -> [JiraUser]
    func assignIssueToCurrentUser(issue: Issue) async throws -> JiraUser
    func assignIssue(issue: Issue, to user: JiraUser) async throws
    func unassignIssue(issue: Issue) async throws
    func changelog(for issue: Issue) async throws -> [IssueChange]
    func addComment(issue: Issue, bodyText: String, replyTo comment: IssueComment?) async throws -> IssueComment
    func deleteComment(issue: Issue, comment: IssueComment) async throws
    func deleteIssue(_ issue: Issue, deleteSubtasks: Bool) async throws
    func transition(issue: Issue, toStatus status: String) async throws
    func updateSprint(issue: Issue, sprintName: String?) async throws -> IssueSprintValue
    func updateStoryPoints(issue: Issue, storyPoints: Double?) async throws
    func updateSummary(issue: Issue, summary: String) async throws
    func updateDescription(issue: Issue, descriptionText: String?) async throws
}
