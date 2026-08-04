import SwiftUI

struct IssueFilterSheet: View {
    let issues: [Issue]
    let currentUser: JiraUser?
    let onApply: (IssueFilterSelection) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: IssueFilterCategory = .assignee
    @State private var draft: IssueFilterSelection
    @State private var query = ""

    init(
        issues: [Issue],
        currentUser: JiraUser?,
        initialSelection: IssueFilterSelection,
        onApply: @escaping (IssueFilterSelection) -> Void
    ) {
        self.issues = issues
        self.currentUser = currentUser
        self.onApply = onApply
        _draft = State(initialValue: initialSelection)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            HStack(spacing: 0) {
                categoryList

                Divider()

                optionList
            }

            Divider()

            footer
        }
        .frame(width: 620, height: 470)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.headingS)
                .foregroundStyle(JiraDesign.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("Filtrer les tickets")
                    .font(.headingS)
                Text("Affinez le backlog et le kanban")
                    .font(.paragraphS)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.labelM)
            }
            .buttonStyle(.borderless)
            .frame(width: 28, height: 28)
            .jiraGlass(shape: .circle, interactive: true)
            .keyboardShortcut(.cancelAction)
        }
        .padding(20)
    }

    private var categoryList: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(IssueFilterCategory.allCases) { category in
                Button {
                    selectedCategory = category
                    query = ""
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: category.icon)
                            .frame(width: 16)

                        Text(category.title)
                            .font(.paragraphM)

                        Spacer()

                        if selectedCount(for: category) > 0 {
                            Text("\(selectedCount(for: category))")
                                .font(.labelS)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(JiraDesign.accent.opacity(0.2))
                                .clipShape(.capsule)
                        }
                    }
                    .foregroundStyle(selectedCategory == category ? .primary : .secondary)
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(selectedCategory == category ? JiraDesign.accent.opacity(0.08) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: JiraDesign.compactRadius, style: .continuous))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button("Tout effacer") {
                draft.removeAll()
            }
            .buttonStyle(.plain)
            .font(.paragraphS)
            .foregroundStyle(draft.isEmpty ? Color.secondary.opacity(0.45) : JiraDesign.accent)
            .disabled(draft.isEmpty)
        }
        .padding(16)
        .frame(width: 190)
    }

    private var optionList: some View {
        VStack(spacing: 12) {
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Rechercher dans \(selectedCategory.title.lowercased())", text: $query)
                    .textFieldStyle(.plain)
                    .font(.paragraphM)

                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 13)
            .frame(height: 38)
            .jiraGlass(shape: .capsule, interactive: true)

            if filteredOptions.isEmpty {
                ContentUnavailableView(
                    "Aucun résultat",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text("Aucune valeur ne correspond à votre recherche.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredOptions) { option in
                            optionRow(option)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            Text(resultSummary)
                .font(.paragraphS)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Annuler") {
                dismiss()
            }
            .buttonStyle(JiraSecondaryButtonStyle(expandsToMaxWidth: false))

            Button("Appliquer") {
                onApply(draft)
                dismiss()
            }
            .buttonStyle(JiraPrimaryButtonStyle(expandsToMaxWidth: false))
            .keyboardShortcut(.defaultAction)
        }
        .padding(16)
    }

    private func optionRow(_ option: IssueFilterOption) -> some View {
        let isSelected = selection(for: selectedCategory).contains(option.id)

        return Button {
            toggle(option.id, in: selectedCategory)
        } label: {
            HStack(spacing: 11) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.paragraphM)
                    .foregroundStyle(isSelected ? JiraDesign.accent : .secondary)

                if selectedCategory == .assignee {
                    JiraInitialsAvatar(name: option.title)
                        .scaleEffect(0.8)
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: selectedCategory.icon)
                        .font(.paragraphS)
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                }

                Text(option.title)
                    .font(.paragraphM)
                    .foregroundStyle(.primary)

                if option.isCurrentUser {
                    Text("Vous")
                        .font(.labelS)
                        .foregroundStyle(JiraDesign.accent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(JiraDesign.accent.opacity(0.14))
                        .clipShape(.capsule)
                }

                Spacer()

                Text("\(option.issueCount)")
                    .font(.paragraphS)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .frame(height: 38)
            .background(isSelected ? JiraDesign.accent.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: JiraDesign.compactRadius, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var filteredOptions: [IssueFilterOption] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return options }
        return options.filter { $0.title.localizedCaseInsensitiveContains(trimmedQuery) }
    }

    private var options: [IssueFilterOption] {
        switch selectedCategory {
        case .assignee:
            let grouped = Dictionary(grouping: issues) { issue in
                issue.assigneeAccountID ?? issue.assigneeName ?? IssueFilterSelection.unassignedID
            }
            return grouped.map { id, matchingIssues in
                let name = matchingIssues.first?.assigneeName ?? "Non assigné"
                return IssueFilterOption(
                    id: id,
                    title: name,
                    issueCount: matchingIssues.count,
                    isCurrentUser: id == currentUser?.accountID
                )
            }.sorted(by: optionSort)
        case .status:
            return stringOptions(issues.map(\.status))
        case .issueType:
            return stringOptions(issues.compactMap(\.issueTypeName))
        case .priority:
            return stringOptions(issues.compactMap(\.priorityName))
        case .labels:
            return stringOptions(issues.flatMap(\.labels))
        }
    }

    private func stringOptions(_ values: [String]) -> [IssueFilterOption] {
        let counts = values.reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
        return counts.map { IssueFilterOption(id: $0.key, title: $0.key, issueCount: $0.value) }
            .sorted(by: optionSort)
    }

    private func optionSort(_ lhs: IssueFilterOption, _ rhs: IssueFilterOption) -> Bool {
        if lhs.id == IssueFilterSelection.unassignedID { return true }
        if rhs.id == IssueFilterSelection.unassignedID { return false }
        if lhs.isCurrentUser != rhs.isCurrentUser { return lhs.isCurrentUser }
        return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
    }

    private func selection(for category: IssueFilterCategory) -> Set<String> {
        switch category {
        case .assignee: draft.assignees
        case .status: draft.statuses
        case .issueType: draft.issueTypes
        case .priority: draft.priorities
        case .labels: draft.labels
        }
    }

    private func selectedCount(for category: IssueFilterCategory) -> Int {
        selection(for: category).count
    }

    private func toggle(_ value: String, in category: IssueFilterCategory) {
        switch category {
        case .assignee: draft.assignees.toggleMembership(of: value)
        case .status: draft.statuses.toggleMembership(of: value)
        case .issueType: draft.issueTypes.toggleMembership(of: value)
        case .priority: draft.priorities.toggleMembership(of: value)
        case .labels: draft.labels.toggleMembership(of: value)
        }
    }

    private var resultSummary: String {
        let count = issues.filter(draft.matches).count
        return "\(count) ticket\(count == 1 ? "" : "s") correspondant\(count == 1 ? "" : "s")"
    }
}

private enum IssueFilterCategory: String, CaseIterable, Identifiable {
    case assignee
    case status
    case issueType
    case priority
    case labels

    var id: String { rawValue }

    var title: String {
        switch self {
        case .assignee: "Personne assignée"
        case .status: "État"
        case .issueType: "Type de ticket"
        case .priority: "Priorité"
        case .labels: "Étiquettes"
        }
    }

    var icon: String {
        switch self {
        case .assignee: "person"
        case .status: "circle.dashed"
        case .issueType: "square.stack.3d.up"
        case .priority: "flag"
        case .labels: "tag"
        }
    }
}

private struct IssueFilterOption: Identifiable {
    let id: String
    let title: String
    let issueCount: Int
    var isCurrentUser = false
}

private extension Set {
    mutating func toggleMembership(of element: Element) {
        if contains(element) {
            remove(element)
        } else {
            insert(element)
        }
    }
}
