import Foundation

final class JiraSessionUseCase: @unchecked Sendable {
    private let workspaceRepository: WorkspaceRepository
    private let jiraConnectionService: JiraConnectionService

    init(
        workspaceRepository: WorkspaceRepository,
        jiraConnectionService: JiraConnectionService
    ) {
        self.workspaceRepository = workspaceRepository
        self.jiraConnectionService = jiraConnectionService
    }

    func isConnected() async -> Bool {
        await jiraConnectionService.isConnected()
    }

    func workspaces() async throws -> [Workspace] {
        try await workspaceRepository.workspaces()
    }

    func connect(configuration: JiraOAuthConfiguration) async throws -> [Workspace] {
        _ = try await jiraConnectionService.connect(configuration: configuration)
        return try await workspaceRepository.workspaces()
    }
}
