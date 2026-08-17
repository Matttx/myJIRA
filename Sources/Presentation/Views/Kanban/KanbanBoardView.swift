import SwiftUI

struct KanbanBoardView: View {
    let columns: [KanbanColumn]
    let hiddenColumnTitles: Set<String>
    let onChangeHiddenColumnTitles: (Set<String>) -> Void
    @Binding var selectedIssueID: Issue.ID?
    let onMoveIssue: (Issue.ID, String, Issue.ID?) -> Void
    let onMoveColumn: (String, String?) -> Void
    let onDeleteIssue: (Issue) -> Void
    let onAssignIssueToCurrentUser: (Issue.ID) -> Void
    let onUnassignIssue: (Issue.ID) -> Void
    let assignableUsers: [JiraUser]
    let onAssignIssue: (Issue.ID, JiraUser) -> Void

    var body: some View {
        VStack(spacing: 4) {
            KanbanColumnsMenu(
                columns: columns,
                hiddenColumnTitles: hiddenColumnTitles,
                onChangeHiddenColumnTitles: onChangeHiddenColumnTitles
            )
            .padding(.horizontal, 22)

            boardContent
        }
    }

    private var boardContent: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(visibleColumns) { column in
                    KanbanColumnDropSlot(
                        beforeColumnTitle: column.title,
                        onMoveColumn: onMoveColumn
                    )

                    KanbanColumnView(
                        column: column,
                        onHide: {
                            onChangeHiddenColumnTitles(hiddenColumnTitles.union([column.title]))
                        },
                        selectedIssueID: $selectedIssueID,
                        onMoveIssue: onMoveIssue,
                        onDeleteIssue: onDeleteIssue,
                        onAssignIssueToCurrentUser: onAssignIssueToCurrentUser,
                        onUnassignIssue: onUnassignIssue,
                        assignableUsers: assignableUsers,
                        onAssignIssue: onAssignIssue
                    )
                    .draggable(KanbanColumnDragPayload.prefix + column.title)
                }

                KanbanColumnDropSlot(
                    beforeColumnTitle: nil,
                    onMoveColumn: onMoveColumn
                )
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 18)
        }
        .scrollIndicators(.hidden)
    }

    private var visibleColumns: [KanbanColumn] {
        columns.filter { !hiddenColumnTitles.contains($0.title) }
    }

}
