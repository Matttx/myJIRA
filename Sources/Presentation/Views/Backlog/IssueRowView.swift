import SwiftUI

struct IssueRowView: View {
    let issue: Issue
    let isSelected: Bool
    let statusOptions: [String]
    let onChangeStatus: (String) -> Void
    let onUpdateStoryPoints: (Double?) -> Void
    let onAssignToCurrentUser: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            titleBlock
            Spacer()
            storyPoints
            subtasks
            assignee
            statusPicker
        }
        .foregroundStyle(isSelected ? Color.foreground : Color.primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isSelected ? JiraDesign.accent : JiraDesign.surface)
        .clipShape(RoundedRectangle(cornerRadius: JiraDesign.rowRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: JiraDesign.rowRadius, style: .continuous))
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
        if let assigneeName = issue.assigneeName {
            JiraInitialsAvatar(name: assigneeName, isSelected: isSelected, showsHoverName: true)
        } else {
            Button(action: onAssignToCurrentUser) {
                Image(systemName: "person")
                .frame(width: 30, height: 30)
                .background(isSelected ? Color.foreground.opacity(0.12) : JiraDesign.surface)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(isSelected ? Color.foreground.opacity(0.18) : JiraDesign.hairline, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .help("Assign to me")
        }
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
}
