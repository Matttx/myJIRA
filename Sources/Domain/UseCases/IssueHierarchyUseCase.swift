import Foundation

struct IssueHierarchyUseCase: Sendable {
    func issue(id: Issue.ID?, in issues: [Issue]) -> Issue? {
        guard let id else { return nil }
        return issues.first { $0.id == id }
    }

    func subtasks(for issue: Issue?, in issues: [Issue]) -> [Issue] {
        guard let issue else { return [] }

        if !issue.subtaskIDs.isEmpty {
            return issue.subtaskIDs.compactMap { subtaskID in
                issues.first { $0.id == subtaskID }
            }
        }

        return issues
            .filter { $0.parentID == issue.id }
            .sorted { lhs, rhs in
                lhs.updatedAt > rhs.updatedAt
            }
    }

    func parent(for issue: Issue?, in issues: [Issue]) -> Issue? {
        guard let parentID = issue?.parentID else { return nil }
        return issues.first { $0.id == parentID }
    }
}
