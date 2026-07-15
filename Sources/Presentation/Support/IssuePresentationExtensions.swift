import Foundation

extension Issue {
    var subtaskCount: Int {
        subtaskIDs.count
    }

    var trimmedSprintName: String? {
        guard let sprintName else { return nil }
        let trimmed = sprintName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var isDoneSprint: Bool {
        guard let sprintState else { return false }
        let normalized = sprintState.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "closed" || normalized == "done"
    }

    var isCompletedIssue: Bool {
        if statusCategoryKey?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "done" {
            return true
        }

        let normalizedStatus = status
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()

        return ["done", "closed", "resolved", "termine", "terminee"].contains(normalizedStatus)
    }

    var isFutureSprint: Bool {
        guard let sprintState else { return false }
        return sprintState.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "future"
    }
}

extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
