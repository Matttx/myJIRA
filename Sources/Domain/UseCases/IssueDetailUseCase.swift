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

    func addComment(to issue: Issue, bodyText: String, replyTo parentComment: IssueComment?) async throws -> IssueComment {
        let comment = try await jiraDataService.addComment(issue: issue, bodyText: bodyText, replyTo: parentComment)
        var comments = issue.comments
        comments.insert(comment, at: 0)
        try await issueRepository.updateComments(issueID: issue.id, comments: comments)
        return comment
    }

    func deleteComment(_ comment: IssueComment, from issue: Issue) async throws -> Issue {
        try await jiraDataService.deleteComment(issue: issue, comment: comment)

        var updatedIssue = issue
        updatedIssue.comments.removeAll { $0.id == comment.id }
        updatedIssue.updatedAt = Date()
        try await issueRepository.updateComments(issueID: issue.id, comments: updatedIssue.comments)
        return updatedIssue
    }

    func updateSummary(for issue: Issue, summary: String) async throws -> Issue {
        let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSummary.isEmpty else {
            throw AuthError.failedTokenExchange("Issue summary cannot be empty.")
        }

        try await issueRepository.updateSummary(issueID: issue.id, summary: trimmedSummary)
        try await jiraDataService.updateSummary(issue: issue, summary: trimmedSummary)

        var updatedIssue = issue
        updatedIssue.summary = trimmedSummary
        updatedIssue.updatedAt = Date()
        return updatedIssue
    }

    func updateDescription(for issue: Issue, descriptionText: String?) async throws -> Issue {
        let trimmedDescription = descriptionText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedDescription = trimmedDescription?.isEmpty == true ? nil : trimmedDescription

        try await issueRepository.updateDescription(issueID: issue.id, descriptionText: normalizedDescription)
        try await jiraDataService.updateDescription(issue: issue, descriptionText: normalizedDescription)

        var updatedIssue = issue
        updatedIssue.descriptionText = normalizedDescription
        updatedIssue.updatedAt = Date()
        return updatedIssue
    }
}
