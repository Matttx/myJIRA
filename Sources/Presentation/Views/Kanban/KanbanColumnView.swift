import SwiftUI

struct KanbanColumnView: View {
    let column: KanbanColumn
    let onHide: () -> Void
    @Binding var selectedIssueID: Issue.ID?
    let onMoveIssue: (Issue.ID, String, Issue.ID?) -> Void
    let onDeleteIssue: (Issue) -> Void
    let onAssignIssueToCurrentUser: (Issue.ID) -> Void
    let onUnassignIssue: (Issue.ID) -> Void
    let assignableUsers: [JiraUser]
    let onAssignIssue: (Issue.ID, JiraUser) -> Void
    @State private var isHeaderHovered = false

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

            Spacer(minLength: 4)

            Menu("", systemImage: "ellipsis") {
                Button("Hide column", systemImage: "eye.slash", action: onHide)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .tint(statusColor.accent)
            .fixedSize()
            .opacity(isHeaderHovered ? 1 : 0)
            .accessibilityHidden(!isHeaderHovered)
        }
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onHover { isHeaderHovered = $0 }
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
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .scrollIndicators(.never)
        .scrollClipDisabled()
        .clipShape(VerticalScrollClipShape(horizontalOverflow: 24))
    }
}

private struct VerticalScrollClipShape: Shape {
    let horizontalOverflow: CGFloat

    func path(in rect: CGRect) -> Path {
        Path(
            CGRect(
                x: rect.minX - horizontalOverflow,
                y: rect.minY,
                width: rect.width + horizontalOverflow * 2,
                height: rect.height
            )
        )
    }
}
