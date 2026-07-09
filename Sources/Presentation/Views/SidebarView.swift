import SwiftUI

struct SidebarView: View {
    let workspaces: [Workspace]
    @Binding var selectedWorkspaceID: Workspace.ID?
    @Binding var selectedProjectID: Project.ID?
    let onSelectWorkspace: (Workspace) -> Void
    let onSelectProject: (Project) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("myJIRA")
                .font(.headingS)
                .padding(.horizontal, 14)
                .padding(.bottom, 14)

            List {
                ForEach(workspaces) { workspace in
                    Section {
                        ForEach(workspace.projects) { project in
                            Button {
                                selectedWorkspaceID = workspace.id
                                selectedProjectID = project.id
                                onSelectProject(project)
                            } label: {
                                ProjectSidebarRow(
                                    project: project,
                                    isSelected: selectedProjectID == project.id
                                )
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
                        }
                    } header: {
                        Text(workspace.name.uppercased())
                            .font(.labelXS)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .padding(.vertical, 18)
    }
}

private struct ProjectSidebarRow: View {
    let project: Project
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(project.key.prefix(1))
                .font(.labelSBold)
                .frame(width: 28, height: 28)
                .background(isSelected ? Color.foreground.opacity(0.16) : Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.labelM)
                    .lineLimit(1)
                Text(project.key)
                    .font(.paragraphS)
                    .foregroundStyle(isSelected ? Color.foreground.opacity(0.76) : .secondary)
            }

            Spacer(minLength: 0)
        }
        .foregroundStyle(isSelected ? Color.foreground : Color.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(isSelected ? JiraDesign.accent : JiraDesign.surface)
        .clipShape(RoundedRectangle(cornerRadius: JiraDesign.controlRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: JiraDesign.controlRadius, style: .continuous))
    }
}
