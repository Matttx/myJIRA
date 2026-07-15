import Foundation
import SwiftUI

struct KanbanIssueCard: View {
    let issue: Issue
    let isSelected: Bool
    let onOpen: () -> Void

    @State private var isHovering = false

    var body: some View {
        let statusColor = JiraStatusColor.resolved(for: issue.status)

        VStack(alignment: .leading, spacing: 10) {
            metadataRow

            Text(issue.summary)
                .font(.paragraphM)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            footerRow
        }
        .foregroundStyle(isSelected ? Color.foreground : Color.primary)
        .padding(12)
        .background(isSelected ? JiraDesign.accent : JiraDesign.surface)
        .clipShape(RoundedRectangle(cornerRadius: JiraDesign.rowRadius, style: .continuous))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(statusColor.accent.opacity(isSelected ? 0.9 : 0.7))
                .frame(width: 3)
                .padding(.vertical, 10)
        }
        .contentShape(RoundedRectangle(cornerRadius: JiraDesign.rowRadius, style: .continuous))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
    }

    private var metadataRow: some View {
        HStack(spacing: 8) {
            Text(issue.key)
                .font(.paragraphSSemiBold)
                .foregroundStyle(isSelected ? Color.foreground.opacity(0.72) : .secondary)

            Spacer(minLength: 0)

            if issue.subtaskCount > 0 {
                SubtaskCountBadge(count: issue.subtaskCount, isSelected: isSelected)
            }

            actionMenu
                .opacity(isHovering ? 1 : 0)
                .allowsHitTesting(isHovering)
                .animation(.easeOut(duration: 0.12), value: isHovering)
        }
    }

    private var footerRow: some View {
        HStack(spacing: 8) {
            Spacer(minLength: 0)

            if let assigneeName = issue.assigneeName {
                Text(assigneeName)
                    .font(.paragraphS)
                    .foregroundStyle(secondaryForeground)
                    .lineLimit(1)
                    .frame(maxWidth: 96, alignment: .trailing)
            }

            if let sprintName = issue.trimmedSprintName {
                Text(sprintName)
                    .font(.paragraphXS)
                    .foregroundStyle(secondaryForeground)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(footerBadgeBackground)
                    .clipShape(.capsule)
            }

            Text(storyPointsText)
                .font(.paragraphXS)
                .foregroundStyle(secondaryForeground)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(footerBadgeBackground)
                .clipShape(.capsule)
        }
    }

    private var actionMenu: some View {
        Menu {
            Button {
                onOpen()
            } label: {
                Label("Open", systemImage: "arrow.up.right.square")
            }

            Button {
                onOpen()
            } label: {
                Label("Edit", systemImage: "square.and.pencil")
            }

            Divider()

            Button(role: .destructive) {
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .disabled(true)
        } label: {
            Image(systemName: "ellipsis")
                .font(.paragraphS)
                .foregroundStyle(secondaryForeground)
                .frame(width: 26, height: 24)
                .background(footerBadgeBackground)
                .clipShape(.capsule)
        }
        .buttonStyle(.plain)
        .help("Issue actions")
    }

    private var secondaryForeground: Color {
        isSelected ? Color.foreground.opacity(0.72) : .secondary
    }

    private var footerBadgeBackground: Color {
        isSelected ? Color.foreground.opacity(0.12) : JiraDesign.surface
    }

    private var storyPointsText: String {
        guard let storyPoints = issue.storyPoints else {
            return "-"
        }

        if storyPoints.rounded() == storyPoints {
            return "\(Int(storyPoints)) SP"
        }

        return String(format: "%.1f SP", storyPoints)
    }
}
