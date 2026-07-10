import Foundation

struct KanbanColumnOrderResolver: Sendable {
    func mergedColumnOrder(_ savedOrder: [String], issues: [Issue]) -> [String] {
        let statuses = Array(Set(issues.map(\.status))).sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
        let knownStatuses = savedOrder.filter { statuses.contains($0) }
        let newStatuses = statuses.filter { !knownStatuses.contains($0) }
        return knownStatuses + newStatuses
    }
}
