import SwiftUI

struct CommentRowView: View {
    let comment: IssueComment
    let onReply: () -> Void
    let onDelete: () -> Void

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

                HStack(spacing: 8) {
                    Button {
                        onReply()
                    } label: {
                        Label("Reply", systemImage: "arrowshape.turn.up.left")
                            .font(.paragraphS)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Reply to comment")

                    commentActionsMenu
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var commentActionsMenu: some View {
        Menu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.paragraphS)
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 20)
                .contentShape(.capsule)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Comment actions")
    }
}
