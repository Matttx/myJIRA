import Foundation

final class PollingSyncService: SyncService, @unchecked Sendable {
    private let workspaceRepository: WorkspaceRepository
    private let issueRepository: IssueRepository
    private let kanbanColumnOrderRepository: KanbanColumnOrderRepository
    private let jiraDataService: JiraDataService

    init(
        workspaceRepository: WorkspaceRepository,
        issueRepository: IssueRepository,
        kanbanColumnOrderRepository: KanbanColumnOrderRepository,
        jiraDataService: JiraDataService
    ) {
        self.workspaceRepository = workspaceRepository
        self.issueRepository = issueRepository
        self.kanbanColumnOrderRepository = kanbanColumnOrderRepository
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

        async let issuesRequest = jiraDataService.issues(for: project)
        async let statusesRequest = jiraDataService.statuses(for: project)
        let (issues, statuses) = try await (issuesRequest, statusesRequest)
        try await issueRepository.replaceIssues(projectID: project.id, issues: issues)
        try await kanbanColumnOrderRepository.saveAvailableStatuses(projectID: project.id, statuses: statuses)
    }
}
