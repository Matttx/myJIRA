import SwiftUI

struct JiraInitialsAvatar: View {
    let name: String?
    var isSelected = false
    var showsHoverName = false
    @State private var isHovering = false

    var body: some View {
        Text(initials)
            .font(.labelS)
            .foregroundStyle(isSelected ? Color.foreground : Color.primary)
            .frame(width: 30, height: 30)
            .background(isSelected ? Color.foreground.opacity(0.12) : JiraDesign.surface.opacity(showsHoverName ? 0 : 1))
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(isSelected ? Color.foreground.opacity(0.18) : JiraDesign.hairline, lineWidth: 1)
            }
            .onHover { hovering in
                guard showsHoverName else { return }
                withAnimation(.easeOut(duration: 0.12)) {
                    isHovering = hovering
                }
            }
            .popover(isPresented: $isHovering, arrowEdge: .top) {
                Text(name ?? "Unknown")
                    .font(.paragraphS)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
    }

    private var initials: String {
        guard let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "?"
        }

        let parts = name
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)

        return parts.isEmpty ? "?" : String(parts).uppercased()
    }
}
