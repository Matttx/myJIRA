import Foundation

final class IssueDetailUseCase: @unchecked Sendable {
    private let issueRepository: IssueRepository
    private let jiraDataService: JiraDataService

    init(issueRepository: IssueRepository, jiraDataService: JiraDataService) {
        self.issueRepository = issueRepository
        self.jiraDataService = jiraDataService
    }

    func loadChangelog(for issue: Issue) async throws -> Issue {
        let changes = try await jiraDataService.changelog(for: issue)
        try await issueRepository.updateChanges(issueID: issue.id, changes: changes)

        var updatedIssue = issue
        updatedIssue.changes = changes
        return updatedIssue
    }
}
