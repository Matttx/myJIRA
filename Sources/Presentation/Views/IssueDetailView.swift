import SwiftUI

struct IssueDetailView: View {
    let issue: Issue?
    let parentIssue: Issue?
    let subtasks: [Issue]
    let statusOptions: [String]
    let isLoadingChangelog: Bool
    let onChangeStatus: (Issue.ID, String) -> Void
    let onSelectIssue: (Issue.ID) -> Void
    let onDetailsPageVisible: (Issue.ID) -> Void

    @State private var selectedPage: IssueDetailPage = .subtasks

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
            VStack(alignment: .leading, spacing: 8) {
                Text(issue.key)
                    .font(.paragraphSSemiBold)
                    .foregroundStyle(.secondary)

                Text(issue.summary)
                    .font(.headingL)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
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
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 18)
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
            subtasksPage
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

                if let description = issue.descriptionText, !description.isEmpty {
                    Text(description)
                        .font(.paragraphM)
                        .lineSpacing(3)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    emptyText("No description.")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .jiraPanel(radius: JiraDesign.controlRadius, padding: 18)
        }
    }

    private var subtasksPage: some View {
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
        }
    }

    private func commentsPage(_ issue: Issue) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if issue.comments.isEmpty {
                emptyText("No comments.")
            } else {
                VStack(spacing: 10) {
                    ForEach(issue.comments, id: \.id) { comment in
                        CommentRowView(comment: comment)
                    }
                }
            }
        }
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
            detailRow("Assignee", issue.assigneeName ?? "Unassigned")
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
