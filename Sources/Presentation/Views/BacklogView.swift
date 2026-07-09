import SwiftUI

struct BacklogView: View {
    let issues: [Issue]
    @Binding var selectedIssueID: Issue.ID?
    let isRefreshing: Bool
    let onRefresh: () -> Void
    @State private var selectedFocus: BacklogFocus = .backlog
    @State private var selectedSprintFilter: SprintFilter = .all

    var body: some View {
        VStack(spacing: 16) {
            toolbar

            if visibleIssues.isEmpty {
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
                        selectedIssueID: $selectedIssueID
                    )
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var visibleIssues: [Issue] {
        issues.filter { !$0.isDoneSprint }
    }

    private var filteredIssues: [Issue] {
        let filter = effectiveSprintFilter

        return visibleIssues.filter { issue in
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
        let activeSprintNames = Set(visibleIssues.compactMap { issue -> String? in
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
        Array(Set(visibleIssues.map(\.status))).sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
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

            JiraInlineValuePickerRow("Sprint", selection: $selectedSprintFilter) {
                ForEach(sprintFilterOptions) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .frame(maxWidth: 240, alignment: .trailing)

            if isRefreshing {
                ProgressView()
                    .controlSize(.small)
            }

            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.labelM)
                    .frame(width: 28, height: 28)
                    .background(JiraDesign.surface)
                    .clipShape(.capsule)
            }
            .buttonStyle(.borderless)
            .help("Refresh")
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
            Text("No issues")
                .font(.headingS)
            Text("Change the sprint filter to show matching tickets.")
                .font(.paragraphM)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var kanbanColumns: [KanbanColumn] {
        let groups = Dictionary(grouping: filteredIssues, by: \.status)

        return statusOptions.map { status in
            KanbanColumn(
                title: status,
                issues: (groups[status] ?? []).sorted { $0.updatedAt > $1.updatedAt }
            )
        }
    }

    private func titleColor(_ focus: BacklogFocus) -> Color {
        if focus == selectedFocus {
            return .primary
        }

        return .secondary.opacity(0.6)
    }
}

private struct IssueGroup: Identifiable {
    var id: String { title }
    let title: String
    let issues: [Issue]
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

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(columns) { column in
                    KanbanColumnView(
                        column: column,
                        selectedIssueID: $selectedIssueID
                    )
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
        .scrollIndicators(.hidden)
    }
}

private struct KanbanColumnView: View {
    let column: KanbanColumn
    @Binding var selectedIssueID: Issue.ID?

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
                LazyVStack(spacing: 8) {
                    ForEach(column.issues) { issue in
                        KanbanIssueCard(
                            issue: issue,
                            isSelected: selectedIssueID == issue.id
                        )
                        .onTapGesture {
                            selectedIssueID = issue.id
                        }
                    }
                }
            }
            .scrollIndicators(.never)
        }
        .frame(width: 300)
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

private extension Issue {
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
