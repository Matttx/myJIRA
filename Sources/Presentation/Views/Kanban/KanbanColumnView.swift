import SwiftUI

struct KanbanColumnView: View {
    let column: KanbanColumn
    @Binding var selectedIssueID: Issue.ID?
    let onMoveIssue: (Issue.ID, String, Issue.ID?) -> Void
    let onDeleteIssue: (Issue) -> Void
    let onAssignIssueToCurrentUser: (Issue.ID) -> Void
    let onUnassignIssue: (Issue.ID) -> Void
    let assignableUsers: [JiraUser]
    let onAssignIssue: (Issue.ID, JiraUser) -> Void

    var body: some View {
        let statusColor = JiraStatusColor.resolved(for: column.title)

        VStack(alignment: .leading, spacing: 10) {
            header(statusColor: statusColor)
            issuesList
        }
        .frame(width: 300)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func header(statusColor: JiraStatusColor) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor.accent)
                .frame(width: 8, height: 8)

            Text(column.title.uppercased())
                .font(.headingXS)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text("\(column.issues.count)")
                .font(.labelS)
                .foregroundStyle(statusColor.accent)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(statusColor.background)
                .clipShape(.capsule)
        }
        .padding(.horizontal, 4)
        .overlay(alignment: .bottomLeading) {
            Capsule()
                .fill(statusColor.accent.opacity(0.38))
                .frame(width: 36, height: 2)
                .offset(y: 8)
        }
    }

    private var issuesList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(column.issues) { issue in
                    KanbanDropSlot(
                        status: column.title,
                        beforeIssueID: issue.id,
                        selectedIssueID: $selectedIssueID,
                        onMoveIssue: onMoveIssue
                    )

                    KanbanIssueCard(
                        issue: issue,
                        isSelected: selectedIssueID == issue.id,
                        onOpen: {
                            selectedIssueID = issue.id
                        },
                        onDelete: {
                            onDeleteIssue(issue)
                        },
                        onAssignToCurrentUser: {
                            onAssignIssueToCurrentUser(issue.id)
                        },
                        onUnassign: {
                            onUnassignIssue(issue.id)
                        },
                        assignableUsers: assignableUsers,
                        onAssign: { user in
                            onAssignIssue(issue.id, user)
                        }
                    )
                    .onTapGesture {
                        selectedIssueID = issue.id
                    }
                    .draggable(issue.id)
                }

                KanbanDropSlot(
                    status: column.title,
                    beforeIssueID: nil,
                    selectedIssueID: $selectedIssueID,
                    onMoveIssue: onMoveIssue,
                    isEmptyColumn: column.issues.isEmpty
                )
            }
        }
        .scrollIndicators(.never)
    }
}
