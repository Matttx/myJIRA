import Foundation

struct Project: Identifiable, Hashable, Sendable {
    let id: String
    var key: String
    var name: String
    var workspaceID: Workspace.ID
}
