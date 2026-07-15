import SwiftUI

struct InlineIssueComposer: View {
    let issueTypes: [IssueTypeMetadata]
    let currentUser: JiraUser?
    let defaultStatus: String?
    let targetSprintID: Int?
    let onLoadIssueTypes: () -> Void
    let onLoadMetadata: (IssueTypeMetadata.ID) -> Void
    let onCreate: (IssueCreationDraft) async -> Bool

    @State private var isEditing = false
    @State private var selectedIssueTypeID: IssueTypeMetadata.ID?
    @State private var summary = ""
    @State private var storyPoints = ""
    @State private var shouldAssignToMe = false
    @FocusState private var isSummaryFocused: Bool

    var body: some View {
        Group {
            if isEditing {
                editingRow
            } else {
                createButton
            }
        }
        .onChange(of: issueTypes) { _, nextTypes in
            guard selectedIssueTypeID == nil, let firstType = nextTypes.first else { return }
            selectedIssueTypeID = firstType.id
        }
    }

    private var createButton: some View {
        HStack(spacing: 10) {
            issueTypePicker

            Button {
                onLoadIssueTypes()
                selectDefaultTypeIfNeeded()
                isEditing = true
                isSummaryFocused = true
            } label: {
                Text("Create issue")
                    .font(.paragraphM)
                Spacer()
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(JiraDesign.surface)
        .clipShape(RoundedRectangle(cornerRadius: JiraDesign.rowRadius, style: .continuous))
    }

    private var editingRow: some View {
        HStack(spacing: 12) {
            issueTypePicker

            VStack(alignment: .leading, spacing: 4) {
                Text(defaultStatus ?? "Default")
                    .font(.paragraphSSemiBold)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                TextField("What needs to be done?", text: $summary)
                    .textFieldStyle(.plain)
                    .font(.paragraphM)
                    .focused($isSummaryFocused)
                    .onSubmit {
                        Task { await commit() }
                    }
            }

            Spacer()
            storyPointsField
            assigneeToggle
            commitButton
            cancelButton
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(JiraDesign.surface)
        .clipShape(RoundedRectangle(cornerRadius: JiraDesign.rowRadius, style: .continuous))
    }

    private var issueTypePicker: some View {
        Menu {
            ForEach(issueTypes) { issueType in
                Button {
                    selectedIssueTypeID = issueType.id
                    onLoadMetadata(issueType.id)
                } label: {
                    Label(issueType.name, systemImage: IssueTypeIcon.systemName(for: issueType.name))
                }
            }
        } label: {
            IssueTypeIcon(name: selectedIssueType?.name)
        }
        .buttonStyle(.plain)
        .disabled(issueTypes.isEmpty)
        .frame(width: 30, height: 30)
        .help(selectedIssueType?.name ?? "Issue type")
        .onTapGesture {
            onLoadIssueTypes()
        }
    }

    private var storyPointsField: some View {
        TextField("-", text: $storyPoints)
            .textFieldStyle(.plain)
            .font(.paragraphS)
            .frame(width: 12)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(JiraDesign.surface)
            .clipShape(.capsule)
            .help("Story points")
    }

    private var assigneeToggle: some View {
        Button {
            shouldAssignToMe.toggle()
        } label: {
            if shouldAssignToMe {
                JiraInitialsAvatar(name: currentUser?.displayName ?? "Me")
            } else {
                Image(systemName: "person")
                .frame(width: 30, height: 30)
                .background(JiraDesign.surface)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(Color.foreground.opacity(0.18), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .help(shouldAssignToMe ? "Leave unassigned" : "Assign to me")
    }

    private var commitButton: some View {
        Button {
            Task { await commit() }
        } label: {
            Image(systemName: "checkmark")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .font(.labelM)
        }
        .buttonStyle(.plain)
        .frame(width: 28, height: 28)
        .background(canCommit ? JiraDesign.accent : JiraDesign.surface)
        .foregroundStyle(canCommit ? JiraDesign.foreground : .secondary)
        .clipShape(.capsule)
        .disabled(!canCommit)
        .help("Create")
    }

    private var cancelButton: some View {
        Button {
            reset()
        } label: {
            Image(systemName: "xmark")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .font(.labelM)
        }
        .buttonStyle(.plain)
        .frame(width: 28, height: 28)
        .background(JiraDesign.surface)
        .clipShape(.capsule)
        .help("Cancel")
    }

    private var canCommit: Bool {
        !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && selectedIssueType != nil
            && normalizedStoryPoints != nil
    }

    private var selectedIssueType: IssueTypeMetadata? {
        let id = selectedIssueTypeID ?? issueTypes.first?.id
        return issueTypes.first { $0.id == id }
    }

    private var normalizedStoryPoints: Double?? {
        let trimmed = storyPoints.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        if trimmed.isEmpty {
            return .some(nil)
        }

        guard let value = Double(trimmed) else {
            return nil
        }

        return .some(value)
    }

    private func commit() async {
        guard canCommit, let issueType = selectedIssueType, let storyPoints = normalizedStoryPoints else { return }

        let created = await onCreate(IssueCreationDraft(
            issueTypeID: issueType.id,
            summary: summary,
            descriptionText: nil,
            storyPoints: storyPoints,
            targetSprintID: targetSprintID,
            assignToCurrentUser: shouldAssignToMe
        ))

        if created {
            reset()
        }
    }

    private func reset() {
        isEditing = false
        summary = ""
        storyPoints = ""
        shouldAssignToMe = false
    }

    private func selectDefaultTypeIfNeeded() {
        guard selectedIssueTypeID == nil, let firstType = issueTypes.first else { return }
        selectedIssueTypeID = firstType.id
    }
}
