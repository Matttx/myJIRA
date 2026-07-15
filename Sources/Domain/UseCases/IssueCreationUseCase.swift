import Foundation

final class IssueCreationUseCase: @unchecked Sendable {
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

    func issueTypes(projectID: Project.ID?) async throws -> [IssueTypeMetadata] {
        let project = try await project(projectID: projectID)
        return try await jiraDataService.issueTypes(for: project)
            .filter { !$0.isSubtask }
    }

    func subtaskIssueTypes(projectID: Project.ID?) async throws -> [IssueTypeMetadata] {
        let project = try await project(projectID: projectID)
        return try await jiraDataService.issueTypes(for: project)
            .filter(\.isSubtask)
    }

    func creationMetadata(projectID: Project.ID?, issueTypeID: IssueTypeMetadata.ID) async throws -> IssueCreationMetadata {
        let project = try await project(projectID: projectID)
        return try await jiraDataService.creationMetadata(for: project, issueTypeID: issueTypeID)
    }

    func currentUser(projectID: Project.ID?) async throws -> JiraUser {
        let project = try await project(projectID: projectID)
        return try await jiraDataService.currentUser(cloudID: project.workspaceID)
    }

    @discardableResult
    func createIssue(
        projectID: Project.ID?,
        draft: IssueCreationDraft,
        issueTypeName: String?,
        defaultStatus: String,
        targetSprintName: String?,
        targetSprintState: String?,
        assigneeName: String?
    ) async throws -> Issue {
        let project = try await project(projectID: projectID)
        let createdIssue = try await jiraDataService.createIssue(in: project, draft: draft)
        let now = Date()
        let description = draft.descriptionText?.trimmingCharacters(in: .whitespacesAndNewlines)

        let issue = Issue(
            id: createdIssue.id,
            key: createdIssue.key,
            projectID: project.id,
            summary: draft.summary.trimmingCharacters(in: .whitespacesAndNewlines),
            status: defaultStatus,
            descriptionText: description?.isEmpty == true ? nil : description,
            issueTypeName: issueTypeName,
            storyPoints: draft.storyPoints,
            sprintID: draft.targetSprintID,
            sprintName: targetSprintName,
            sprintState: targetSprintState,
            assigneeName: assigneeName,
            createdAt: now,
            updatedAt: now
        )

        try await issueRepository.upsertIssue(issue)
        return issue
    }

    @discardableResult
    func createSubtask(
        projectID: Project.ID?,
        parentIssue: Issue,
        draft: IssueCreationDraft,
        issueTypeName: String?,
        defaultStatus: String,
        assigneeName: String?
    ) async throws -> Issue {
        let project = try await project(projectID: projectID)
        var subtaskDraft = draft
        subtaskDraft.parentIssueKey = parentIssue.key
        subtaskDraft.targetSprintID = nil
        subtaskDraft.storyPoints = nil

        let createdIssue = try await jiraDataService.createIssue(in: project, draft: subtaskDraft)
        let now = Date()
        let description = draft.descriptionText?.trimmingCharacters(in: .whitespacesAndNewlines)

        let subtask = Issue(
            id: createdIssue.id,
            key: createdIssue.key,
            projectID: project.id,
            summary: draft.summary.trimmingCharacters(in: .whitespacesAndNewlines),
            status: defaultStatus,
            descriptionText: description?.isEmpty == true ? nil : description,
            issueTypeName: issueTypeName,
            sprintID: parentIssue.sprintID,
            sprintName: parentIssue.sprintName,
            sprintState: parentIssue.sprintState,
            parentID: parentIssue.id,
            parentKey: parentIssue.key,
            isSubtask: true,
            assigneeName: assigneeName,
            createdAt: now,
            updatedAt: now
        )

        var updatedParent = parentIssue
        if !updatedParent.subtaskIDs.contains(subtask.id) {
            updatedParent.subtaskIDs.append(subtask.id)
        }
        updatedParent.updatedAt = now

        try await issueRepository.upsertIssue(subtask)
        try await issueRepository.upsertIssue(updatedParent)
        return subtask
    }

    private func project(projectID: Project.ID?) async throws -> Project {
        guard let projectID else {
            throw AuthError.invalidConfiguration
        }

        let workspaces = try await workspaceRepository.workspaces()
        guard let project = workspaces.flatMap(\.projects).first(where: { $0.id == projectID }) else {
            throw AuthError.invalidConfiguration
        }

        return project
    }
}
