import SwiftUI

struct IssueDetailView: View {
    let issue: Issue?

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            if let issue {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(issue.key)
                            .font(.paragraphSSemiBold)
                            .foregroundStyle(.secondary)

                        Text(issue.summary)
                            .font(.headingL)
                            .lineLimit(3)
                    }

                    Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
                        detailRow("Status", issue.status)
                        detailRow("Sprint", issue.sprintName ?? "Backlog")
                        detailRow("Assignee", issue.assigneeName ?? "Unassigned")
                        detailRow("Updated", issue.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    .jiraPanel(radius: JiraDesign.controlRadius, padding: 18)

                    Spacer()
                }
                .padding(28)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                VStack(spacing: 10) {
                    Text("No issue selected")
                        .font(.headingS)
                    Text("Select a ticket from the backlog to inspect its details.")
                        .font(.paragraphM)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
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
}
