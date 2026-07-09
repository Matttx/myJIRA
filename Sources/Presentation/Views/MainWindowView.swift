import SwiftUI

struct MainWindowView: View {
    @State var viewModel: MainWindowViewModel
    @Bindable var router: AppRouter
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var isIssueInspectorPresented = true

    var body: some View {
        Group {
            if viewModel.isConnected {
                appContent
            } else {
                ConnectJiraView(isConnecting: viewModel.isRefreshing) { configuration in
                    Task {
                        await viewModel.connect(configuration: configuration, router: router)
                    }
                }
            }
        }
        .task {
            await viewModel.loadInitialSelection(router: router)
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshRequested)) { _ in
            Task { await viewModel.refresh(router: router) }
        }
        .alert("Unable to refresh", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var appContent: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(
                workspaces: viewModel.workspaces,
                selectedWorkspaceID: $router.selectedWorkspaceID,
                selectedProjectID: $router.selectedProjectID,
                onSelectWorkspace: { workspace in
                    router.select(workspace: workspace)
                    Task { await viewModel.refresh(router: router) }
                },
                onSelectProject: { project in
                    router.select(project: project)
                    Task { await viewModel.refresh(router: router) }
                }
            )
        } detail: {
            BacklogView(
                issues: viewModel.issues,
                selectedIssueID: $router.selectedIssueID,
                isRefreshing: viewModel.isRefreshing,
                onRefresh: {
                    Task { await viewModel.refresh(router: router) }
                },
                onMoveIssue: { issueID, status, beforeIssueID in
                    Task {
                        await viewModel.moveIssue(
                            id: issueID,
                            toStatus: status,
                            beforeIssueID: beforeIssueID
                        )
                    }
                }
            )
            .inspector(isPresented: $isIssueInspectorPresented) {
                issueDetailInspector
                    .inspectorColumnWidth(min: 340, ideal: 440, max: 760)
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    isIssueInspectorPresented.toggle()
                } label: {
                    Image(systemName: "sidebar.right")
                }
                .help(isIssueInspectorPresented ? "Hide detail" : "Show detail")
            }
        }
    }

    private var issueDetailInspector: some View {
        let selectedIssue = viewModel.issue(id: router.selectedIssueID)

        return IssueDetailView(
            issue: selectedIssue,
            parentIssue: viewModel.parent(for: selectedIssue),
            subtasks: viewModel.subtasks(for: selectedIssue),
            onSelectIssue: { issueID in
                router.selectedIssueID = issueID
            }
        )
    }
}
