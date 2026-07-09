import Foundation

@MainActor
@Observable
final class MainWindowViewModel {
    var workspaces: [Workspace] = []
    var issues: [Issue] = []
    var isRefreshing = false
    var isConnected = false
    var errorMessage: String?

    private let workspaceRepository: WorkspaceRepository
    private let issueRepository: IssueRepository
    private let syncService: SyncService
    private let jiraConnectionService: JiraConnectionService

    init(
        workspaceRepository: WorkspaceRepository,
        issueRepository: IssueRepository,
        syncService: SyncService,
        jiraConnectionService: JiraConnectionService
    ) {
        self.workspaceRepository = workspaceRepository
        self.issueRepository = issueRepository
        self.syncService = syncService
        self.jiraConnectionService = jiraConnectionService
    }

    func loadInitialSelection(router: AppRouter) async {
        isConnected = await jiraConnectionService.isConnected()

        guard isConnected else {
            workspaces = []
            issues = []
            return
        }

        do {
            workspaces = try await workspaceRepository.workspaces()
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        if router.selectedWorkspaceID == nil, let workspace = workspaces.first {
            router.select(workspace: workspace)
        }

        if router.selectedProjectID != nil {
            await refresh(router: router)
        } else {
            await loadIssues(router: router)
        }
    }

    func refresh(router: AppRouter) async {
        isRefreshing = true
        errorMessage = nil
        defer { isRefreshing = false }

        do {
            try await syncService.refresh(projectID: router.selectedProjectID)
            workspaces = try await workspaceRepository.workspaces()
            await loadIssues(router: router)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func connect(configuration: JiraOAuthConfiguration, router: AppRouter) async {
        isRefreshing = true
        errorMessage = nil
        defer { isRefreshing = false }

        do {
            _ = try await jiraConnectionService.connect(configuration: configuration)
            isConnected = true
            router.selectedWorkspaceID = nil
            router.selectedProjectID = nil
            router.selectedIssueID = nil
            await loadInitialSelection(router: router)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadIssues(router: AppRouter) async {
        guard let projectID = router.selectedProjectID else {
            issues = []
            return
        }

        do {
            issues = try await issueRepository.issues(projectID: projectID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func issue(id: Issue.ID?) -> Issue? {
        guard let id else { return nil }
        return issues.first { $0.id == id }
    }

    func subtasks(for issue: Issue?) -> [Issue] {
        guard let issue else { return [] }

        if !issue.subtaskIDs.isEmpty {
            return issue.subtaskIDs.compactMap { subtaskID in
                issues.first { $0.id == subtaskID }
            }
        }

        return issues
            .filter { $0.parentID == issue.id }
            .sorted { lhs, rhs in
                lhs.updatedAt > rhs.updatedAt
            }
    }

    func parent(for issue: Issue?) -> Issue? {
        guard let parentID = issue?.parentID else { return nil }
        return issues.first { $0.id == parentID }
    }

    func moveIssue(id: Issue.ID, toStatus status: String, beforeIssueID: Issue.ID?) async {
        guard id != beforeIssueID else { return }
        guard let sourceIndex = issues.firstIndex(where: { $0.id == id }) else { return }

        let previousIssues = issues
        var movedIssue = issues.remove(at: sourceIndex)
        let didChangeStatus = movedIssue.status != status
        movedIssue.status = status

        if didChangeStatus {
            movedIssue.updatedAt = Date()
        }

        if let beforeIssueID,
           let targetIndex = issues.firstIndex(where: { $0.id == beforeIssueID }) {
            issues.insert(movedIssue, at: targetIndex)
        } else if let targetIndex = issues.lastIndex(where: { $0.status == status }) {
            issues.insert(movedIssue, at: issues.index(after: targetIndex))
        } else {
            issues.append(movedIssue)
        }

        do {
            if didChangeStatus {
                try await issueRepository.updateStatus(issueID: id, status: status)
            }
        } catch {
            issues = previousIssues
            errorMessage = error.localizedDescription
        }
    }
}
