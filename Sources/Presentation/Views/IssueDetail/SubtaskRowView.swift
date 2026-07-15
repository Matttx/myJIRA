import SwiftUI

struct SubtaskRowView: View {
    let subtask: Issue
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            rowContent
        }
        .buttonStyle(.plain)
    }

    private var rowContent: some View {
        HStack(spacing: 8) {
            titleBlock
            Spacer()
            storyPoints
            assignee
            subtasks
            statusBadge
        }
        .foregroundStyle(Color.primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(JiraDesign.surface)
        .clipShape(RoundedRectangle(cornerRadius: JiraDesign.rowRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: JiraDesign.rowRadius, style: .continuous))
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
