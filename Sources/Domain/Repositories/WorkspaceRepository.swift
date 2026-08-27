import Foundation

protocol WorkspaceRepository: Sendable {
    func workspaces() async throws -> [Workspace]
    func replace(workspaces: [Workspace]) async throws
}
