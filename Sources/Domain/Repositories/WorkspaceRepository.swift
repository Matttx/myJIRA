import Foundation

protocol WorkspaceRepository: Sendable {
    func workspaces() async throws -> [Workspace]
    func refreshWorkspaces() async throws
    func replace(workspaces: [Workspace]) async throws
}
