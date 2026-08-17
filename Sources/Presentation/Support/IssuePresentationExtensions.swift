@preconcurrency import AppKit
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

    var agentChatContextMarkdown: String {
        var sections = ["# \(key) — \(summary)"]
        var metadata = [
            "- **Project:** \(projectID)",
            "- **Status:** \(status)"
        ]

        appendMetadata("Type", value: issueTypeName, to: &metadata)
        appendMetadata("Priority", value: priorityName, to: &metadata)
        appendMetadata("Sprint", value: trimmedSprintName, to: &metadata)
        appendMetadata("Assignee", value: assigneeName, to: &metadata)
        appendMetadata("Reporter", value: reporterName, to: &metadata)
        appendMetadata("Parent", value: parentKey, to: &metadata)

        if let storyPoints {
            metadata.append("- **Story points:** \(storyPoints.formatted(.number.precision(.fractionLength(0...2))))")
        }

        if !labels.isEmpty {
            metadata.append("- **Labels:** \(labels.joined(separator: ", "))")
        }

        if !subtaskIDs.isEmpty {
            metadata.append("- **Subtasks:** \(subtaskIDs.joined(separator: ", "))")
        }

        if let createdAt {
            metadata.append("- **Created:** \(createdAt.ISO8601Format())")
        }
        metadata.append("- **Updated:** \(updatedAt.ISO8601Format())")
        sections.append("## Ticket\n\(metadata.joined(separator: "\n"))")

        if let description = descriptionText?.nilIfBlank {
            sections.append("## Description\n\(description)")
        }

        let relevantComments = comments
            .filter { !$0.bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.createdAt < $1.createdAt }
        if !relevantComments.isEmpty {
            let commentText = relevantComments.map { comment in
                let author = comment.authorName?.nilIfBlank ?? "Unknown author"
                let replyContext = comment.parentID == nil ? "" : " — reply"
                return "### \(author) — \(comment.createdAt.ISO8601Format())\(replyContext)\n\(comment.bodyText)"
            }
            sections.append("## Comments (\(relevantComments.count))\n\(commentText.joined(separator: "\n\n"))")
        }

        let orderedChanges = changes.sorted { $0.createdAt < $1.createdAt }
        if !orderedChanges.isEmpty {
            let changeText = orderedChanges.map { change in
                let author = change.authorName?.nilIfBlank ?? "Unknown author"
                let previousValue = change.fromValue?.nilIfBlank ?? "∅"
                let newValue = change.toValue?.nilIfBlank ?? "∅"
                return "- \(change.createdAt.ISO8601Format()) — **\(change.fieldName)**: \(previousValue) → \(newValue) _(\(author))_"
            }
            sections.append("## Change history\n\(changeText.joined(separator: "\n"))")
        }

        return sections.joined(separator: "\n\n")
    }

    @MainActor
    func copyAgentChatContextToPasteboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(agentChatContextMarkdown, forType: .string)
    }

    private func appendMetadata(_ label: String, value: String?, to metadata: inout [String]) {
        guard let value = value?.nilIfBlank else { return }
        metadata.append("- **\(label):** \(value)")
    }
}

extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
