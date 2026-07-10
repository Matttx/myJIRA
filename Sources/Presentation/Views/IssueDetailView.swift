import SwiftUI

struct IssueDetailView: View {
    let issue: Issue?
    let parentIssue: Issue?
    let subtasks: [Issue]
    let isLoadingChangelog: Bool
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

                        if let count = tabCount(for: page, issue: issue) {
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
            detailRow("Status", issue.status)
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

private enum IssueDetailPage: CaseIterable, Identifiable {
    case subtasks
    case comments
    case history

    var id: Self { self }

    var title: String {
        switch self {
        case .subtasks:
            "Subtasks"
        case .comments:
            "Comments"
        case .history:
            "History"
        }
    }
}

private struct CommentRowView: View {
    let comment: IssueComment

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            InitialsAvatar(name: comment.authorName)

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

private struct ChangeRowView: View {
    let change: IssueChange

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            InitialsAvatar(name: change.authorName)

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
                changeValue(
                    oldValue,
                    foreground: Color.red.opacity(0.78),
                    background: Color.red.opacity(0.08),
                    allowsWrapping: true
                )

                Image(systemName: "arrow.down")
                    .font(.paragraphXS)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 10)

                changeValue(
                    newValue,
                    foreground: Color.green.opacity(0.78),
                    background: Color.green.opacity(0.09),
                    allowsWrapping: true
                )
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                changeValue(
                    oldValue,
                    foreground: Color.red.opacity(0.78),
                    background: Color.red.opacity(0.08),
                    allowsWrapping: false
                )

                Image(systemName: "arrow.right")
                    .font(.paragraphXS)
                    .foregroundStyle(.secondary)

                changeValue(
                    newValue,
                    foreground: Color.green.opacity(0.78),
                    background: Color.green.opacity(0.09),
                    allowsWrapping: false
                )
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

private struct InitialsAvatar: View {
    let name: String?

    var body: some View {
        Text(initials)
            .font(.labelS)
            .foregroundStyle(.primary)
            .frame(width: 30, height: 30)
            .overlay {
                Circle()
                    .stroke(JiraDesign.hairline, lineWidth: 1)
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

private struct SubtaskRowView: View {
    let subtask: Issue
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(subtask.key)
                        .font(.paragraphSSemiBold)
                        .foregroundStyle(.secondary)

                    Text(subtask.summary)
                        .font(.paragraphM)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Text(subtask.status)
                    .font(.paragraphS)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(JiraDesign.surface)
                    .clipShape(.capsule)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(JiraDesign.surface)
            .clipShape(RoundedRectangle(cornerRadius: JiraDesign.rowRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: JiraDesign.rowRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(proposal: proposal, subviews: subviews)
        return CGSize(
            width: proposal.width ?? rows.map(\.width).max() ?? 0,
            height: rows.map(\.height).reduce(0, +) + CGFloat(max(0, rows.count - 1)) * spacing
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(proposal: ProposedViewSize(width: bounds.width, height: nil), subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func rows(proposal: ProposedViewSize, subviews: Subviews) -> [FlowRow] {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        var rows: [FlowRow] = []
        var current = FlowRow()

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let proposedWidth = current.width == 0 ? size.width : current.width + spacing + size.width

            if proposedWidth > maxWidth, !current.indices.isEmpty {
                rows.append(current)
                current = FlowRow()
            }

            current.indices.append(index)
            current.width = current.width == 0 ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
        }

        if !current.indices.isEmpty {
            rows.append(current)
        }

        return rows
    }
}

private struct FlowRow {
    var indices: [Int] = []
    var width: CGFloat = 0
    var height: CGFloat = 0
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
