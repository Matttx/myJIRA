import Foundation

struct IssueMovePlan: Sendable {
    var previousIssues: [Issue]
    var updatedIssues: [Issue]
    var originalIssue: Issue
    var didChangeStatus: Bool
}

final class IssueBoardUseCase: @unchecked Sendable {
    private let issueRepository: IssueRepository
    private let kanbanColumnOrderRepository: KanbanColumnOrderRepository
    private let jiraDataService: JiraDataService
    private let columnOrderResolver: KanbanColumnOrderResolver

    init(
        issueRepository: IssueRepository,
        kanbanColumnOrderRepository: KanbanColumnOrderRepository,
        jiraDataService: JiraDataService,
        columnOrderResolver: KanbanColumnOrderResolver = KanbanColumnOrderResolver()
    ) {
        self.issueRepository = issueRepository
        self.kanbanColumnOrderRepository = kanbanColumnOrderRepository
        self.jiraDataService = jiraDataService
        self.columnOrderResolver = columnOrderResolver
    }

    func makeMovePlan(
        issueID: Issue.ID,
        toStatus status: String,
        beforeIssueID: Issue.ID?,
        issues: [Issue]
    ) -> IssueMovePlan? {
        guard issueID != beforeIssueID else { return nil }
        guard let sourceIndex = issues.firstIndex(where: { $0.id == issueID }) else { return nil }

        let previousIssues = issues
        let originalIssue = issues[sourceIndex]
        var nextIssues = issues
        var movedIssue = nextIssues.remove(at: sourceIndex)
        let didChangeStatus = movedIssue.status != status
        movedIssue.status = status

        if didChangeStatus {
            movedIssue.updatedAt = Date()
        }

        if let beforeIssueID,
           let targetIndex = nextIssues.firstIndex(where: { $0.id == beforeIssueID }) {
            nextIssues.insert(movedIssue, at: targetIndex)
        } else if let targetIndex = nextIssues.lastIndex(where: { $0.status == status }) {
            nextIssues.insert(movedIssue, at: nextIssues.index(after: targetIndex))
        } else {
            nextIssues.append(movedIssue)
        }

        return IssueMovePlan(
            previousIssues: previousIssues,
            updatedIssues: nextIssues,
            originalIssue: originalIssue,
            didChangeStatus: didChangeStatus
        )
    }

    func commitMove(_ plan: IssueMovePlan, toStatus status: String) async throws {
        guard plan.didChangeStatus else { return }

        try await issueRepository.updateStatus(issueID: plan.originalIssue.id, status: status)
        try await jiraDataService.transition(issue: plan.originalIssue, toStatus: status)
    }

    func rollbackMove(_ plan: IssueMovePlan) async {
        try? await issueRepository.updateStatus(issueID: plan.originalIssue.id, status: plan.originalIssue.status)
    }

    func commitSprintChange(issue: Issue, sprintName: String?) async throws -> Issue {
        let sprintValue = try await jiraDataService.updateSprint(issue: issue, sprintName: sprintName)
        try await issueRepository.updateSprint(
            issueID: issue.id,
            sprintID: sprintValue.id,
            sprintName: sprintValue.name,
            sprintState: sprintValue.state
        )

        var updatedIssue = issue
        updatedIssue.sprintID = sprintValue.id
        updatedIssue.sprintName = sprintValue.name
        updatedIssue.sprintState = sprintValue.state
        updatedIssue.updatedAt = Date()
        return updatedIssue
    }

    func rollbackSprintChange(issue: Issue) async {
        try? await issueRepository.updateSprint(
            issueID: issue.id,
            sprintID: issue.sprintID,
            sprintName: issue.sprintName,
            sprintState: issue.sprintState
        )
    }

    func commitStoryPointsChange(issue: Issue, storyPoints: Double?) async throws -> Issue {
        try await issueRepository.updateStoryPoints(issueID: issue.id, storyPoints: storyPoints)
        try await jiraDataService.updateStoryPoints(issue: issue, storyPoints: storyPoints)

        var updatedIssue = issue
        updatedIssue.storyPoints = storyPoints
        updatedIssue.updatedAt = Date()
        return updatedIssue
    }

    func rollbackStoryPointsChange(issue: Issue) async {
        try? await issueRepository.updateStoryPoints(issueID: issue.id, storyPoints: issue.storyPoints)
    }

    func commitAssignToCurrentUser(issue: Issue) async throws -> Issue {
        let user = try await jiraDataService.assignIssueToCurrentUser(issue: issue)
        try await issueRepository.updateAssignee(issueID: issue.id, assigneeName: user.displayName)

        var updatedIssue = issue
        updatedIssue.assigneeName = user.displayName
        updatedIssue.updatedAt = Date()
        return updatedIssue
    }

    func commitAssign(issue: Issue, to user: JiraUser) async throws -> Issue {
        try await jiraDataService.assignIssue(issue: issue, to: user)
        try await issueRepository.updateAssignee(issueID: issue.id, assigneeName: user.displayName)

        var updatedIssue = issue
        updatedIssue.assigneeName = user.displayName
        updatedIssue.updatedAt = Date()
        return updatedIssue
    }

    func commitUnassign(issue: Issue) async throws -> Issue {
        try await jiraDataService.unassignIssue(issue: issue)
        try await issueRepository.updateAssignee(issueID: issue.id, assigneeName: nil)

        var updatedIssue = issue
        updatedIssue.assigneeName = nil
        updatedIssue.updatedAt = Date()
        return updatedIssue
    }

    func rollbackAssignee(issue: Issue) async {
        try? await issueRepository.updateAssignee(issueID: issue.id, assigneeName: issue.assigneeName)
    }

    func commitDeleteIssue(_ issue: Issue, deleteSubtasks: Bool) async throws {
        try await issueRepository.deleteIssue(issueID: issue.id)
        if let parentID = issue.parentID,
           var parentIssue = try await issueRepository.issue(id: parentID) {
            parentIssue.subtaskIDs.removeAll { $0 == issue.id }
            parentIssue.updatedAt = Date()
            try await issueRepository.upsertIssue(parentIssue)
        }

        if deleteSubtasks {
            for subtaskID in issue.subtaskIDs {
                try await issueRepository.deleteIssue(issueID: subtaskID)
            }
        }
        try await jiraDataService.deleteIssue(issue, deleteSubtasks: deleteSubtasks)
    }

    func rollbackDeleteIssues(_ issues: [Issue]) async {
        for issue in issues {
            try? await issueRepository.upsertIssue(issue)
        }
    }

    func moveColumn(
        _ title: String,
        before beforeTitle: String?,
        projectID: Project.ID?,
        currentOrder: [String],
        issues: [Issue]
    ) async throws -> [String]? {
        guard let projectID else { return nil }

        var nextOrder = columnOrderResolver.mergedColumnOrder(currentOrder, issues: issues)
        guard let sourceIndex = nextOrder.firstIndex(of: title) else { return nil }

        nextOrder.remove(at: sourceIndex)

        if let beforeTitle, let targetIndex = nextOrder.firstIndex(of: beforeTitle) {
            nextOrder.insert(title, at: targetIndex)
        } else {
            nextOrder.append(title)
        }

        try await kanbanColumnOrderRepository.saveColumnOrder(projectID: projectID, statuses: nextOrder)
        return nextOrder
    }
}
