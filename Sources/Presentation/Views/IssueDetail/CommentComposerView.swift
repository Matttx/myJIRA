import SwiftUI

struct CommentComposerView: View {
    let authorName: String?
    let replyingToComment: IssueComment?
    let isSubmitting: Bool
    let onCancelReply: () -> Void
    let onSubmit: (String) async -> Bool

    @State private var bodyText = ""
    @FocusState private var isFocused: Bool

    private var trimmedBody: String {
        bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                if let replyingToComment {
                    replyContext(replyingToComment)
                }

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $bodyText)
                        .font(.paragraphM)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: isFocused || !bodyText.isEmpty ? 88 : 42)
                        .focused($isFocused)

                    if bodyText.isEmpty {
                        Text(replyingToComment == nil ? "Add a comment..." : "Write a reply...")
                            .font(.paragraphM)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(JiraDesign.surface)
                .clipShape(RoundedRectangle(cornerRadius: JiraDesign.controlRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: JiraDesign.controlRadius, style: .continuous)
                        .stroke(isFocused ? JiraDesign.accent.opacity(0.24) : JiraDesign.hairline, lineWidth: 1)
                }

                if isFocused || !bodyText.isEmpty {
                    HStack(spacing: 8) {
                        Button("Cancel") {
                            bodyText = ""
                            isFocused = false
                            onCancelReply()
                        }
                        .buttonStyle(JiraSecondaryButtonStyle(expandsToMaxWidth: false))
                        .disabled(isSubmitting)

                        Button {
                            submit()
                        } label: {
                            if isSubmitting {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text(replyingToComment == nil ? "Comment" : "Reply")
                            }
                        }
                        .buttonStyle(JiraPrimaryButtonStyle(expandsToMaxWidth: false))
                        .disabled(trimmedBody.isEmpty || isSubmitting)
                        .keyboardShortcut(.return, modifiers: .command)

                        Text("Cmd+Return")
                            .font(.paragraphS)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.bottom, 8)
    }

    private func replyContext(_ comment: IssueComment) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Replying to \(comment.authorName ?? "Unknown")")
                    .font(.paragraphSSemiBold)
                    .foregroundStyle(.primary)

                Text(comment.bodyText.isEmpty ? "Empty comment." : comment.bodyText)
                    .font(.paragraphS)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Button {
                onCancelReply()
            } label: {
                Image(systemName: "xmark")
                    .font(.paragraphS)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("Cancel reply")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(JiraDesign.surface)
        .clipShape(RoundedRectangle(cornerRadius: JiraDesign.compactRadius, style: .continuous))
    }

    private func submit() {
        let comment = trimmedBody
        guard !comment.isEmpty else { return }

        Task {
            if await onSubmit(comment) {
                bodyText = ""
                isFocused = false
            }
        }
    }
}
