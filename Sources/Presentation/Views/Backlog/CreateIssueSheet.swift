import SwiftUI

struct CreateIssueSheet: View {
    let issueTypes: [IssueTypeMetadata]
    let sprintOptions: [IssueSprintOption]
    let initialTargetSprintID: Int?
    let creationMetadata: IssueCreationMetadata?
    let isLoading: Bool
    let isCreating: Bool
    let onLoadIssueTypes: () -> Void
    let onLoadMetadata: (IssueTypeMetadata.ID) -> Void
    let onCreate: (IssueCreationDraft) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var selectedIssueTypeID: IssueTypeMetadata.ID?
    @State private var summary = ""
    @State private var descriptionText = ""
    @State private var storyPoints = ""
    @State private var selectedTargetSprintID: Int?
    @State private var shouldAssignToMe = false
    @State private var didRequestInitialLoad = false
    @FocusState private var isSummaryFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            formFields
            metadataState
            footer
        }
        .padding(24)
        .frame(width: 520)
        .onAppear(perform: loadInitialOptionsIfNeeded)
        .onChange(of: issueTypes) { _, nextTypes in
            guard selectedIssueTypeID == nil else { return }
            selectedIssueTypeID = nextTypes.first?.id
        }
        .task {
            isSummaryFocused = true
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Create issue")
                .font(.headingL)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.labelM)
            }
            .buttonStyle(.plain)
            .help("Close")
        }
    }

    private var formFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Summary", text: $summary)
                .jiraCapsuleFieldStyle()
                .focused($isSummaryFocused)

            HStack(spacing: 10) {
                IssueTypeIcon(name: selectedIssueType?.name)

                JiraInlineValuePickerRow("Type", selection: Binding(
                    get: { selectedIssueTypeID ?? issueTypes.first?.id ?? "" },
                    set: { issueTypeID in
                        selectedIssueTypeID = issueTypeID
                        onLoadMetadata(issueTypeID)
                    }
                )) {
                    ForEach(issueTypes) { issueType in
                        Text(issueType.name).tag(issueType.id)
                    }
                }
                .disabled(issueTypes.isEmpty || isLoading || isCreating)

                JiraInlineValuePickerRow("Sprint", selection: $selectedTargetSprintID) {
                    ForEach(sprintOptions) { option in
                        Text(option.title).tag(option.sprintID)
                    }
                }
                .disabled(sprintOptions.count <= 1 || isCreating)

                storyPointsField

                Button {
                    shouldAssignToMe.toggle()
                } label: {
                    Image(systemName: shouldAssignToMe ? "person.fill.checkmark" : "person")
                        .font(.paragraphS)
                        .frame(width: 30, height: 30)
                        .background(JiraDesign.surface)
                        .clipShape(Circle())
                        .overlay {
                            Circle()
                                .stroke(JiraDesign.hairline, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .help(shouldAssignToMe ? "Leave unassigned" : "Assign to me")
            }

            TextEditor(text: $descriptionText)
                .font(.paragraphM)
                .scrollContentBackground(.hidden)
                .padding(12)
                .frame(height: 130)
                .background(JiraDesign.surface)
                .clipShape(RoundedRectangle(cornerRadius: JiraDesign.controlRadius, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if descriptionText.isEmpty {
                        Text("Description")
                            .font(.paragraphM)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 17)
                            .padding(.vertical, 20)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    private var storyPointsField: some View {
        HStack(spacing: 6) {
            Text("SP")
                .font(.labelS)
                .foregroundStyle(.secondary)

            TextField("-", text: $storyPoints)
                .textFieldStyle(.plain)
                .font(.paragraphS)
                .frame(width: 34)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(JiraDesign.surface)
        .clipShape(.capsule)
        .help("Story points")
    }

    @ViewBuilder
    private var metadataState: some View {
        if isLoading {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Loading Jira fields")
                    .font(.paragraphS)
                    .foregroundStyle(.secondary)
            }
        } else if issueTypes.isEmpty {
            Text("No issue type available for this project.")
                .font(.paragraphS)
                .foregroundStyle(.secondary)
        } else if !unsupportedRequiredFields.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Jira requires unsupported fields for this issue type:")
                    .font(.paragraphS)
                    .foregroundStyle(.secondary)

                ForEach(unsupportedRequiredFields) { field in
                    Text("- \(field.name)")
                        .font(.paragraphS)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(JiraDesign.surface)
            .clipShape(RoundedRectangle(cornerRadius: JiraDesign.compactRadius, style: .continuous))
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(JiraSecondaryButtonStyle(expandsToMaxWidth: false))

            Button {
                Task { await createIssue() }
            } label: {
                if isCreating {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Create")
                }
            }
            .buttonStyle(JiraPrimaryButtonStyle(expandsToMaxWidth: false))
            .disabled(!canCreate)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var unsupportedRequiredFields: [IssueCreationField] {
        creationMetadata?.unsupportedRequiredFields ?? []
    }

    private var selectedIssueType: IssueTypeMetadata? {
        let id = selectedIssueTypeID ?? issueTypes.first?.id
        return issueTypes.first { $0.id == id }
    }

    private var canCreate: Bool {
        selectedIssueTypeID != nil
            && !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && normalizedStoryPoints != nil
            && unsupportedRequiredFields.isEmpty
            && !isLoading
            && !isCreating
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

    private func loadInitialOptionsIfNeeded() {
        guard !didRequestInitialLoad else { return }
        didRequestInitialLoad = true
        selectedIssueTypeID = selectedIssueTypeID ?? issueTypes.first?.id
        selectedTargetSprintID = initialTargetSprintID
        onLoadIssueTypes()
    }

    private func createIssue() async {
        guard let selectedIssueTypeID, let storyPoints = normalizedStoryPoints else { return }

        let created = await onCreate(IssueCreationDraft(
            issueTypeID: selectedIssueTypeID,
            summary: summary,
            descriptionText: descriptionText,
            storyPoints: storyPoints,
            targetSprintID: selectedTargetSprintID,
            parentIssueKey: nil,
            assignToCurrentUser: shouldAssignToMe
        ))

        if created {
            dismiss()
        }
    }
}
