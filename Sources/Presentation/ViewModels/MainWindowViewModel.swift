import Foundation

@MainActor
@Observable
final class MainWindowViewModel {
    var workspaces: [Workspace] = []
    var currentProjectViewModel: ProjectViewModel?
    var isRefreshing = false
    var isConnected = false
    var errorMessage: String?

    var currentProjectTitle: String {
        guard let selectedProjectID = currentProjectViewModel?.projectID else {
            return "myJIRA"
        }

        return workspaces
            .flatMap(\.projects)
            .first { $0.id == selectedProjectID }?
            .name ?? "myJIRA"
    }

    private let jiraSessionUseCase: JiraSessionUseCase
    private let projectIssuesUseCase: ProjectIssuesUseCase
    private let issueBoardUseCase: IssueBoardUseCase
    private let issueHierarchyUseCase: IssueHierarchyUseCase
    private let issueDetailUseCase: IssueDetailUseCase
    private let issueCreationUseCase: IssueCreationUseCase
    private let projectUsersManager: ProjectUsersManager
    private var projectViewModels: [Project.ID: ProjectViewModel] = [:]

    init(
        jiraSessionUseCase: JiraSessionUseCase,
        projectIssuesUseCase: ProjectIssuesUseCase,
        issueBoardUseCase: IssueBoardUseCase,
        issueHierarchyUseCase: IssueHierarchyUseCase,
        issueDetailUseCase: IssueDetailUseCase,
        issueCreationUseCase: IssueCreationUseCase,
        projectUsersManager: ProjectUsersManager
    ) {
        self.jiraSessionUseCase = jiraSessionUseCase
        self.projectIssuesUseCase = projectIssuesUseCase
        self.issueBoardUseCase = issueBoardUseCase
        self.issueHierarchyUseCase = issueHierarchyUseCase
        self.issueDetailUseCase = issueDetailUseCase
        self.issueCreationUseCase = issueCreationUseCase
        self.projectUsersManager = projectUsersManager
    }

    func loadInitialSelection(router: AppRouter) async {
        isConnected = await jiraSessionUseCase.isConnected()

        guard isConnected else {
            workspaces = []
            currentProjectViewModel = nil
            projectViewModels.removeAll()
            return
        }

        do {
            workspaces = try await jiraSessionUseCase.workspaces()
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        if router.selectedWorkspaceID == nil, let workspace = workspaces.first {
            router.select(workspace: workspace)
        }

        await selectProject(router.selectedProjectID)
    }

    func connect(configuration: JiraOAuthConfiguration, router: AppRouter) async {
        isRefreshing = true
        errorMessage = nil
        defer { isRefreshing = false }

        do {
            workspaces = try await jiraSessionUseCase.connect(configuration: configuration)
            isConnected = true
            projectViewModels.removeAll()
            currentProjectViewModel = nil
            router.selectedWorkspaceID = nil
            router.selectedProjectID = nil
            router.selectedIssueID = nil
            await loadInitialSelection(router: router)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshCurrentProject() async {
        guard let currentProjectViewModel else { return }

        isRefreshing = true
        errorMessage = nil
        defer { isRefreshing = false }

        await currentProjectViewModel.refresh()

        do {
            workspaces = try await jiraSessionUseCase.workspaces()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectWorkspace(_ workspace: Workspace, router: AppRouter) async {
        router.select(workspace: workspace)
        await selectProject(router.selectedProjectID)
    }

    func selectProject(_ project: Project, router: AppRouter) async {
        router.select(project: project)
        await selectProject(project.id)
    }

    func selectProject(_ projectID: Project.ID?) async {
        guard let projectID else {
            currentProjectViewModel = nil
            return
        }

        let projectViewModel = projectViewModel(for: projectID)
        currentProjectViewModel = projectViewModel

        if projectViewModel.issues.isEmpty {
            await projectViewModel.load()
        }

        await projectViewModel.loadAssignableUsersIfNeeded()
    }

    func clearGlobalError() {
        errorMessage = nil
    }

    private func projectViewModel(for projectID: Project.ID) -> ProjectViewModel {
        if let existingViewModel = projectViewModels[projectID] {
            return existingViewModel
        }

        let viewModel = ProjectViewModel(
            projectID: projectID,
            projectIssuesUseCase: projectIssuesUseCase,
            issueBoardUseCase: issueBoardUseCase,
            issueHierarchyUseCase: issueHierarchyUseCase,
            issueDetailUseCase: issueDetailUseCase,
            issueCreationUseCase: issueCreationUseCase,
            projectUsersManager: projectUsersManager
        )
        projectViewModels[projectID] = viewModel
        return viewModel
    }
}
