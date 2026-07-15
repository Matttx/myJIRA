import Foundation

@MainActor
@Observable
final class ProjectViewModel {
    let projectID: Project.ID

    var issues: [Issue] = []
    var kanbanColumnOrder: [String] = []
    var issueTypes: [IssueTypeMetadata] = []
    var subtaskIssueTypes: [IssueTypeMetadata] = []
    var creationMetadata: IssueCreationMetadata?
    var currentUser: JiraUser?
    var assignableUsers: [JiraUser] = []
    var isRefreshing = false
    var isLoadingIssueCreation = false
    var isLoadingAssignableUsers = false
    var isCreatingIssue = false
    var errorMessage: String?

    private let projectIssuesUseCase: ProjectIssuesUseCase
    private let issueBoardUseCase: IssueBoardUseCase
    private let issueHierarchyUseCase: IssueHierarchyUseCase
    private let issueDetailUseCase: IssueDetailUseCase
    private let issueCreationUseCase: IssueCreationUseCase
    private let projectUsersManager: ProjectUsersManager
    private var loadedChangelogIssueIDs: Set<Issue.ID> = []
    private var loadingChangelogIssueIDs: Set<Issue.ID> = []
    private var addingCommentIssueIDs: Set<Issue.ID> = []

    init(
        projectID: Project.ID,
        projectIssuesUseCase: ProjectIssuesUseCase,
        issueBoardUseCase: IssueBoardUseCase,
        issueHierarchyUseCase: IssueHierarchyUseCase,
        issueDetailUseCase: IssueDetailUseCase,
        issueCreationUseCase: IssueCreationUseCase,
        projectUsersManager: ProjectUsersManager
    ) {
        self.projectID = projectID
        self.projectIssuesUseCase = projectIssuesUseCase
        self.issueBoardUseCase = issueBoardUseCase
        self.issueHierarchyUseCase = issueHierarchyUseCase
        self.issueDetailUseCase = issueDetailUseCase
        self.issueCreationUseCase = issueCreationUseCase
        self.projectUsersManager = projectUsersManager
    }

    func load() async {
        do {
            apply(try await projectIssuesUseCase.load(projectID: projectID))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh() async {
        isRefreshing = true
        errorMessage = nil
        defer { isRefreshing = false }

        do {
            apply(try await projectIssuesUseCase.refresh(projectID: projectID))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadIssueCreationOptions() async {
        isLoadingIssueCreation = true
        errorMessage = nil
        defer { isLoadingIssueCreation = false }

        do {
            let types = try await issueCreationUseCase.issueTypes(projectID: projectID)
            issueTypes = types
            subtaskIssueTypes = try await issueCreationUseCase.subtaskIssueTypes(projectID: projectID)
            currentUser = try? await issueCreationUseCase.currentUser(projectID: projectID)
            try? await loadAssignableUsers(forceRefresh: false)

            if let firstType = types.first {
                creationMetadata = try await issueCreationUseCase.creationMetadata(
                    projectID: projectID,
                    issueTypeID: firstType.id
                )
            } else {
                creationMetadata = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadCreationMetadata(issueTypeID: IssueTypeMetadata.ID) async {
        isLoadingIssueCreation = true
        errorMessage = nil
        defer { isLoadingIssueCreation = false }

        do {
            creationMetadata = try await issueCreationUseCase.creationMetadata(
                projectID: projectID,
                issueTypeID: issueTypeID
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createIssue(draft: IssueCreationDraft) async -> Issue? {
        isCreatingIssue = true
        errorMessage = nil
        defer { isCreatingIssue = false }

        do {
            let issueTypeName = issueTypes.first(where: { $0.id == draft.issueTypeID })?.name
            let sprintContext = sprintContext(for: draft.targetSprintID)
            let assigneeName = try await assigneeNameIfNeeded(draft: draft)
            let createdIssue = try await issueCreationUseCase.createIssue(
                projectID: projectID,
                draft: draft,
                issueTypeName: issueTypeName,
                defaultStatus: defaultIssueStatus,
                targetSprintName: sprintContext.name,
                targetSprintState: sprintContext.state,
                assigneeName: assigneeName
            )

            insertOrReplaceLocalIssue(createdIssue)
            return createdIssue
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func loadSubtaskCreationOptionsIfNeeded() async {
        guard subtaskIssueTypes.isEmpty else { return }

        isLoadingIssueCreation = true
        errorMessage = nil
        defer { isLoadingIssueCreation = false }

        do {
            subtaskIssueTypes = try await issueCreationUseCase.subtaskIssueTypes(projectID: projectID)
            currentUser = try? await issueCreationUseCase.currentUser(projectID: projectID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createSubtask(parentIssueID: Issue.ID, draft: IssueCreationDraft) async -> Issue? {
        guard let parentIssue = issue(id: parentIssueID) else { return nil }

        isCreatingIssue = true
        errorMessage = nil
        defer { isCreatingIssue = false }

        do {
            let issueTypeName = subtaskIssueTypes.first(where: { $0.id == draft.issueTypeID })?.name
            let assigneeName = try await assigneeNameIfNeeded(draft: draft)
            let createdSubtask = try await issueCreationUseCase.createSubtask(
                projectID: projectID,
                parentIssue: parentIssue,
                draft: draft,
                issueTypeName: issueTypeName,
                defaultStatus: defaultIssueStatus,
                assigneeName: assigneeName
            )

            insertOrReplaceLocalIssue(createdSubtask)
            if let parentIndex = issues.firstIndex(where: { $0.id == parentIssueID }),
               !issues[parentIndex].subtaskIDs.contains(createdSubtask.id) {
                issues[parentIndex].subtaskIDs.append(createdSubtask.id)
                issues[parentIndex].updatedAt = Date()
            }

            return createdSubtask
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func assignIssueToCurrentUser(issueID: Issue.ID) async {
        guard let index = issues.firstIndex(where: { $0.id == issueID }) else { return }

        let originalIssue = issues[index]
        let optimisticName = currentUser?.displayName ?? "Me"
        var optimisticIssue = originalIssue
        optimisticIssue.assigneeName = optimisticName
        optimisticIssue.updatedAt = Date()
        issues[index] = optimisticIssue

        do {
            let updatedIssue = try await issueBoardUseCase.commitAssignToCurrentUser(issue: originalIssue)
            currentUser = JiraUser(accountID: currentUser?.accountID ?? "", displayName: updatedIssue.assigneeName ?? optimisticName)

            if let currentIndex = issues.firstIndex(where: { $0.id == issueID }) {
                issues[currentIndex] = updatedIssue
            }
        } catch {
            if let currentIndex = issues.firstIndex(where: { $0.id == issueID }) {
                issues[currentIndex] = originalIssue
            }
            await issueBoardUseCase.rollbackAssignee(issue: originalIssue)
            errorMessage = error.localizedDescription
        }
    }

    func loadAssignableUsersIfNeeded(forceRefresh: Bool = false) async {
        guard forceRefresh || assignableUsers.isEmpty else { return }

        do {
            try await loadAssignableUsers(forceRefresh: forceRefresh)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func assignIssue(issueID: Issue.ID, to user: JiraUser) async {
        guard let index = issues.firstIndex(where: { $0.id == issueID }) else { return }

        let originalIssue = issues[index]
        var optimisticIssue = originalIssue
        optimisticIssue.assigneeName = user.displayName
        optimisticIssue.updatedAt = Date()
        issues[index] = optimisticIssue

        do {
            let updatedIssue = try await issueBoardUseCase.commitAssign(issue: originalIssue, to: user)

            if let currentIndex = issues.firstIndex(where: { $0.id == issueID }) {
                issues[currentIndex] = updatedIssue
            }
        } catch {
            if let currentIndex = issues.firstIndex(where: { $0.id == issueID }) {
                issues[currentIndex] = originalIssue
            }
            await issueBoardUseCase.rollbackAssignee(issue: originalIssue)
            errorMessage = error.localizedDescription
        }
    }

    func unassignIssue(issueID: Issue.ID) async {
        guard let index = issues.firstIndex(where: { $0.id == issueID }) else { return }

        let originalIssue = issues[index]
        var optimisticIssue = originalIssue
        optimisticIssue.assigneeName = nil
        optimisticIssue.updatedAt = Date()
        issues[index] = optimisticIssue

        do {
            let updatedIssue = try await issueBoardUseCase.commitUnassign(issue: originalIssue)

            if let currentIndex = issues.firstIndex(where: { $0.id == issueID }) {
                issues[currentIndex] = updatedIssue
            }
        } catch {
            if let currentIndex = issues.firstIndex(where: { $0.id == issueID }) {
                issues[currentIndex] = originalIssue
            }
            await issueBoardUseCase.rollbackAssignee(issue: originalIssue)
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

    func isAddingComment(to issueID: Issue.ID?) -> Bool {
        guard let issueID else { return false }
        return addingCommentIssueIDs.contains(issueID)
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

    func addComment(issueID: Issue.ID, bodyText: String, replyTo parentComment: IssueComment? = nil) async -> Bool {
        let trimmedBody = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBody.isEmpty,
              !addingCommentIssueIDs.contains(issueID),
              let index = issues.firstIndex(where: { $0.id == issueID })
        else { return false }

        addingCommentIssueIDs.insert(issueID)
        defer { addingCommentIssueIDs.remove(issueID) }

        let originalIssue = issues[index]
        let optimisticComment = IssueComment(
            id: "local-\(UUID().uuidString)",
            authorName: currentUser?.displayName ?? "Me",
            authorAccountID: currentUser?.accountID,
            bodyText: trimmedBody,
            createdAt: Date(),
            updatedAt: nil,
            parentID: parentComment?.id
        )

        var optimisticIssue = originalIssue
        optimisticIssue.comments.insert(optimisticComment, at: 0)
        optimisticIssue.updatedAt = Date()
        issues[index] = optimisticIssue

        do {
            let jiraComment = try await issueDetailUseCase.addComment(
                to: originalIssue,
                bodyText: trimmedBody,
                replyTo: parentComment
            )

            if let currentIndex = issues.firstIndex(where: { $0.id == issueID }) {
                var updatedIssue = issues[currentIndex]
                if let optimisticIndex = updatedIssue.comments.firstIndex(where: { $0.id == optimisticComment.id }) {
                    updatedIssue.comments[optimisticIndex] = jiraComment
                } else if updatedIssue.comments.contains(where: { $0.id == jiraComment.id }) == false {
                    updatedIssue.comments.insert(jiraComment, at: 0)
                }
                updatedIssue.updatedAt = Date()
                issues[currentIndex] = updatedIssue
            }

            return true
        } catch {
            if let currentIndex = issues.firstIndex(where: { $0.id == issueID }) {
                issues[currentIndex] = originalIssue
            }
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteComment(issueID: Issue.ID, commentID: String) async {
        guard let index = issues.firstIndex(where: { $0.id == issueID }),
              let comment = issues[index].comments.first(where: { $0.id == commentID })
        else { return }

        let originalIssue = issues[index]
        var optimisticIssue = originalIssue
        optimisticIssue.comments.removeAll { $0.id == commentID }
        optimisticIssue.updatedAt = Date()
        issues[index] = optimisticIssue

        do {
            let updatedIssue = try await issueDetailUseCase.deleteComment(comment, from: originalIssue)
            if let currentIndex = issues.firstIndex(where: { $0.id == issueID }) {
                issues[currentIndex] = updatedIssue
            }
        } catch {
            if let currentIndex = issues.firstIndex(where: { $0.id == issueID }) {
                issues[currentIndex] = originalIssue
            }
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func deleteIssue(issueID: Issue.ID) async -> Set<Issue.ID> {
        guard let issue = issue(id: issueID) else { return [] }

        let deleteSubtasks = issue.subtaskIDs.isEmpty == false
        let deletedIDs = Set([issue.id] + (deleteSubtasks ? issue.subtaskIDs : []))
        let originalIssues = issues.filter { deletedIDs.contains($0.id) }
        let previousIssues = issues

        issues.removeAll { deletedIDs.contains($0.id) }

        do {
            try await issueBoardUseCase.commitDeleteIssue(issue, deleteSubtasks: deleteSubtasks)
            return deletedIDs
        } catch {
            issues = previousIssues
            await issueBoardUseCase.rollbackDeleteIssues(originalIssues)
            errorMessage = error.localizedDescription
            return []
        }
    }

    func updateSummary(issueID: Issue.ID, summary: String) async -> Bool {
        let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSummary.isEmpty,
              let index = issues.firstIndex(where: { $0.id == issueID }),
              issues[index].summary != trimmedSummary
        else { return false }

        let originalIssue = issues[index]
        var optimisticIssue = originalIssue
        optimisticIssue.summary = trimmedSummary
        optimisticIssue.updatedAt = Date()
        issues[index] = optimisticIssue

        do {
            let updatedIssue = try await issueDetailUseCase.updateSummary(for: originalIssue, summary: trimmedSummary)
            if let currentIndex = issues.firstIndex(where: { $0.id == issueID }) {
                issues[currentIndex] = updatedIssue
            }
            return true
        } catch {
            if let currentIndex = issues.firstIndex(where: { $0.id == issueID }) {
                issues[currentIndex] = originalIssue
            }
            errorMessage = error.localizedDescription
            return false
        }
    }

    func updateDescription(issueID: Issue.ID, descriptionText: String?) async -> Bool {
        let trimmedDescription = descriptionText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedDescription = trimmedDescription?.isEmpty == true ? nil : trimmedDescription
        guard let index = issues.firstIndex(where: { $0.id == issueID }),
              issues[index].descriptionText != normalizedDescription
        else { return false }

        let originalIssue = issues[index]
        var optimisticIssue = originalIssue
        optimisticIssue.descriptionText = normalizedDescription
        optimisticIssue.updatedAt = Date()
        issues[index] = optimisticIssue

        do {
            let updatedIssue = try await issueDetailUseCase.updateDescription(
                for: originalIssue,
                descriptionText: normalizedDescription
            )
            if let currentIndex = issues.firstIndex(where: { $0.id == issueID }) {
                issues[currentIndex] = updatedIssue
            }
            return true
        } catch {
            if let currentIndex = issues.firstIndex(where: { $0.id == issueID }) {
                issues[currentIndex] = originalIssue
            }
            errorMessage = error.localizedDescription
            return false
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

    func moveKanbanColumn(_ title: String, before beforeTitle: String?) async {
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

    private func loadAssignableUsers(forceRefresh: Bool) async throws {
        isLoadingAssignableUsers = true
        defer { isLoadingAssignableUsers = false }

        assignableUsers = try await projectUsersManager.users(
            projectID: projectID,
            forceRefresh: forceRefresh
        )
    }

    private var defaultIssueStatus: String {
        let knownStatuses = Set(issues.map(\.status))

        if let orderedStatus = kanbanColumnOrder.first(where: { knownStatuses.contains($0) }) {
            return orderedStatus
        }

        return issues.first?.status ?? "To Do"
    }

    private func sprintContext(for sprintID: Int?) -> (name: String?, state: String?) {
        guard let sprintID,
              let issue = issues.first(where: { $0.sprintID == sprintID })
        else {
            return (nil, nil)
        }

        return (issue.sprintName, issue.sprintState)
    }

    private func assigneeNameIfNeeded(draft: IssueCreationDraft) async throws -> String? {
        guard draft.assignToCurrentUser else { return nil }

        if let currentUser {
            return currentUser.displayName
        }

        let user = try await issueCreationUseCase.currentUser(projectID: projectID)
        currentUser = user
        return user.displayName
    }

    private func insertOrReplaceLocalIssue(_ issue: Issue) {
        if let index = issues.firstIndex(where: { $0.id == issue.id }) {
            issues[index] = issue
            return
        }

        let insertionIndex = issues.lastIndex { currentIssue in
            currentIssue.sprintID == issue.sprintID
        }.map { issues.index(after: $0) } ?? issues.endIndex

        issues.insert(issue, at: insertionIndex)
    }

    private func normalizedSprintName(_ sprintName: String?) -> String? {
        let trimmed = sprintName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty, trimmed.localizedCaseInsensitiveCompare("Backlog") != .orderedSame else {
            return nil
        }
        return trimmed
    }
}
