import Foundation

struct IssueGroup: Identifiable {
    var id: String { sprintID.map { "sprint:\($0)" } ?? "backlog" }
    let title: String
    let sprintID: Int?
    let issues: [Issue]
}

enum BacklogDragPayload {
    private static let issuePrefix = "myjira-backlog-issue:"
    private static let sprintPrefix = "myjira-backlog-sprint:"

    static func issue(_ issueID: Issue.ID) -> String {
        issuePrefix + issueID
    }

    static func sprint(_ groupID: String) -> String {
        sprintPrefix + groupID
    }

    static func issueID(from payload: String) -> Issue.ID? {
        guard payload.hasPrefix(issuePrefix) else { return nil }
        return String(payload.dropFirst(issuePrefix.count))
    }

    static func sprintID(from payload: String) -> String? {
        guard payload.hasPrefix(sprintPrefix) else { return nil }
        return String(payload.dropFirst(sprintPrefix.count))
    }
}

struct IssueSprintOption: Identifiable, Hashable {
    var id: String {
        sprintID.map { "sprint:\($0)" } ?? "backlog"
    }

    let sprintID: Int?
    let title: String
}

struct KanbanColumn: Identifiable {
    var id: String { title }
    let title: String
    let issues: [Issue]
}

enum BacklogFocus: String, CaseIterable, Identifiable {
    case backlog
    case kanban

    var id: String { rawValue }

    var title: String {
        switch self {
        case .backlog:
            "Backlog"
        case .kanban:
            "Kanban"
        }
    }
}

enum SprintFilter: Hashable, Identifiable, Sendable {
    case all
    case backlog
    case sprint(String)

    var id: String {
        switch self {
        case .all:
            "all"
        case .backlog:
            "backlog"
        case .sprint(let name):
            "sprint:\(name)"
        }
    }

    var title: String {
        switch self {
        case .all:
            "All"
        case .backlog:
            "Backlog"
        case .sprint(let name):
            name
        }
    }

    static func saved(id: String?) -> SprintFilter {
        guard let id else { return .all }

        switch id {
        case "all":
            return .all
        case "backlog":
            return .backlog
        default:
            if id.hasPrefix("sprint:") {
                return .sprint(String(id.dropFirst("sprint:".count)))
            }

            return .all
        }
    }
}
