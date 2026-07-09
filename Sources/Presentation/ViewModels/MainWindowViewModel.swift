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
}
