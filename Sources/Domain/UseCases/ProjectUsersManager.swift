import Foundation

final class ProjectUsersManager: @unchecked Sendable {
    private let workspaceRepository: WorkspaceRepository
    private let jiraDataService: JiraDataService
    private var cache: [Project.ID: [JiraUser]] = [:]

    init(workspaceRepository: WorkspaceRepository, jiraDataService: JiraDataService) {
        self.workspaceRepository = workspaceRepository
        self.jiraDataService = jiraDataService
    }

    func users(projectID: Project.ID, forceRefresh: Bool = false) async throws -> [JiraUser] {
        if !forceRefresh, let cachedUsers = cache[projectID] {
            return cachedUsers
        }

        let project = try await project(projectID: projectID)
        let users = try await jiraDataService.assignableUsers(for: project)
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
        cache[projectID] = users
        return users
    }

    func clear(projectID: Project.ID? = nil) {
        if let projectID {
            cache[projectID] = nil
        } else {
            cache.removeAll()
        }
    }

    private func project(projectID: Project.ID) async throws -> Project {
        let workspaces = try await workspaceRepository.workspaces()
        guard let project = workspaces.flatMap(\.projects).first(where: { $0.id == projectID }) else {
            throw AuthError.invalidConfiguration
        }

        return project
    }
}
