import Foundation

final class DefaultJiraConnectionService: JiraConnectionService, @unchecked Sendable {
    private let authService: AuthService
    private let jiraDataService: JiraDataService
    private let workspaceRepository: WorkspaceRepository
    private let secretStore: SecretStore

    init(
        authService: AuthService,
        jiraDataService: JiraDataService,
        workspaceRepository: WorkspaceRepository,
        secretStore: SecretStore
    ) {
        self.authService = authService
        self.jiraDataService = jiraDataService
        self.workspaceRepository = workspaceRepository
        self.secretStore = secretStore
    }

    func connect(configuration: JiraOAuthConfiguration) async throws -> JiraConnectionResult {
        try secretStore.save(Data(configuration.clientSecret.utf8), account: "jira.oauth.clientSecret")

        let resources = try await authService.connect(configuration: configuration)
        var workspaces: [Workspace] = []

        for resource in resources {
            let projects = try await jiraDataService.projects(for: resource)
            workspaces.append(Workspace(
                id: resource.id,
                name: resource.name,
                baseURL: resource.url,
                projects: projects
            ))
        }

        try await workspaceRepository.replace(workspaces: workspaces)
        return JiraConnectionResult(resources: resources, workspaces: workspaces)
    }

    func disconnect() async throws {
        try authService.disconnect()
        try secretStore.delete(account: "jira.oauth.clientSecret")
        try await workspaceRepository.replace(workspaces: [])
    }

    func isConnected() async -> Bool {
        guard let token = try? authService.currentToken() else {
            return false
        }

        return token.expiresAt > Date()
    }
}
