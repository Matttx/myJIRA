import SwiftUI

struct JiraSearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.paragraphS)
                .foregroundStyle(.secondary)

            TextField("Search ticket", text: $text)
                .textFieldStyle(.plain)
                .font(.paragraphS)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.paragraphS)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(JiraDesign.surface)
        .clipShape(.capsule)
    }
}
