import SwiftUI

struct IssueDetailView: View {
    let issue: Issue?
    let parentIssue: Issue?
    let subtasks: [Issue]
    let onSelectIssue: (Issue.ID) -> Void

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            if let issue {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(issue.key)
                                .font(.paragraphSSemiBold)
                                .foregroundStyle(.secondary)

                            Text(issue.summary)
                                .font(.headingL)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
                            detailRow("Status", issue.status)
                            detailRow("Sprint", issue.sprintName ?? "Backlog")
                            detailRow("Assignee", issue.assigneeName ?? "Unassigned")
                            detailRow("Updated", issue.updatedAt.formatted(date: .abbreviated, time: .shortened))
                            if let parentIssue {
                                detailButtonRow("Parent", "\(parentIssue.key) · \(parentIssue.summary)") {
                                    onSelectIssue(parentIssue.id)
                                }
                            } else if let parentKey = issue.parentKey {
                                detailRow("Parent", parentKey)
                            }
                        }
                        .jiraPanel(radius: JiraDesign.controlRadius, padding: 18)

                        if !subtasks.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 8) {
                                    Text("SUBTASKS")
                                        .font(.headingXS)
                                    Text("\(subtasks.count)")
                                        .font(.labelS)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 4)
                                        .background(JiraDesign.surface)
                                        .clipShape(.capsule)
                                }

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
                    .padding(28)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title)
                .font(.labelS)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.paragraphM)
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
