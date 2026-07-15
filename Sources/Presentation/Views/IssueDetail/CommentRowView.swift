import SwiftUI

struct CommentRowView: View {
    let comment: IssueComment

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            JiraInitialsAvatar(name: comment.authorName)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(comment.authorName ?? "Unknown")
                        .font(.paragraphSSemiBold)

                    Text(comment.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.paragraphS)
                        .foregroundStyle(.secondary)
                }

                Text(comment.bodyText.isEmpty ? "Empty comment." : comment.bodyText)
                    .font(.paragraphM)
                    .foregroundStyle(comment.bodyText.isEmpty ? .secondary : .primary)
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
