import Foundation

struct IssueGroup: Identifiable {
    var id: String { title }
    let title: String
    let sprintID: Int?
    let issues: [Issue]
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

enum SprintFilter: Hashable, Identifiable {
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
}
