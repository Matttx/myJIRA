import Foundation

protocol KanbanColumnOrderRepository: Sendable {
    func columnOrder(projectID: Project.ID) async throws -> [String]
    func saveColumnOrder(projectID: Project.ID, statuses: [String]) async throws
    func availableStatuses(projectID: Project.ID) async throws -> [String]
    func saveAvailableStatuses(projectID: Project.ID, statuses: [String]) async throws
}
