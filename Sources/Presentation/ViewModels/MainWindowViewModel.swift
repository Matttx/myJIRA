import Foundation

@MainActor
@Observable
final class MainWindowViewModel {
    var workspaces: [Workspace] = []
    var issues: [Issue] = []
    var kanbanColumnOrder: [String] = []
    var isRefreshing = false
    var isConnected = false
    var errorMessage: String?

    private let jiraSessionUseCase: JiraSessionUseCase
    private let projectIssuesUseCase: ProjectIssuesUseCase
    private let issueBoardUseCase: IssueBoardUseCase
    private let issueHierarchyUseCase: IssueHierarchyUseCase
    private let issueDetailUseCase: IssueDetailUseCase
    private var loadedChangelogIssueIDs: Set<Issue.ID> = []
    private var loadingChangelogIssueIDs: Set<Issue.ID> = []

    init(
        jiraSessionUseCase: JiraSessionUseCase,
        projectIssuesUseCase: ProjectIssuesUseCase,
        issueBoardUseCase: IssueBoardUseCase,
        issueHierarchyUseCase: IssueHierarchyUseCase,
        issueDetailUseCase: IssueDetailUseCase
    ) {
        self.jiraSessionUseCase = jiraSessionUseCase
        self.projectIssuesUseCase = projectIssuesUseCase
        self.issueBoardUseCase = issueBoardUseCase
        self.issueHierarchyUseCase = issueHierarchyUseCase
        self.issueDetailUseCase = issueDetailUseCase
    }

    func loadInitialSelection(router: AppRouter) async {
        isConnected = await jiraSessionUseCase.isConnected()

        guard isConnected else {
            workspaces = []
            issues = []
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
            apply(try await projectIssuesUseCase.refresh(projectID: router.selectedProjectID))
            workspaces = try await jiraSessionUseCase.workspaces()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func connect(configuration: JiraOAuthConfiguration, router: AppRouter) async {
        isRefreshing = true
        errorMessage = nil
        defer { isRefreshing = false }

        do {
            workspaces = try await jiraSessionUseCase.connect(configuration: configuration)
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
        do {
            apply(try await projectIssuesUseCase.load(projectID: router.selectedProjectID))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func issue(id: Issue.ID?) -> Issue? {
        issueHierarchyUseCase.issue(id: id, in: issues)
    }

    func subtasks(for issue: Issue?) -> [Issue] {
        issueHierarchyUseCase.subtasks(for: issue, in: issues)
    }

    func parent(for issue: Issue?) -> Issue? {
        issueHierarchyUseCase.parent(for: issue, in: issues)
    }

    func isLoadingChangelog(for issueID: Issue.ID?) -> Bool {
        guard let issueID else { return false }
        return loadingChangelogIssueIDs.contains(issueID)
    }

    func loadChangelogIfNeeded(issueID: Issue.ID?) async {
        guard let issueID,
              !loadedChangelogIssueIDs.contains(issueID),
              !loadingChangelogIssueIDs.contains(issueID),
              let issue = issue(id: issueID)
        else { return }

        loadingChangelogIssueIDs.insert(issueID)
        defer { loadingChangelogIssueIDs.remove(issueID) }

        do {
            let updatedIssue = try await issueDetailUseCase.loadChangelog(for: issue)
            loadedChangelogIssueIDs.insert(issueID)

            if let index = issues.firstIndex(where: { $0.id == issueID }) {
                issues[index] = updatedIssue
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func moveIssue(id: Issue.ID, toStatus status: String, beforeIssueID: Issue.ID?) async {
        guard let plan = issueBoardUseCase.makeMovePlan(
            issueID: id,
            toStatus: status,
            beforeIssueID: beforeIssueID,
            issues: issues
        ) else { return }

        issues = plan.updatedIssues

        do {
            try await issueBoardUseCase.commitMove(plan, toStatus: status)
        } catch {
            issues = plan.previousIssues
            await issueBoardUseCase.rollbackMove(plan)
            errorMessage = error.localizedDescription
        }
    }

    func updateSprint(issueID: Issue.ID, sprintName: String?) async {
        guard let index = issues.firstIndex(where: { $0.id == issueID }) else { return }

        let originalIssue = issues[index]
        let normalizedSprintName = normalizedSprintName(sprintName)

        var optimisticIssue = originalIssue
        optimisticIssue.sprintID = normalizedSprintName == nil ? nil : originalIssue.sprintID
        optimisticIssue.sprintName = normalizedSprintName
        optimisticIssue.sprintState = normalizedSprintName == nil ? nil : originalIssue.sprintState
        optimisticIssue.updatedAt = Date()
        issues[index] = optimisticIssue

        do {
            let updatedIssue = try await issueBoardUseCase.commitSprintChange(
                issue: originalIssue,
                sprintName: normalizedSprintName
            )

            if let currentIndex = issues.firstIndex(where: { $0.id == issueID }) {
                issues[currentIndex] = updatedIssue
            }
        } catch {
            if let currentIndex = issues.firstIndex(where: { $0.id == issueID }) {
                issues[currentIndex] = originalIssue
            }
            await issueBoardUseCase.rollbackSprintChange(issue: originalIssue)
            errorMessage = error.localizedDescription
        }
    }

    func updateStoryPoints(issueID: Issue.ID, storyPoints: Double?) async {
        guard let index = issues.firstIndex(where: { $0.id == issueID }) else { return }

        let originalIssue = issues[index]
        var optimisticIssue = originalIssue
        optimisticIssue.storyPoints = storyPoints
        optimisticIssue.updatedAt = Date()
        issues[index] = optimisticIssue

        do {
            let updatedIssue = try await issueBoardUseCase.commitStoryPointsChange(
                issue: originalIssue,
                storyPoints: storyPoints
            )

            if let currentIndex = issues.firstIndex(where: { $0.id == issueID }) {
                issues[currentIndex] = updatedIssue
            }
        } catch {
            if let currentIndex = issues.firstIndex(where: { $0.id == issueID }) {
                issues[currentIndex] = originalIssue
            }
            await issueBoardUseCase.rollbackStoryPointsChange(issue: originalIssue)
            errorMessage = error.localizedDescription
        }
    }

    func moveKanbanColumn(_ title: String, before beforeTitle: String?, projectID: Project.ID?) async {
        do {
            if let nextOrder = try await issueBoardUseCase.moveColumn(
                title,
                before: beforeTitle,
                projectID: projectID,
                currentOrder: kanbanColumnOrder,
                issues: issues
            ) {
                kanbanColumnOrder = nextOrder
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func apply(_ snapshot: ProjectIssuesSnapshot) {
        issues = snapshot.issues
        kanbanColumnOrder = snapshot.kanbanColumnOrder
    }

    private func normalizedSprintName(_ sprintName: String?) -> String? {
        let trimmed = sprintName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty, trimmed.localizedCaseInsensitiveCompare("Backlog") != .orderedSame else {
            return nil
        }
        return trimmed
    }
}
