import SwiftUI

struct SubtaskCountBadge: View {
    let count: Int
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "checklist")
                .font(.labelS)
            Text("\(count)")
                .font(.labelS)
        }
        .foregroundStyle(isSelected ? Color.foreground.opacity(0.72) : .secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(height: 30)
        .jiraGlass(shape: .capsule, tint: isSelected ? Color.primary : nil)
    }
}
