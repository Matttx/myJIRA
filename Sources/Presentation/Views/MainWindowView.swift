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
        .endEditingOnOutsideClick()
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
                kanbanColumnOrder: viewModel.kanbanColumnOrder,
                issueTypes: viewModel.issueTypes,
                creationMetadata: viewModel.creationMetadata,
                currentUser: viewModel.currentUser,
                selectedIssueID: $router.selectedIssueID,
                isRefreshing: viewModel.isRefreshing,
                isLoadingIssueCreation: viewModel.isLoadingIssueCreation,
                isCreatingIssue: viewModel.isCreatingIssue,
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
                },
                onUpdateStoryPoints: { issueID, storyPoints in
                    Task {
                        await viewModel.updateStoryPoints(issueID: issueID, storyPoints: storyPoints)
                    }
                },
                onMoveColumn: { title, beforeTitle in
                    Task {
                        await viewModel.moveKanbanColumn(
                            title,
                            before: beforeTitle,
                            projectID: router.selectedProjectID
                        )
                    }
                },
                onAssignIssueToCurrentUser: { issueID in
                    Task {
                        await viewModel.assignIssueToCurrentUser(issueID: issueID)
                    }
                },
                onLoadIssueCreationOptions: {
                    Task {
                        await viewModel.loadIssueCreationOptions(projectID: router.selectedProjectID)
                    }
                },
                onLoadCreationMetadata: { issueTypeID in
                    Task {
                        await viewModel.loadCreationMetadata(
                            projectID: router.selectedProjectID,
                            issueTypeID: issueTypeID
                        )
                    }
                },
                onCreateIssue: { draft in
                    await viewModel.createIssue(
                        projectID: router.selectedProjectID,
                        draft: draft,
                        router: router
                    ) != nil
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
            statusOptions: orderedStatusOptions,
            isLoadingChangelog: viewModel.isLoadingChangelog(for: selectedIssue?.id),
            onChangeStatus: { issueID, status in
                Task {
                    await viewModel.moveIssue(id: issueID, toStatus: status, beforeIssueID: nil)
                }
            },
            onSelectIssue: { issueID in
                router.selectedIssueID = issueID
            },
            onDetailsPageVisible: { issueID in
                Task {
                    await viewModel.loadChangelogIfNeeded(issueID: issueID)
                }
            }
        )
    }

    private var orderedStatusOptions: [String] {
        let statusOptions = Array(Set(viewModel.issues.map(\.status))).sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
        let knownStatuses = viewModel.kanbanColumnOrder.filter { statusOptions.contains($0) }
        let newStatuses = statusOptions.filter { !knownStatuses.contains($0) }
        return knownStatuses + newStatuses
    }
}
