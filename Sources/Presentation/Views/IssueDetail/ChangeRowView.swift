import SwiftUI

struct ChangeRowView: View {
    let change: IssueChange

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            JiraInitialsAvatar(name: change.authorName)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(change.authorName ?? "Unknown")
                        .font(.paragraphSSemiBold)

                    Text("updated \(change.fieldName)")
                        .font(.paragraphM)
                }

                Text(change.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.paragraphS)
                    .foregroundStyle(.secondary)

                changeDiffView
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var changeDiffView: some View {
        let oldValue = change.fromValue?.nilIfBlank ?? "Empty"
        let newValue = change.toValue?.nilIfBlank ?? "Empty"

        if shouldUseVerticalDiff(oldValue: oldValue, newValue: newValue) {
            VStack(alignment: .leading, spacing: 7) {
                changeValue(oldValue, foreground: Color.red.opacity(0.78), background: Color.red.opacity(0.08), allowsWrapping: true)

                Image(systemName: "arrow.down")
                    .font(.paragraphXS)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 10)

                changeValue(newValue, foreground: Color.green.opacity(0.78), background: Color.green.opacity(0.09), allowsWrapping: true)
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                changeValue(oldValue, foreground: Color.red.opacity(0.78), background: Color.red.opacity(0.08), allowsWrapping: false)

                Image(systemName: "arrow.right")
                    .font(.paragraphXS)
                    .foregroundStyle(.secondary)

                changeValue(newValue, foreground: Color.green.opacity(0.78), background: Color.green.opacity(0.09), allowsWrapping: false)
            }
        }
    }

    private func shouldUseVerticalDiff(oldValue: String, newValue: String) -> Bool {
        let longFieldNames = ["summary", "description", "title", "name"]
        let normalizedFieldName = change.fieldName.lowercased()

        if longFieldNames.contains(where: { normalizedFieldName.contains($0) }) {
            return true
        }

        return oldValue.count + newValue.count > 72 || oldValue.contains("\n") || newValue.contains("\n")
    }

    private func changeValue(
        _ value: String,
        foreground: Color,
        background: Color,
        allowsWrapping: Bool
    ) -> some View {
        Text(value)
            .font(.paragraphS)
            .foregroundStyle(foreground)
            .lineLimit(allowsWrapping ? nil : 1)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}
