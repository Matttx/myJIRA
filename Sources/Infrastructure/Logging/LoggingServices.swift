import Foundation

final class LoggingSecretStore: SecretStore, @unchecked Sendable {
    private let wrapped: SecretStore
    private let logs: LogManager

    init(wrapping wrapped: SecretStore, logs: LogManager = .shared) {
        self.wrapped = wrapped
        self.logs = logs
    }

    func save(_ data: Data, account: String) throws {
        try logs.measure(service: "SecretStore", operation: "save", metadata: [
            "account": account, "byteCount": "\(data.count)"
        ]) { try wrapped.save(data, account: account) }
    }

    func read(account: String) throws -> Data? {
        try logs.measure(service: "SecretStore", operation: "read", metadata: ["account": account]) {
            try wrapped.read(account: account)
        }
    }

    func delete(account: String) throws {
        try logs.measure(service: "SecretStore", operation: "delete", metadata: ["account": account]) {
            try wrapped.delete(account: account)
        }
    }
}

final class LoggingAuthService: AuthService, @unchecked Sendable {
    private let wrapped: AuthService
    private let logs: LogManager

    init(wrapping wrapped: AuthService, logs: LogManager = .shared) {
        self.wrapped = wrapped
        self.logs = logs
    }

    func connect(configuration: JiraOAuthConfiguration) async throws -> [JiraAccessibleResource] {
        try await logs.measure(service: "AuthService", operation: "connect", metadata: [
            "redirectHost": configuration.redirectURI.host ?? "unknown",
            "scopeCount": "\(configuration.scopes.count)"
        ]) { try await wrapped.connect(configuration: configuration) }
    }

    func currentToken() throws -> JiraTokenSet? {
        try logs.measure(service: "AuthService", operation: "currentToken") {
            try wrapped.currentToken()
        }
    }

    func disconnect() throws {
        try logs.measure(service: "AuthService", operation: "disconnect") {
            try wrapped.disconnect()
        }
    }
}

final class LoggingJiraDataService: JiraDataService, @unchecked Sendable {
    private let wrapped: JiraDataService
    private let logs: LogManager

    init(wrapping wrapped: JiraDataService, logs: LogManager = .shared) {
        self.wrapped = wrapped
        self.logs = logs
    }

    func projects(for resource: JiraAccessibleResource) async throws -> [Project] {
        try await call("projects", ["workspaceID": resource.id]) { try await wrapped.projects(for: resource) }
    }

    func issues(for project: Project) async throws -> [Issue] {
        try await call("issues", projectMetadata(project)) { try await wrapped.issues(for: project) }
    }

    func issueTypes(for project: Project) async throws -> [IssueTypeMetadata] {
        try await call("issueTypes", projectMetadata(project)) { try await wrapped.issueTypes(for: project) }
    }

    func creationMetadata(for project: Project, issueTypeID: IssueTypeMetadata.ID) async throws -> IssueCreationMetadata {
        try await call("creationMetadata", projectMetadata(project).merging(["issueTypeID": issueTypeID]) { _, new in new }) {
            try await wrapped.creationMetadata(for: project, issueTypeID: issueTypeID)
        }
    }

    func createIssue(in project: Project, draft: IssueCreationDraft) async throws -> CreatedIssue {
        try await call("createIssue", projectMetadata(project).merging(["issueTypeID": draft.issueTypeID]) { _, new in new }) {
            try await wrapped.createIssue(in: project, draft: draft)
        }
    }

    func currentUser(cloudID: String) async throws -> JiraUser {
        try await call("currentUser", ["cloudID": cloudID]) { try await wrapped.currentUser(cloudID: cloudID) }
    }

    func assignableUsers(for project: Project) async throws -> [JiraUser] {
        try await call("assignableUsers", projectMetadata(project)) { try await wrapped.assignableUsers(for: project) }
    }

    func assignIssueToCurrentUser(issue: Issue) async throws -> JiraUser {
        try await call("assignIssueToCurrentUser", issueMetadata(issue)) { try await wrapped.assignIssueToCurrentUser(issue: issue) }
    }

    func assignIssue(issue: Issue, to user: JiraUser) async throws {
        try await call("assignIssue", issueMetadata(issue).merging(["accountID": user.accountID]) { _, new in new }) {
            try await wrapped.assignIssue(issue: issue, to: user)
        }
    }

    func unassignIssue(issue: Issue) async throws {
        try await call("unassignIssue", issueMetadata(issue)) { try await wrapped.unassignIssue(issue: issue) }
    }

    func changelog(for issue: Issue) async throws -> [IssueChange] {
        try await call("changelog", issueMetadata(issue)) { try await wrapped.changelog(for: issue) }
    }

    func addComment(issue: Issue, bodyText: String, replyTo comment: IssueComment?) async throws -> IssueComment {
        try await call("addComment", issueMetadata(issue).merging([
            "bodyLength": "\(bodyText.count)", "replyTo": comment?.id ?? "none"
        ]) { _, new in new }) { try await wrapped.addComment(issue: issue, bodyText: bodyText, replyTo: comment) }
    }

    func deleteComment(issue: Issue, comment: IssueComment) async throws {
        try await call("deleteComment", issueMetadata(issue).merging(["commentID": comment.id]) { _, new in new }) {
            try await wrapped.deleteComment(issue: issue, comment: comment)
        }
    }

    func deleteIssue(_ issue: Issue, deleteSubtasks: Bool) async throws {
        try await call("deleteIssue", issueMetadata(issue).merging(["deleteSubtasks": "\(deleteSubtasks)"]) { _, new in new }) {
            try await wrapped.deleteIssue(issue, deleteSubtasks: deleteSubtasks)
        }
    }

    func transition(issue: Issue, toStatus status: String) async throws {
        try await call("transition", issueMetadata(issue).merging(["targetStatus": status]) { _, new in new }) {
            try await wrapped.transition(issue: issue, toStatus: status)
        }
    }

    func updateSprint(issue: Issue, sprintName: String?) async throws -> IssueSprintValue {
        try await call("updateSprint", issueMetadata(issue).merging(["sprint": sprintName ?? "backlog"]) { _, new in new }) {
            try await wrapped.updateSprint(issue: issue, sprintName: sprintName)
        }
    }

    func updateStoryPoints(issue: Issue, storyPoints: Double?) async throws {
        try await call("updateStoryPoints", issueMetadata(issue).merging(["storyPoints": storyPoints.map { String($0) } ?? "none"]) { _, new in new }) {
            try await wrapped.updateStoryPoints(issue: issue, storyPoints: storyPoints)
        }
    }

    func updateSummary(issue: Issue, summary: String) async throws {
        try await call("updateSummary", issueMetadata(issue).merging(["summaryLength": "\(summary.count)"]) { _, new in new }) {
            try await wrapped.updateSummary(issue: issue, summary: summary)
        }
    }

    func updateDescription(issue: Issue, descriptionText: String?) async throws {
        try await call("updateDescription", issueMetadata(issue).merging(["descriptionLength": "\(descriptionText?.count ?? 0)"]) { _, new in new }) {
            try await wrapped.updateDescription(issue: issue, descriptionText: descriptionText)
        }
    }

    private func call<T: Sendable>(_ operation: String, _ metadata: [String: String], _ body: () async throws -> T) async throws -> T {
        try await logs.measure(service: "JiraDataService", operation: operation, metadata: metadata, body)
    }

    private func projectMetadata(_ project: Project) -> [String: String] {
        ["projectID": project.id, "projectKey": project.key, "workspaceID": project.workspaceID]
    }

    private func issueMetadata(_ issue: Issue) -> [String: String] {
        ["issueID": issue.id, "issueKey": issue.key, "projectID": issue.projectID]
    }
}

final class LoggingJiraConnectionService: JiraConnectionService, @unchecked Sendable {
    private let wrapped: JiraConnectionService
    private let logs: LogManager

    init(wrapping wrapped: JiraConnectionService, logs: LogManager = .shared) {
        self.wrapped = wrapped
        self.logs = logs
    }

    func connect(configuration: JiraOAuthConfiguration) async throws -> JiraConnectionResult {
        try await logs.measure(service: "JiraConnectionService", operation: "connect") {
            try await wrapped.connect(configuration: configuration)
        }
    }

    func disconnect() async throws {
        try await logs.measure(service: "JiraConnectionService", operation: "disconnect") {
            try await wrapped.disconnect()
        }
    }

    func isConnected() async -> Bool {
        await logs.measure(service: "JiraConnectionService", operation: "isConnected") {
            await wrapped.isConnected()
        }
    }
}

final class LoggingSyncService: SyncService, @unchecked Sendable {
    private let wrapped: SyncService
    private let logs: LogManager

    init(wrapping wrapped: SyncService, logs: LogManager = .shared) {
        self.wrapped = wrapped
        self.logs = logs
    }

    func refresh(projectID: Project.ID?) async throws {
        try await logs.measure(service: "SyncService", operation: "refresh", metadata: [
            "projectID": projectID ?? "none"
        ]) { try await wrapped.refresh(projectID: projectID) }
    }
}
