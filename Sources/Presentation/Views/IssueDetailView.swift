import SwiftUI

struct IssueDetailView: View {
    let issue: Issue?
    let parentIssue: Issue?
    let subtasks: [Issue]
    let statusOptions: [String]
    let subtaskIssueTypes: [IssueTypeMetadata]
    let assignableUsers: [JiraUser]
    let commentAuthorName: String?
    let currentUser: JiraUser?
    let isLoadingChangelog: Bool
    let isAddingComment: Bool
    let isCreatingIssue: Bool
    let onChangeStatus: (Issue.ID, String) -> Void
    let onUpdateSummary: (Issue.ID, String) async -> Bool
    let onUpdateDescription: (Issue.ID, String?) async -> Bool
    let onAddComment: (Issue.ID, String, IssueComment?) async -> Bool
    let onLoadSubtaskCreationOptions: () -> Void
    let onCreateSubtask: (Issue.ID, IssueCreationDraft) async -> Bool
    let onDeleteComment: (Issue.ID, String) -> Void
    let onDeleteIssue: (Issue.ID) -> Void
    let onAssignIssueToCurrentUser: (Issue.ID) -> Void
    let onUnassignIssue: (Issue.ID) -> Void
    let onAssignIssue: (Issue.ID, JiraUser) -> Void
    let onSelectIssue: (Issue.ID) -> Void
    let onDetailsPageVisible: (Issue.ID) -> Void

    @State private var selectedPage: IssueDetailPage = .subtasks
    @State private var replyingToComment: IssueComment?
    @State private var commentToDelete: IssueComment?
    @State private var isDeleteIssueConfirmationPresented = false

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            if let issue {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header(issue)

                        fixedOverview(issue)
                            .padding(.horizontal, 24)

                        pageTabs(issue)
                            .padding(.horizontal, 24)
                            .padding(.top, 22)
                            .padding(.bottom, 14)

                        selectedPageContent(issue)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 28)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .onChange(of: issue.id) { _, _ in
                    selectedPage = .subtasks
                    replyingToComment = nil
                    commentToDelete = nil
                    isDeleteIssueConfirmationPresented = false
                }
                .onChange(of: selectedPage) { _, page in
                    guard page == .history else { return }
                    onDetailsPageVisible(issue.id)
                }
            }
        }
    }

    private func header(_ issue: Issue) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                titleBlock(issue)

                Spacer(minLength: 12)

                issueActionsMenu(issue)
            }
            
            HStack(spacing: 8) {
                JiraInlineValuePickerRow(selection: Binding(
                    get: { issue.status },
                    set: { status in
                        guard status != issue.status else { return }
                        onChangeStatus(issue.id, status)
                    }
                ), statusColor: JiraStatusColor.resolved(for: issue.status)) {
                    ForEach(statusOptions, id: \.self) { status in
                        Text(status).tag(status)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)

                AssigneeAvatarButton(
                    assigneeName: issue.assigneeName,
                    assignableUsers: assignableUsers,
                    onAssignToCurrentUser: {
                        onAssignIssueToCurrentUser(issue.id)
                    },
                    onUnassign: {
                        onUnassignIssue(issue.id)
                    },
                    onAssign: { user in
                        onAssignIssue(issue.id, user)
                    }
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 18)
        .confirmationDialog(
            "Delete issue?",
            isPresented: $isDeleteIssueConfirmationPresented
        ) {
            Button("Delete", role: .destructive) {
                onDeleteIssue(issue.id)
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            if issue.subtaskCount > 0 {
                Text("This will delete \(issue.key) and its subtasks from Jira.")
            } else {
                Text("This will delete \(issue.key) from Jira.")
            }
        }
    }

    @ViewBuilder
    private func titleBlock(_ issue: Issue) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(issue.key)
                .font(.paragraphSSemiBold)
                .foregroundStyle(.secondary)

            editableSummary(issue)
        }
    }

    private func editableSummary(_ issue: Issue) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if issue.isSubtask, let parentIssue {
                Button {
                    onSelectIssue(parentIssue.id)
                } label: {
                    Text("\(parentIssue.summary) /")
                        .font(.headingL)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                .help("Open parent issue")
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                if issue.isSubtask {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.headingL)
                        .foregroundStyle(.secondary)
                }
                
                EditableIssueText(
                    text: issue.summary,
                    placeholder: "Untitled issue",
                    font: .headingL,
                    emptyFont: .headingL,
                    lineLimit: 1...4,
                    onCommit: { nextSummary in
                        guard let nextSummary else { return false }
                        return await onUpdateSummary(issue.id, nextSummary)
                    }
                )
            }
        }
    }

    private func issueActionsMenu(_ issue: Issue) -> some View {
        Menu {
            Button {
                onSelectIssue(issue.id)
            } label: {
                Label("Open", systemImage: "arrow.up.right.square")
            }

            Button {
                onSelectIssue(issue.id)
            } label: {
                Label("Edit", systemImage: "square.and.pencil")
            }

            Divider()

            Button(role: .destructive) {
                isDeleteIssueConfirmationPresented = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.paragraphM)
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 28)
                .background(JiraDesign.surface)
                .clipShape(.capsule)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Issue actions")
    }

    private func pageTabs(_ issue: Issue) -> some View {
        HStack(spacing: 12) {
            ForEach(IssueDetailPage.allCases) { page in
                Button {
                    selectedPage = page
                } label: {
                    HStack(spacing: 2) {
                        Text(page.title)
                            .font(.headingS)

                        if let count = tabCount(for: page, issue: issue), page != .history {
                            countBadge(count)
                        }
                    }
                    .foregroundStyle(page == selectedPage ? .primary : .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(page == selectedPage ? .isSelected : [])
            }
        }
    }

    private func tabCount(for page: IssueDetailPage, issue: Issue) -> Int? {
        switch page {
        case .subtasks:
            subtasks.count
        case .comments:
            issue.comments.count
        case .history:
            issue.changes.count
        }
    }

    @ViewBuilder
    private func selectedPageContent(_ issue: Issue) -> some View {
        switch selectedPage {
        case .subtasks:
            subtasksPage(issue)
        case .comments:
            commentsPage(issue)
        case .history:
            historyPage(issue)
        }
    }

    private func fixedOverview(_ issue: Issue) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            infoGrid(issue)

            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Description")

                EditableIssueText(
                    text: issue.descriptionText,
                    placeholder: "No description.",
                    font: .paragraphM,
                    emptyFont: .paragraphM,
                    lineLimit: 3...12,
                    onCommit: { nextDescription in
                        await onUpdateDescription(issue.id, nextDescription)
                    }
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .jiraPanel(radius: JiraDesign.controlRadius, padding: 18)
        }
    }

    private func subtasksPage(_ issue: Issue) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if subtasks.isEmpty {
                emptyText("No subtasks.")
            } else {
                VStack(spacing: 6) {
                    ForEach(subtasks) { subtask in
                        SubtaskRowView(subtask: subtask) {
                            onSelectIssue(subtask.id)
                        }
                    }
                }
            }

            InlineSubtaskComposerView(
                issueTypes: subtaskIssueTypes,
                currentUser: currentUser,
                isCreating: isCreatingIssue,
                onLoadIssueTypes: onLoadSubtaskCreationOptions,
                onCreate: { draft in
                    await onCreateSubtask(issue.id, draft)
                }
            )
        }
    }

    private func commentsPage(_ issue: Issue) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            CommentComposerView(
                authorName: commentAuthorName,
                replyingToComment: replyingToComment,
                isSubmitting: isAddingComment,
                onCancelReply: {
                    replyingToComment = nil
                },
                onSubmit: { bodyText in
                    let success = await onAddComment(issue.id, bodyText, replyingToComment)
                    if success {
                        replyingToComment = nil
                    }
                    return success
                }
            )

            if issue.comments.isEmpty {
                emptyText("No comments.")
            } else {
                VStack(spacing: 8) {
                    ForEach(rootComments(for: issue), id: \.id) { comment in
                        CommentRowView(comment: comment) {
                            replyingToComment = comment
                        } onDelete: {
                            commentToDelete = comment
                        }

                        let replies = replies(to: comment, in: issue)
                        if replies.isEmpty == false {
                            VStack(spacing: 6) {
                                ForEach(replies, id: \.id) { reply in
                                    CommentRowView(comment: reply) {
                                        replyingToComment = reply
                                    } onDelete: {
                                        commentToDelete = reply
                                    }
                                }
                            }
                            .padding(.leading, 36)
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete comment?",
            isPresented: Binding(
                get: { commentToDelete != nil },
                set: { isPresented in
                    if isPresented == false {
                        commentToDelete = nil
                    }
                }
            )
        ) {
            Button("Delete", role: .destructive) {
                if let commentToDelete {
                    onDeleteComment(issue.id, commentToDelete.id)
                }
                commentToDelete = nil
            }

            Button("Cancel", role: .cancel) {
                commentToDelete = nil
            }
        } message: {
            Text("This comment will be deleted from Jira.")
        }
    }

    private func rootComments(for issue: Issue) -> [IssueComment] {
        let knownIDs = Set(issue.comments.map(\.id))
        return issue.comments.filter { comment in
            guard let parentID = comment.parentID else { return true }
            return knownIDs.contains(parentID) == false
        }
    }

    private func replies(to parentComment: IssueComment, in issue: Issue) -> [IssueComment] {
        issue.comments.filter { $0.parentID == parentComment.id }
    }

    private func historyPage(_ issue: Issue) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if isLoadingChangelog {
                emptyText("Loading history...")
            } else if issue.changes.isEmpty {
                emptyText("No change history.")
            } else {
                VStack(spacing: 0) {
                    ForEach(issue.changes, id: \.id) { change in
                        ChangeRowView(change: change)
                    }
                }
            }
        }
    }

    private func infoGrid(_ issue: Issue) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
            detailRow("Type", issue.issueTypeName ?? (issue.isSubtask ? "Subtask" : "Issue"))
            detailRow("Priority", issue.priorityName ?? "No priority")
            detailRow("Sprint", issue.sprintName ?? "Backlog")
            detailRow("Reporter", issue.reporterName ?? "Unknown")
            if let createdAt = issue.createdAt {
                detailRow("Created", createdAt.formatted(date: .abbreviated, time: .shortened))
            }
            detailRow("Updated", issue.updatedAt.formatted(date: .abbreviated, time: .shortened))
            if let parentIssue {
                detailButtonRow("Parent", "\(parentIssue.key) · \(parentIssue.summary)") {
                    onSelectIssue(parentIssue.id)
                }
            } else if let parentKey = issue.parentKey {
                detailRow("Parent", parentKey)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .jiraPanel(radius: JiraDesign.controlRadius, padding: 18)
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title)
                .font(.labelS)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.paragraphM)
                .textSelection(.enabled)
        }
    }

    private func detailButtonRow(_ title: String, _ value: String, action: @escaping () -> Void) -> some View {
        GridRow {
            Text(title)
                .font(.labelS)
                .foregroundStyle(.secondary)
            Button(action: action) {
                Text(value)
                    .font(.paragraphM)
                    .lineLimit(1)
            }
            .buttonStyle(.plain)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headingXS)
            .foregroundStyle(.primary)
    }

    private func countBadge(_ count: Int) -> some View {
        Text("\(count)")
            .font(.labelS)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(JiraDesign.surface)
            .clipShape(.capsule)
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .font(.paragraphM)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
    }
}
