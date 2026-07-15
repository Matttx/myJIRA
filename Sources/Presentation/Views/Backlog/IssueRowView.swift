import SwiftUI

struct IssueRowView: View {
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
        .background(isSelected ? JiraDesign.accent : JiraDesign.surface)
        .clipShape(RoundedRectangle(cornerRadius: JiraDesign.rowRadius, style: .continuous))
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
            onCommit: onUpdateStoryPoints
        )
    }

    @ViewBuilder
    private var assignee: some View {
        AssigneeAvatarButton(
            assigneeName: issue.assigneeName,
            isSelected: isSelected,
            assignableUsers: assignableUsers,
            onAssignToCurrentUser: onAssignToCurrentUser,
            onUnassign: onUnassign,
            onAssign: onAssign
        )
    }

    @ViewBuilder
    private var subtasks: some View {
        if issue.subtaskCount > 0 {
            SubtaskCountBadge(count: issue.subtaskCount, isSelected: isSelected)
        }
    }

    private var statusPicker: some View {
        JiraInlineValuePickerRow(selection: Binding(
            get: { issue.status },
            set: { status in
                guard status != issue.status else { return }
                onChangeStatus(status)
            }
        ), isProminent: isSelected, statusColor: JiraStatusColor.resolved(for: issue.status)) {
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
                .foregroundStyle(isSelected ? Color.foreground.opacity(0.72) : .secondary)
                .frame(width: 26, height: 24)
                .background(isSelected ? Color.foreground.opacity(0.12) : JiraDesign.surface)
                .clipShape(.capsule)
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

        Divider()

        Button(role: .destructive) {
            onDelete()
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}
