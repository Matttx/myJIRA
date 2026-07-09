import SwiftUI

struct MainWindowView: View {
    @State var viewModel: MainWindowViewModel
    @Bindable var router: AppRouter

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
        NavigationSplitView {
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
        } content: {
            BacklogView(
                issues: viewModel.issues,
                selectedIssueID: $router.selectedIssueID,
                isRefreshing: viewModel.isRefreshing,
                onRefresh: {
                    Task { await viewModel.refresh(router: router) }
                }
            )
        } detail: {
            IssueDetailView(issue: viewModel.issue(id: router.selectedIssueID))
        }
    }
}
