import SwiftUI

struct EditableStoryPointsTag: View {
    let storyPoints: Double?
    let isSelected: Bool
    let onCommit: (Double?) -> Void

    @State private var isEditing = false
    @State private var draftValue = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        Group {
            if isEditing {
                TextField("-", text: $draftValue)
                    .textFieldStyle(.plain)
                    .font(.paragraphS)
                    .foregroundStyle(.primary)
                    .frame(width: 12)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(JiraDesign.foreground.opacity(0.3))
                    .clipShape(.capsule)
                    .focused($isFocused)
                    .onSubmit(commit)
                    .onChange(of: isFocused) { _, focused in
                        guard !focused else { return }
                        commit()
                    }
            } else {
                Button {
                    draftValue = storyPoints.map(Self.format) ?? ""
                    isEditing = true
                    isFocused = true
                } label: {
                    Text(storyPoints.map { "\(Self.format($0)) SP" } ?? "-")
                        .font(.paragraphS)
                        .foregroundStyle(isSelected ? Color.foreground.opacity(0.72) : .secondary)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isSelected ? Color.foreground.opacity(0.12) : JiraDesign.surface)
                        .clipShape(.capsule)
                }
                .buttonStyle(.plain)
                .help("Edit story points")
            }
        }
        .onAppear {
            guard !isEditing else { return }
            draftValue = storyPoints.map(Self.format) ?? ""
        }
        .onChange(of: storyPoints) { _, nextStoryPoints in
            guard !isEditing else { return }
            draftValue = nextStoryPoints.map(Self.format) ?? ""
        }
    }

    private func commit() {
        guard isEditing else { return }
        isEditing = false

        let trimmed = draftValue.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        let normalized = trimmed.isEmpty ? nil : Double(trimmed)
        guard normalized != storyPoints else { return }
        onCommit(normalized)
    }

    private static func format(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }
}
