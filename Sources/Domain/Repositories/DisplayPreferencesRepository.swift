import Foundation

protocol DisplayPreferencesRepository: Sendable {
    func projectOrder(workspaceID: Workspace.ID) async throws -> [Project.ID]
    func saveProjectOrder(workspaceID: Workspace.ID, projectIDs: [Project.ID]) async throws
    func backlogSprintOrder(projectID: Project.ID) async throws -> [String]
    func saveBacklogSprintOrder(projectID: Project.ID, groupIDs: [String]) async throws
    func collapsedBacklogGroupIDs(projectID: Project.ID) async throws -> Set<String>
    func saveCollapsedBacklogGroupIDs(projectID: Project.ID, groupIDs: Set<String>) async throws
    func selectedSprintFilter(projectID: Project.ID) async throws -> SprintFilter
    func saveSelectedSprintFilter(projectID: Project.ID, filter: SprintFilter) async throws
}
