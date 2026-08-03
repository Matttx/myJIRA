import Foundation

final class DefaultJiraConnectionService: JiraConnectionService, @unchecked Sendable {
    private let authService: AuthService
    private let jiraDataService: JiraDataService
    private let workspaceRepository: WorkspaceRepository

    init(
        authService: AuthService,
        jiraDataService: JiraDataService,
        workspaceRepository: WorkspaceRepository
    ) {
        self.authService = authService
        self.jiraDataService = jiraDataService
        self.workspaceRepository = workspaceRepository
    }

    func connect(configuration: JiraOAuthConfiguration) async throws -> JiraConnectionResult {
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
        try await workspaceRepository.replace(workspaces: [])
    }

    func isConnected() async -> Bool {
        guard let token = try? await authService.validToken() else {
            return false
        }
        return token.expiresAt > Date.now
    }
}
