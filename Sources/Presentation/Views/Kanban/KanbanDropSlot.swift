import SwiftUI

struct KanbanDropSlot: View {
    let status: String
    let beforeIssueID: Issue.ID?
    @Binding var selectedIssueID: Issue.ID?
    let onMoveIssue: (Issue.ID, String, Issue.ID?) -> Void
    var isEmptyColumn = false
    @State private var isTargeted = false

    var body: some View {
        placeholder
        .frame(maxWidth: .infinity)
        .frame(height: slotHeight)
        .contentShape(Rectangle())
        .dropDestination(for: String.self) { issueIDs, _ in
            guard
                let issueID = issueIDs.first,
                KanbanColumnDragPayload.title(from: issueID) == nil
            else {
                return false
            }

            onMoveIssue(issueID, status, beforeIssueID)
            selectedIssueID = issueID
            return true
        } isTargeted: { targeted in
            withAnimation(.easeInOut(duration: 0.12)) {
                isTargeted = targeted
            }
        }
    }

    private var slotHeight: CGFloat {
        if isTargeted || isEmptyColumn {
            return 104
        }

        return 8
    }

    @ViewBuilder
    private var placeholder: some View {
        if isTargeted || isEmptyColumn {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Capsule()
                        .fill(placeholderLine)
                        .frame(width: 52, height: 8)

                    Spacer()

                    Capsule()
                        .fill(placeholderLine)
                        .frame(width: 26, height: 8)
                }

                Capsule()
                    .fill(placeholderLine)
                    .frame(height: 10)

                Capsule()
                    .fill(placeholderLine.opacity(0.72))
                    .frame(width: 170, height: 10)

                HStack {
                    Spacer()

                    Capsule()
                        .fill(placeholderLine)
                        .frame(width: 64, height: 18)

                    Capsule()
                        .fill(placeholderLine)
                        .frame(width: 42, height: 18)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
            .background(placeholderBackground)
            .clipShape(RoundedRectangle(cornerRadius: JiraDesign.rowRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: JiraDesign.rowRadius, style: .continuous)
                    .strokeBorder(placeholderBorder, style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
            }
            .opacity(isTargeted ? 1 : 0.68)
            .padding(.vertical, 4)
            .transition(.scale(scale: 0.98).combined(with: .opacity))
        } else {
            Color.clear
        }
    }

    private var placeholderBackground: Color {
        isTargeted ? JiraDesign.surface.opacity(1.2) : JiraDesign.subtleSurface
    }

    private var placeholderBorder: Color {
        isTargeted ? JiraDesign.accent.opacity(0.42) : JiraDesign.hairline
    }

    private var placeholderLine: Color {
        isTargeted ? Color.primary.opacity(0.16) : Color.primary.opacity(0.09)
    }
}
