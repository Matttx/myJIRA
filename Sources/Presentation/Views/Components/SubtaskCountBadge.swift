import SwiftUI

struct SubtaskCountBadge: View {
    let count: Int
    let isSelected: Bool
    var usesTaskCardMaterial = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "checklist")
                .font(.labelS)
            Text("\(count)")
                .font(.labelS)
        }
        .foregroundStyle(isSelected ? Color.white : .secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(height: 30)
        .jiraControlSurface(shape: .capsule, usesTaskCardMaterial: usesTaskCardMaterial)
    }
}
