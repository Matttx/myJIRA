import SwiftUI

struct KanbanColumnDropSlot: View {
    let beforeColumnTitle: String?
    let onMoveColumn: (String, String?) -> Void
    @State private var isTargeted = false

    var body: some View {
        RoundedRectangle(cornerRadius: JiraDesign.compactRadius, style: .continuous)
            .fill(isTargeted ? JiraDesign.accent : Color.clear)
            .frame(width: isTargeted ? 4 : 1)
            .frame(maxHeight: .infinity)
            .padding(.horizontal, isTargeted ? 8 : 6)
            .contentShape(Rectangle())
            .dropDestination(for: String.self) { payloads, _ in
                guard
                    let payload = payloads.first,
                    let draggedColumnTitle = KanbanColumnDragPayload.title(from: payload),
                    draggedColumnTitle != beforeColumnTitle
                else {
                    return false
                }

                onMoveColumn(draggedColumnTitle, beforeColumnTitle)
                return true
            } isTargeted: { targeted in
                withAnimation(.easeInOut(duration: 0.12)) {
                    isTargeted = targeted
                }
            }
    }
}
