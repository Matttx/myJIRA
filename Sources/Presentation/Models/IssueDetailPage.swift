import Foundation

enum IssueDetailPage: CaseIterable, Identifiable {
    case subtasks
    case comments
    case history

    var id: Self { self }

    var title: String {
        switch self {
        case .subtasks:
            "Subtasks"
        case .comments:
            "Comments"
        case .history:
            "History"
        }
    }
}
