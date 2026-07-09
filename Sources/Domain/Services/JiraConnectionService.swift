import Foundation

protocol JiraConnectionService: Sendable {
    func connect(configuration: JiraOAuthConfiguration) async throws -> JiraConnectionResult
    func disconnect() async throws
    func isConnected() async -> Bool
}

struct JiraConnectionResult: Sendable {
    var resources: [JiraAccessibleResource]
    var workspaces: [Workspace]

    var projectCount: Int {
        workspaces.flatMap(\.projects).count
    }
}
