import SwiftUI

struct InlineSubtaskComposerView: View {
    let issueTypes: [IssueTypeMetadata]
    let currentUser: JiraUser?
    let isCreating: Bool
    let onLoadIssueTypes: () -> Void
    let onCreate: (IssueCreationDraft) async -> Bool

    @State private var isEditing = false
    @State private var selectedIssueTypeID: IssueTypeMetadata.ID?
    @State private var summary = ""
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
            guard selectedIssueTypeID == nil else { return }
            selectedIssueTypeID = nextTypes.first?.id
        }
    }

    private var createButton: some View {
        Button {
            onLoadIssueTypes()
            selectDefaultTypeIfNeeded()
            isEditing = true
            isSummaryFocused = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.paragraphS)
                    .frame(width: 30, height: 30)
                    .background(JiraDesign.surface)
                    .clipShape(Circle())

                Text("Create subtask")
                    .font(.paragraphM)

                Spacer()
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(JiraDesign.surface)
            .clipShape(RoundedRectangle(cornerRadius: JiraDesign.rowRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var editingRow: some View {
        HStack(spacing: 10) {
            issueTypePicker

            TextField("Subtask title", text: $summary)
                .textFieldStyle(.plain)
                .font(.paragraphM)
                .focused($isSummaryFocused)
                .onSubmit {
                    Task { await commit() }
                }

            Spacer(minLength: 8)
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
        .help(selectedIssueType?.name ?? "Subtask type")
        .onTapGesture {
            onLoadIssueTypes()
        }
    }

    private var assigneeToggle: some View {
        Button {
            shouldAssignToMe.toggle()
        } label: {
            if shouldAssignToMe {
                JiraInitialsAvatar(name: currentUser?.displayName ?? "Me")
            } else {
                Image(systemName: "person")
                    .font(.paragraphS)
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(JiraDesign.surface)
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(JiraDesign.hairline, lineWidth: 1)
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
            if isCreating {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "checkmark")
                    .font(.labelM)
            }
        }
        .buttonStyle(.plain)
        .frame(width: 28, height: 28)
        .background(canCommit ? JiraDesign.accent : JiraDesign.surface)
        .foregroundStyle(canCommit ? JiraDesign.foreground : .secondary)
        .clipShape(.capsule)
        .disabled(!canCommit || isCreating)
        .help("Create")
    }

    private var cancelButton: some View {
        Button {
            reset()
        } label: {
            Image(systemName: "xmark")
                .font(.labelM)
        }
        .buttonStyle(.plain)
        .frame(width: 28, height: 28)
        .background(JiraDesign.surface)
        .clipShape(.capsule)
        .help("Cancel")
    }

    private var selectedIssueType: IssueTypeMetadata? {
        let id = selectedIssueTypeID ?? issueTypes.first?.id
        return issueTypes.first { $0.id == id }
    }

    private var canCommit: Bool {
        !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && selectedIssueType != nil
    }

    private func commit() async {
        guard canCommit, let issueType = selectedIssueType else { return }

        let created = await onCreate(IssueCreationDraft(
            issueTypeID: issueType.id,
            summary: summary,
            descriptionText: nil,
            storyPoints: nil,
            targetSprintID: nil,
            parentIssueKey: nil,
            assignToCurrentUser: shouldAssignToMe
        ))

        if created {
            reset()
        }
    }

    private func reset() {
        isEditing = false
        summary = ""
        shouldAssignToMe = false
    }

    private func selectDefaultTypeIfNeeded() {
        guard selectedIssueTypeID == nil, let firstType = issueTypes.first else { return }
        selectedIssueTypeID = firstType.id
    }
}
