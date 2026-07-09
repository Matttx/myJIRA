import SwiftUI

struct BacklogView: View {
    let issues: [Issue]
    @Binding var selectedIssueID: Issue.ID?
    let isRefreshing: Bool
    let onRefresh: () -> Void
    let onMoveIssue: (Issue.ID, String, Issue.ID?) -> Void
    @State private var selectedFocus: BacklogFocus = .backlog
    @State private var selectedSprintFilter: SprintFilter = .all
    @State private var searchQuery = ""
    @State private var statusOrder: [String] = []

    var body: some View {
        VStack(spacing: 16) {
            toolbar

            if browsableIssues.isEmpty && searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(spacing: 10) {
                    Text("No issues")
                        .font(.headingS)
                    Text("Refresh or select another project to load its backlog.")
                        .font(.paragraphM)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
            } else {
                switch selectedFocus {
                case .backlog:
                    if filteredIssues.isEmpty {
                        emptyFilterState
                    } else {
                        backlogList
                    }
                case .kanban:
                    KanbanBoardView(
                        columns: kanbanColumns,
                        selectedIssueID: $selectedIssueID,
                        onMoveIssue: onMoveIssue,
                        onMoveColumn: moveColumn
                    )
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            syncStatusOrder()
        }
        .onChange(of: statusOptions) { _, _ in
            syncStatusOrder()
        }
    }

    private var availableIssues: [Issue] {
        issues.filter { !$0.isDoneSprint }
    }

    private var browsableIssues: [Issue] {
        availableIssues.filter { !$0.isSubtask }
    }

    private var filteredIssues: [Issue] {
        if hasSearchQuery {
            return availableIssues.filter(matchesSearch)
        }

        let filter = effectiveSprintFilter

        return browsableIssues.filter { issue in
            switch filter {
            case .all:
                true
            case .backlog:
                issue.trimmedSprintName == nil
            case .sprint(let name):
                issue.trimmedSprintName == name
            }
        }
    }

    private var effectiveSprintFilter: SprintFilter {
        sprintFilterOptions.contains(selectedSprintFilter) ? selectedSprintFilter : .all
    }

    private var sprintFilterOptions: [SprintFilter] {
        let activeSprintNames = Set(browsableIssues.compactMap { issue -> String? in
            guard let sprintName = issue.trimmedSprintName else { return nil }
            if issue.isFutureSprint { return nil }
            return sprintName
        })

        let sprintFilters = activeSprintNames
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .map(SprintFilter.sprint)

        return [.all, .backlog] + sprintFilters
    }

    private var groupedIssues: [IssueGroup] {
        let groups = Dictionary(grouping: filteredIssues) { issue in
            issue.trimmedSprintName ?? "Backlog"
        }

        return groups
            .map { title, issues in
                IssueGroup(
                    title: title,
                    issues: issues.sorted { $0.updatedAt > $1.updatedAt }
                )
            }
            .sorted { lhs, rhs in
                if lhs.title == "Backlog" { return false }
                if rhs.title == "Backlog" { return true }
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
    }

    private var statusOptions: [String] {
        Array(Set(availableIssues.map(\.status))).sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
    }

    private var orderedStatusOptions: [String] {
        let knownStatuses = statusOrder.filter { statusOptions.contains($0) }
        let newStatuses = statusOptions.filter { !knownStatuses.contains($0) }
        return knownStatuses + newStatuses
    }

    private var hasSearchQuery: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var toolbar: some View {
        HStack(spacing: 16) {
            ForEach(BacklogFocus.allCases) { focus in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedFocus = focus
                    }
                } label: {
                    Text(focus.title)
                        .font(.headingL)
                        .foregroundStyle(titleColor(focus))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(focus == selectedFocus ? .isSelected : [])
            }

            Spacer()

            HStack(spacing: 8) {
                JiraSearchField(text: $searchQuery)
                    .frame(width: 260)
                    .onSubmit {
                        selectBestSearchMatch()
                    }

                JiraInlineValuePickerRow("Sprint", selection: $selectedSprintFilter) {
                    ForEach(sprintFilterOptions) { filter in
                        Text(filter.title).tag(filter)
                    }
                }

                

                Button(action: onRefresh) {
                    if isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.labelM)
                    }
                }
                .buttonStyle(.borderless)
                .frame(width: 28, height: 28)
                .background(JiraDesign.surface)
                .clipShape(.capsule)
                .help("Refresh")
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private var backlogList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                ForEach(groupedIssues) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text(group.title.uppercased())
                                .font(.headingXS)
                                .foregroundStyle(.primary)
                            Text("\(group.issues.count)")
                                .font(.labelS)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(JiraDesign.surface)
                                .clipShape(.capsule)
                        }
                        .padding(.horizontal, 4)

                        VStack(spacing: 6) {
                            ForEach(group.issues) { issue in
                                IssueRowView(
                                    issue: issue,
                                    isSelected: selectedIssueID == issue.id,
                                    statusOptions: statusOptions
                                )
                                .onTapGesture {
                                    selectedIssueID = issue.id
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
    }

    private var emptyFilterState: some View {
        VStack(spacing: 10) {
            Text(hasSearchQuery ? "No matching ticket" : "No issues")
                .font(.headingS)
            Text(hasSearchQuery ? "Try another key or summary." : "Change the sprint filter to show matching tickets.")
                .font(.paragraphM)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var kanbanColumns: [KanbanColumn] {
        return orderedStatusOptions.map { status in
            KanbanColumn(
                title: status,
                issues: filteredIssues.filter { $0.status == status }
            )
        }
    }

    private func titleColor(_ focus: BacklogFocus) -> Color {
        if focus == selectedFocus {
            return .primary
        }

        return .secondary.opacity(0.6)
    }

    private func matchesSearch(_ issue: Issue) -> Bool {
        let tokens = searchQuery
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)

        guard !tokens.isEmpty else { return true }

        let searchableText = [
            issue.key,
            issue.summary,
            issue.status,
            issue.assigneeName,
            issue.sprintName,
            issue.parentKey
        ]
        .compactMap(\.self)
        .joined(separator: " ")

        return tokens.allSatisfy { token in
            searchableText.localizedCaseInsensitiveContains(token)
        }
    }

    private func selectBestSearchMatch() {
        let normalizedQuery = searchQuery
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        guard !normalizedQuery.isEmpty else { return }

        let exactMatch = filteredIssues.first { issue in
            issue.key.uppercased() == normalizedQuery || issue.id.uppercased() == normalizedQuery
        }

        selectedIssueID = exactMatch?.id ?? filteredIssues.first?.id
    }

    private func syncStatusOrder() {
        let nextOrder = orderedStatusOptions
        if statusOrder != nextOrder {
            statusOrder = nextOrder
        }
    }

    private func moveColumn(_ title: String, before beforeTitle: String?) {
        var nextOrder = orderedStatusOptions
        guard let sourceIndex = nextOrder.firstIndex(of: title) else { return }

        nextOrder.remove(at: sourceIndex)

        if let beforeTitle, let targetIndex = nextOrder.firstIndex(of: beforeTitle) {
            nextOrder.insert(title, at: targetIndex)
        } else {
            nextOrder.append(title)
        }

        statusOrder = nextOrder
    }
}

private struct IssueGroup: Identifiable {
    var id: String { title }
    let title: String
    let issues: [Issue]
}

private struct JiraSearchField: View {
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

private struct KanbanColumn: Identifiable {
    var id: String { title }
    let title: String
    let issues: [Issue]
}

private enum BacklogFocus: String, CaseIterable, Identifiable {
    case backlog
    case kanban

    var id: String { rawValue }

    var title: String {
        switch self {
        case .backlog:
            "Backlog"
        case .kanban:
            "Kanban"
        }
    }
}

private enum SprintFilter: Hashable, Identifiable {
    case all
    case backlog
    case sprint(String)

    var id: String {
        switch self {
        case .all:
            "all"
        case .backlog:
            "backlog"
        case .sprint(let name):
            "sprint:\(name)"
        }
    }

    var title: String {
        switch self {
        case .all:
            "All"
        case .backlog:
            "Backlog"
        case .sprint(let name):
            name
        }
    }
}

private struct KanbanBoardView: View {
    let columns: [KanbanColumn]
    @Binding var selectedIssueID: Issue.ID?
    let onMoveIssue: (Issue.ID, String, Issue.ID?) -> Void
    let onMoveColumn: (String, String?) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(columns) { column in
                    KanbanColumnDropSlot(
                        beforeColumnTitle: column.title,
                        onMoveColumn: onMoveColumn
                    )

                    KanbanColumnView(
                        column: column,
                        selectedIssueID: $selectedIssueID,
                        onMoveIssue: onMoveIssue
                    )
                    .draggable(KanbanColumnDragPayload.prefix + column.title)
                }

                KanbanColumnDropSlot(
                    beforeColumnTitle: nil,
                    onMoveColumn: onMoveColumn
                )
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
        .scrollIndicators(.hidden)
    }
}

private struct KanbanColumnDropSlot: View {
    let beforeColumnTitle: String?
    let onMoveColumn: (String, String?) -> Void
    @State private var isTargeted = false

    var body: some View {
        RoundedRectangle(cornerRadius: JiraDesign.compactRadius, style: .continuous)
            .fill(isTargeted ? JiraDesign.accent : Color.clear)
            .frame(width: isTargeted ? 4 : 1)
            .frame(maxHeight: .infinity)
            .padding(.horizontal, isTargeted ? 8 : 6)
            .contentShape(Rectangle())
            .dropDestination(for: String.self) { payloads, _ in
                guard
                    let payload = payloads.first,
                    let draggedColumnTitle = KanbanColumnDragPayload.title(from: payload),
                    draggedColumnTitle != beforeColumnTitle
                else {
                    return false
                }

                onMoveColumn(draggedColumnTitle, beforeColumnTitle)
                return true
            } isTargeted: { targeted in
                withAnimation(.easeInOut(duration: 0.12)) {
                    isTargeted = targeted
                }
            }
    }
}

private enum KanbanColumnDragPayload {
    static let prefix = "myjira-column:"

    static func title(from payload: String) -> String? {
        guard payload.hasPrefix(prefix) else { return nil }
        return String(payload.dropFirst(prefix.count))
    }
}

private struct KanbanColumnView: View {
    let column: KanbanColumn
    @Binding var selectedIssueID: Issue.ID?
    let onMoveIssue: (Issue.ID, String, Issue.ID?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(column.title.uppercased())
                    .font(.headingXS)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text("\(column.issues.count)")
                    .font(.labelS)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(JiraDesign.surface)
                    .clipShape(.capsule)
            }
            .padding(.horizontal, 4)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(column.issues) { issue in
                        KanbanDropSlot(
                            status: column.title,
                            beforeIssueID: issue.id,
                            selectedIssueID: $selectedIssueID,
                            onMoveIssue: onMoveIssue
                        )

                        KanbanIssueCard(
                            issue: issue,
                            isSelected: selectedIssueID == issue.id
                        )
                        .onTapGesture {
                            selectedIssueID = issue.id
                        }
                        .draggable(issue.id)
                    }

                    KanbanDropSlot(
                        status: column.title,
                        beforeIssueID: nil,
                        selectedIssueID: $selectedIssueID,
                        onMoveIssue: onMoveIssue,
                        isEmptyColumn: column.issues.isEmpty
                    )
                }
            }
            .scrollIndicators(.never)
        }
        .frame(width: 300)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

private struct KanbanDropSlot: View {
    let status: String
    let beforeIssueID: Issue.ID?
    @Binding var selectedIssueID: Issue.ID?
    let onMoveIssue: (Issue.ID, String, Issue.ID?) -> Void
    var isEmptyColumn = false
    @State private var isTargeted = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: JiraDesign.compactRadius, style: .continuous)
                .fill(isTargeted ? JiraDesign.accent : Color.clear)
                .frame(height: isTargeted ? 4 : 1)
                .padding(.horizontal, isTargeted ? 0 : 10)
                .opacity(isTargeted ? 1 : 0)

            if isEmptyColumn {
                RoundedRectangle(cornerRadius: JiraDesign.rowRadius, style: .continuous)
                    .strokeBorder(isTargeted ? JiraDesign.accent : JiraDesign.hairline, style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .frame(height: 88)
                    .opacity(isTargeted ? 1 : 0.7)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: isEmptyColumn ? 96 : (isTargeted ? 18 : 8))
        .contentShape(Rectangle())
        .dropDestination(for: String.self) { issueIDs, _ in
            guard
                let issueID = issueIDs.first,
                KanbanColumnDragPayload.title(from: issueID) == nil
            else {
                return false
            }

            onMoveIssue(issueID, status, beforeIssueID)
            selectedIssueID = issueID
            return true
        } isTargeted: { targeted in
            withAnimation(.easeInOut(duration: 0.12)) {
                isTargeted = targeted
            }
        }
    }
}

private struct KanbanIssueCard: View {
    let issue: Issue
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(issue.key)
                    .font(.paragraphSSemiBold)
                    .foregroundStyle(isSelected ? Color.foreground.opacity(0.72) : .secondary)

                Spacer(minLength: 0)

                if let sprintName = issue.sprintName {
                    Text(sprintName)
                        .font(.paragraphXS)
                        .foregroundStyle(isSelected ? Color.foreground.opacity(0.72) : .secondary)
                        .lineLimit(1)
                }

                if issue.subtaskCount > 0 {
                    SubtaskCountBadge(count: issue.subtaskCount, isSelected: isSelected)
                }
            }

            Text(issue.summary)
                .font(.paragraphM)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            if let assigneeName = issue.assigneeName {
                Text(assigneeName)
                    .font(.paragraphS)
                    .foregroundStyle(isSelected ? Color.foreground.opacity(0.72) : .secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .foregroundStyle(isSelected ? Color.foreground : Color.primary)
        .padding(12)
        .background(isSelected ? JiraDesign.accent : JiraDesign.surface)
        .clipShape(RoundedRectangle(cornerRadius: JiraDesign.rowRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: JiraDesign.rowRadius, style: .continuous))
    }
}

private struct IssueRowView: View {
    let issue: Issue
    let isSelected: Bool
    let statusOptions: [String]

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(issue.key)
                    .font(.paragraphSSemiBold)
                    .foregroundStyle(isSelected ? Color.foreground.opacity(0.72) : .secondary)

                Text(issue.summary)
                    .font(.paragraphM)
                    .lineLimit(1)
            }

            Spacer()

            if let assigneeName = issue.assigneeName {
                Text(assigneeName)
                    .font(.paragraphS)
                    .foregroundStyle(isSelected ? Color.foreground.opacity(0.72) : .secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 120, alignment: .trailing)
            }

            if issue.subtaskCount > 0 {
                SubtaskCountBadge(count: issue.subtaskCount, isSelected: isSelected)
            }

            JiraInlineValuePickerRow(selection: Binding(
                get: { issue.status },
                set: { _ in }
            ), isProminent: isSelected) {
                ForEach(statusOptions, id: \.self) { status in
                    Text(status).tag(status)
                }
            }
            .frame(width: 132, alignment: .trailing)
        }
        .foregroundStyle(isSelected ? Color.foreground : Color.primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isSelected ? JiraDesign.accent : JiraDesign.surface)
        .clipShape(RoundedRectangle(cornerRadius: JiraDesign.rowRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: JiraDesign.rowRadius, style: .continuous))
    }
}

private struct SubtaskCountBadge: View {
    let count: Int
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "checklist")
                .font(.paragraphXS)
            Text("\(count)")
                .font(.paragraphXS)
        }
        .foregroundStyle(isSelected ? Color.foreground.opacity(0.72) : .secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isSelected ? Color.foreground.opacity(0.12) : JiraDesign.surface)
        .clipShape(.capsule)
    }
}

private extension Issue {
    var subtaskCount: Int {
        subtaskIDs.count
    }

    var trimmedSprintName: String? {
        guard let sprintName else { return nil }
        let trimmed = sprintName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var isDoneSprint: Bool {
        guard let sprintState else { return false }
        let normalized = sprintState.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "closed" || normalized == "done"
    }

    var isFutureSprint: Bool {
        guard let sprintState else { return false }
        return sprintState.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "future"
    }
}
