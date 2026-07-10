import Foundation

struct ProjectIssuesSnapshot: Sendable {
    var issues: [Issue]
    var kanbanColumnOrder: [String]
}

final class ProjectIssuesUseCase: @unchecked Sendable {
    private let issueRepository: IssueRepository
    private let kanbanColumnOrderRepository: KanbanColumnOrderRepository
    private let syncService: SyncService
    private let columnOrderResolver: KanbanColumnOrderResolver

    init(
        issueRepository: IssueRepository,
        kanbanColumnOrderRepository: KanbanColumnOrderRepository,
        syncService: SyncService,
        columnOrderResolver: KanbanColumnOrderResolver = KanbanColumnOrderResolver()
    ) {
        self.issueRepository = issueRepository
        self.kanbanColumnOrderRepository = kanbanColumnOrderRepository
        self.syncService = syncService
        self.columnOrderResolver = columnOrderResolver
    }

    func load(projectID: Project.ID?) async throws -> ProjectIssuesSnapshot {
        guard let projectID else {
            return ProjectIssuesSnapshot(issues: [], kanbanColumnOrder: [])
        }

        let issues = try await issueRepository.issues(projectID: projectID)
        let savedOrder = try await kanbanColumnOrderRepository.columnOrder(projectID: projectID)

        return ProjectIssuesSnapshot(
            issues: issues,
            kanbanColumnOrder: columnOrderResolver.mergedColumnOrder(savedOrder, issues: issues)
        )
    }

    func refresh(projectID: Project.ID?) async throws -> ProjectIssuesSnapshot {
        try await syncService.refresh(projectID: projectID)
        return try await load(projectID: projectID)
    }
}
