import SwiftUI

struct KanbanBoardView: View {
    let columns: [KanbanColumn]
    @Binding var selectedIssueID: Issue.ID?
    let onMoveIssue: (Issue.ID, String, Issue.ID?) -> Void
    let onMoveColumn: (String, String?) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(columns) { column in
                    KanbanColumnDropSlot(
                        beforeColumnTitle: column.title,
                        onMoveColumn: onMoveColumn
                    )

                    KanbanColumnView(
                        column: column,
                        selectedIssueID: $selectedIssueID,
                        onMoveIssue: onMoveIssue
                    )
                    .draggable(KanbanColumnDragPayload.prefix + column.title)
                }

                KanbanColumnDropSlot(
                    beforeColumnTitle: nil,
                    onMoveColumn: onMoveColumn
                )
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
        .scrollIndicators(.hidden)
    }
}
