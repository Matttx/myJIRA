import SwiftUI

struct AssigneeAvatarButton: View {
    let assigneeName: String?
    var isSelected = false
    var assignableUsers: [JiraUser] = []
    let onAssignToCurrentUser: () -> Void
    let onUnassign: () -> Void
    var onAssign: (JiraUser) -> Void = { _ in }

    var body: some View {
        Menu {
            selectedAssigneeMenuItem

            Divider()

            Button {
                onAssignToCurrentUser()
            } label: {
                Label("Assign to me", systemImage: "person.crop.circle.badge.checkmark")
            }

            ForEach(selectableUsers, id: \.accountID) { user in
                Button {
                    onAssign(user)
                } label: {
                    Text(user.displayName)
                }
            }
            
            Divider()
            
            Button {
                onUnassign()
            } label: {
                Label("Unassign", systemImage: "person.crop.circle.badge.xmark")
            }
            .disabled(assigneeName == nil)
            
        } label: {
            label
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private var selectableUsers: [JiraUser] {
        guard let assigneeName else {
            return assignableUsers
        }

        return assignableUsers.filter { user in
            user.displayName.localizedCaseInsensitiveCompare(assigneeName) != .orderedSame
        }
    }

    @ViewBuilder
    private var selectedAssigneeMenuItem: some View {
        if let assigneeName {
            Label(assigneeName, systemImage: "checkmark")
                .font(.paragraphS)
        } else {
            Label("Unassigned", systemImage: "checkmark")
                .font(.paragraphS)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var label: some View {
        if let assigneeName {
            JiraInitialsAvatar(name: assigneeName, isSelected: isSelected)
        } else {
            Image(systemName: "person")
                .font(.paragraphS)
                .foregroundStyle(isSelected ? Color.foreground.opacity(0.72) : .secondary)
                .frame(width: 30, height: 30)
                .background(isSelected ? Color.foreground.opacity(0.12) : JiraDesign.surface)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(isSelected ? Color.foreground.opacity(0.18) : JiraDesign.hairline, lineWidth: 1)
                }
        }
    }
}
