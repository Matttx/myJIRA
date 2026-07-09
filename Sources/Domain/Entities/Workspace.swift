import Foundation

struct Workspace: Identifiable, Hashable, Sendable {
    let id: String
    var name: String
    var baseURL: URL
    var projects: [Project]
}
