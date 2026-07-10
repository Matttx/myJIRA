import Foundation

protocol KanbanColumnOrderRepository: Sendable {
    func columnOrder(projectID: Project.ID) async throws -> [String]
    func saveColumnOrder(projectID: Project.ID, statuses: [String]) async throws
}
