import SwiftUI

struct IssueTypeIcon: View {
    let name: String?

    var body: some View {
        Image(systemName: systemName)
            .font(.paragraphS)
            .foregroundStyle(.secondary)
            .frame(width: 30, height: 30)
            .background(JiraDesign.surface)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(JiraDesign.hairline, lineWidth: 1)
            }
    }

    private var systemName: String {
        Self.systemName(for: name)
    }

    static func systemName(for name: String?) -> String {
        let normalized = (name ?? "")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()

        if normalized.contains("bug") {
            return "ladybug"
        }

        if normalized.contains("story") || normalized.contains("user story") {
            return "book.pages"
        }

        if normalized.contains("epic") {
            return "bolt"
        }

        if normalized.contains("sub") {
            return "checklist"
        }

        return "checkmark.square"
    }
}
