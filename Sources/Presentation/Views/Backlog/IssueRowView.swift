@preconcurrency import AppKit
import SwiftUI

struct IssueRowView: View {
    @Environment(\.jiraBaseURL) private var jiraBaseURL

    let issue: Issue
    let isSelected: Bool
    let statusOptions: [String]
    let onChangeStatus: (String) -> Void
    let onUpdateStoryPoints: (Double?) -> Void
    let onAssignToCurrentUser: () -> Void
    let onUnassign: () -> Void
    let assignableUsers: [JiraUser]
    let onAssign: (JiraUser) -> Void
    let onOpen: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            titleBlock
            Spacer()
            storyPoints
            subtasks
            assignee
            statusPicker
            if isHovering {
                actionsMenu
                    .allowsHitTesting(isHovering)
            }
        }
        .foregroundStyle(isSelected ? Color.foreground : Color.primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            cardBackground,
            in: RoundedRectangle(cornerRadius: JiraDesign.rowRadius)
        )
        .contentShape(RoundedRectangle(cornerRadius: JiraDesign.rowRadius, style: .continuous))
        .onHover { hovering in
            withAnimation(.bouncy(duration: 0.3)) {
                isHovering = hovering
            }
        }
        .contextMenu {
            actionItems
        }
    }

    private var cardBackground: Color {
        isSelected ? .primary : Color(nsColor: .quaternarySystemFill)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(issue.key)
                .font(.paragraphSSemiBold)
                .foregroundStyle(isSelected ? Color.foreground.opacity(0.72) : .secondary)

            Text(issue.summary)
                .font(.paragraphM)
                .lineLimit(1)
        }
    }

    private var storyPoints: some View {
        EditableStoryPointsTag(
            storyPoints: issue.storyPoints,
            isSelected: isSelected,
            usesTaskCardMaterial: true,
            onCommit: onUpdateStoryPoints
        )
    }

    @ViewBuilder
    private var assignee: some View {
        AssigneeAvatarButton(
            assigneeName: issue.assigneeName,
            isSelected: isSelected,
            usesTaskCardMaterial: true,
            assignableUsers: assignableUsers,
            onAssignToCurrentUser: onAssignToCurrentUser,
            onUnassign: onUnassign,
            onAssign: onAssign
        )
    }

    @ViewBuilder
    private var subtasks: some View {
        if issue.subtaskCount > 0 {
            SubtaskCountBadge(count: issue.subtaskCount, isSelected: isSelected, usesTaskCardMaterial: true)
        }
    }

    private var statusPicker: some View {
        JiraInlineValuePickerRow(selection: Binding(
            get: { issue.status },
            set: { status in
                guard status != issue.status else { return }
                onChangeStatus(status)
            }
        ), isProminent: isSelected, statusColor: JiraStatusColor.resolved(for: issue.status), usesTaskCardMaterial: true) {
            ForEach(statusOptions, id: \.self) { status in
                Text(status).tag(status)
            }
        }
    }

    private var actionsMenu: some View {
        Menu {
            actionItems
        } label: {
            Image(systemName: "ellipsis")
                .font(.paragraphS)
                .foregroundStyle(isSelected ? Color.white : .secondary)
                .frame(width: 26, height: 24)
                .jiraTaskCardMaterial(shape: .capsule)
        }
        .buttonStyle(.plain)
        .help("Issue actions")
    }

    @ViewBuilder
    private var actionItems: some View {
        Button {
            onOpen()
        } label: {
            Label("Open", systemImage: "arrow.up.right.square")
        }

        Button {
            onOpen()
        } label: {
            Label("Edit", systemImage: "square.and.pencil")
        }

        Button {
            copyIssueKey()
        } label: {
            Label("Copy ticket ID", systemImage: "doc.on.doc")
        }

        if issue.jiraURL(baseURL: jiraBaseURL) != nil {
            Button {
                issue.copyJiraURLToPasteboard(baseURL: jiraBaseURL)
            } label: {
                Label("Copy Jira URL", systemImage: "link")
            }
        }

        Button {
            issue.copyAgentChatContextToPasteboard()
        } label: {
            Label("Copy for AI agent", systemImage: "sparkles")
        }

        Divider()

        Button(role: .destructive) {
            onDelete()
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func copyIssueKey() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(issue.key, forType: .string)
    }
}
