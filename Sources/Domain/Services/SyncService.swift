import Foundation

protocol SyncService: Sendable {
    func refresh(projectID: Project.ID?) async throws
}
