import SwiftUI

struct SubtaskRowView: View {
    let subtask: Issue
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        rowContent
            .onTapGesture(perform: onSelect)
            .onHover { hovering in
                withAnimation(.bouncy(duration: 0.3)) {
                    isHovering = hovering
                }
            }
            .contextMenu {
                actionItems
            }
    }

    @ViewBuilder
    private var actionItems: some View {
        Button {
            onSelect()
        } label: {
            Label("Open", systemImage: "arrow.up.right.square")
        }

        Button {
            onSelect()
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

    private var rowContent: some View {
        HStack(spacing: 8) {
            titleBlock
            Spacer()
            storyPoints
            assignee
            subtasks
            statusBadge
            if isHovering {
                actionsMenu
                    .allowsHitTesting(isHovering)
            }
        }
        .foregroundStyle(Color.primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(JiraDesign.surface)
        .clipShape(RoundedRectangle(cornerRadius: JiraDesign.rowRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: JiraDesign.rowRadius, style: .continuous))
    }

    private var actionsMenu: some View {
        Menu {
            actionItems
        } label: {
            Image(systemName: "ellipsis")
                .font(.paragraphS)
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 24)
                .background(JiraDesign.surface)
                .clipShape(.capsule)
        }
        .buttonStyle(.plain)
        .help("Subtask actions")
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(subtask.key)
                .font(.paragraphSSemiBold)
                .foregroundStyle(.secondary)

            Text(subtask.summary)
                .font(.paragraphM)
                .lineLimit(1)
        }
    }

    private var storyPoints: some View {
        EditableStoryPointsTag(
            storyPoints: subtask.storyPoints,
            isSelected: false,
            onCommit: { _ in }
        )
    }

    @ViewBuilder
    private var assignee: some View {
        if let assigneeName = subtask.assigneeName {
            JiraInitialsAvatar(name: assigneeName, showsHoverName: true)
        } else {
            Image(systemName: "person")
                .font(.paragraphS)
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .background(JiraDesign.surface)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(JiraDesign.hairline, lineWidth: 1)
                }
                .help("Unassigned")
        }
    }

    @ViewBuilder
    private var subtasks: some View {
        if subtask.subtaskCount > 0 {
            SubtaskCountBadge(count: subtask.subtaskCount, isSelected: false)
        }
    }

    private var statusBadge: some View {
        JiraInlineValuePickerRow(
            selection: .constant(subtask.status),
            statusColor: JiraStatusColor.resolved(for: subtask.status)
        ) {
            Text(subtask.status).tag(subtask.status)
        }
        .allowsHitTesting(false)
    }
}
