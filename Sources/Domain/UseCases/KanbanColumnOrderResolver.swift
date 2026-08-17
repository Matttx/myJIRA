import Foundation

struct KanbanColumnOrderResolver: Sendable {
    func mergedColumnOrder(
        _ savedOrder: [String],
        availableStatuses: [String] = [],
        issues: [Issue]
    ) -> [String] {
        let observedStatuses = issues.map(\.status)
        let sourceStatuses = availableStatuses.isEmpty
            ? savedOrder + observedStatuses
            : availableStatuses + observedStatuses
        let statuses = sourceStatuses.reduce(into: [String]()) { result, status in
            guard !result.contains(status) else { return }
            result.append(status)
        }
        let knownStatuses = savedOrder.filter { statuses.contains($0) }
        let newStatuses = statuses.filter { !knownStatuses.contains($0) }
        return knownStatuses + newStatuses
    }
}
