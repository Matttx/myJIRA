import SwiftUI

struct BacklogView: View {
    let issues: [Issue]
    let kanbanColumnOrder: [String]
    let issueTypes: [IssueTypeMetadata]
    let creationMetadata: IssueCreationMetadata?
    let currentUser: JiraUser?
    let assignableUsers: [JiraUser]
    @Binding var selectedIssueID: Issue.ID?
    let isRefreshing: Bool
    let isLoadingIssueCreation: Bool
    let isCreatingIssue: Bool
    let onRefresh: () -> Void
    let onMoveIssue: (Issue.ID, String, Issue.ID?) -> Void
    let onUpdateStoryPoints: (Issue.ID, Double?) -> Void
    let onMoveColumn: (String, String?) -> Void
    let onAssignIssueToCurrentUser: (Issue.ID) -> Void
    let onUnassignIssue: (Issue.ID) -> Void
    let onAssignIssue: (Issue.ID, JiraUser) -> Void
    let onDeleteIssue: (Issue.ID) -> Void
    let onLoadIssueCreationOptions: () -> Void
    let onLoadCreationMetadata: (IssueTypeMetadata.ID) -> Void
    let onCreateIssue: (IssueCreationDraft) async -> Bool
    @State private var selectedFocus: BacklogFocus = .backlog
    @State private var selectedSprintFilter: SprintFilter = .all
    @State private var searchQuery = ""
    @State private var isCreateIssuePresented = false
    @State private var issueToDelete: Issue?

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
                        onMoveColumn: onMoveColumn,
                        onDeleteIssue: { issue in
                            issueToDelete = issue
                        },
                        onAssignIssueToCurrentUser: onAssignIssueToCurrentUser,
                        onUnassignIssue: onUnassignIssue,
                        assignableUsers: assignableUsers,
                        onAssignIssue: onAssignIssue
                    )
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $isCreateIssuePresented) {
            CreateIssueSheet(
                issueTypes: issueTypes,
                sprintOptions: issueSprintOptions,
                initialTargetSprintID: defaultCreationSprintID,
                creationMetadata: creationMetadata,
                isLoading: isLoadingIssueCreation,
                isCreating: isCreatingIssue,
                onLoadIssueTypes: onLoadIssueCreationOptions,
                onLoadMetadata: onLoadCreationMetadata,
                onCreate: onCreateIssue
            )
        }
        .confirmationDialog(
            "Delete issue?",
            isPresented: Binding(
                get: { issueToDelete != nil },
                set: { isPresented in
                    if isPresented == false {
                        issueToDelete = nil
                    }
                }
            )
        ) {
            Button("Delete", role: .destructive) {
                if let issueToDelete {
                    onDeleteIssue(issueToDelete.id)
                }
                issueToDelete = nil
            }

            Button("Cancel", role: .cancel) {
                issueToDelete = nil
            }
        } message: {
            if let issueToDelete, issueToDelete.subtaskCount > 0 {
                Text("This will delete \(issueToDelete.key) and its subtasks from Jira.")
            } else if let issueToDelete {
                Text("This will delete \(issueToDelete.key) from Jira.")
            } else {
                Text("This issue will be deleted from Jira.")
            }
        }
    }

    private var availableIssues: [Issue] {
        issues.filter { !$0.isDoneSprint && !$0.isCompletedIssue }
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

    private var issueSprintOptions: [IssueSprintOption] {
        let sprintOptions = browsableIssues
            .reduce(into: [Int: IssueSprintOption]()) { result, issue in
                guard let sprintID = issue.sprintID,
                      let sprintName = issue.trimmedSprintName,
                      !issue.isDoneSprint
                else { return }

                result[sprintID] = IssueSprintOption(sprintID: sprintID, title: sprintName)
            }
            .values
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }

        return [IssueSprintOption(sprintID: nil, title: "Backlog")] + sprintOptions
    }

    private var defaultCreationSprintID: Int? {
        switch effectiveSprintFilter {
        case .all, .backlog:
            return nil
        case .sprint(let name):
            return issueSprintOptions.first { option in
                option.title == name
            }?.sprintID
        }
    }

    private var groupedIssues: [IssueGroup] {
        let groups = Dictionary(grouping: filteredIssues) { issue in
            issue.trimmedSprintName ?? "Backlog"
        }

        return groups
            .map { title, issues in
                IssueGroup(
                    title: title,
                    sprintID: issues.first?.sprintID,
                    issues: issues
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
        let knownStatuses = kanbanColumnOrder.filter { statusOptions.contains($0) }
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

                Button {
                    isCreateIssuePresented = true
                } label: {
                    Image(systemName: "plus")
                        .font(.labelM)
                }
                .buttonStyle(.borderless)
                .frame(width: 28, height: 28)
                .background(JiraDesign.surface)
                .clipShape(.capsule)
                .help("Create issue")

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
                                    statusOptions: statusOptions,
                                    onChangeStatus: { status in
                                        onMoveIssue(issue.id, status, nil)
                                    },
                                    onUpdateStoryPoints: { storyPoints in
                                        onUpdateStoryPoints(issue.id, storyPoints)
                                    },
                                    onAssignToCurrentUser: {
                                        onAssignIssueToCurrentUser(issue.id)
                                    },
                                    onUnassign: {
                                        onUnassignIssue(issue.id)
                                    },
                                    assignableUsers: assignableUsers,
                                    onAssign: { user in
                                        onAssignIssue(issue.id, user)
                                    },
                                    onOpen: {
                                        selectedIssueID = issue.id
                                    },
                                    onDelete: {
                                        issueToDelete = issue
                                    }
                                )
                                .onTapGesture {
                                    selectedIssueID = issue.id
                                }
                            }

                            InlineIssueComposer(
                                issueTypes: issueTypes,
                                currentUser: currentUser,
                                defaultStatus: orderedStatusOptions.first,
                                targetSprintID: group.sprintID,
                                onLoadIssueTypes: onLoadIssueCreationOptions,
                                onLoadMetadata: onLoadCreationMetadata,
                                onCreate: onCreateIssue
                            )
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
}
