import Foundation

final class PollingSyncService: SyncService, @unchecked Sendable {
    private let workspaceRepository: WorkspaceRepository
    private let issueRepository: IssueRepository
    private let jiraDataService: JiraDataService

    init(
        workspaceRepository: WorkspaceRepository,
        issueRepository: IssueRepository,
        jiraDataService: JiraDataService
    ) {
        self.workspaceRepository = workspaceRepository
        self.issueRepository = issueRepository
        self.jiraDataService = jiraDataService
    }

    func refresh(projectID: Project.ID?) async throws {
        guard let projectID else {
            return
        }

        let workspaces = try await workspaceRepository.workspaces()
        guard let project = workspaces.flatMap(\.projects).first(where: { $0.id == projectID }) else {
            return
        }

        let issues = try await jiraDataService.issues(for: project)
        try await issueRepository.replaceIssues(projectID: project.id, issues: issues)
    }
}
