import SwiftUI

struct MainWindowView: View {
    @AppStorage(IssueFetchPreferences.storageKey) private var issueFetchLimit = IssueFetchPreferences.defaultLimit
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
            Task { await viewModel.refreshCurrentProject() }
        }
        .alert("Unable to complete action", isPresented: errorPresentation) {
            Button("OK") {
                clearError()
            }
        } message: {
            Text(currentErrorMessage ?? "")
        }
    }

    private var appContent: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(
                workspaces: viewModel.workspaces,
                selectedWorkspaceID: $router.selectedWorkspaceID,
                selectedProjectID: $router.selectedProjectID,
                onSelectWorkspace: { workspace in
                    Task {
                        await viewModel.selectWorkspace(workspace, router: router)
                    }
                },
                onSelectProject: { project in
                    Task {
                        await viewModel.selectProject(project, router: router)
                    }
                }
            )
            .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 320)
        } detail: {
            if let projectViewModel = viewModel.currentProjectViewModel {
                projectContent(projectViewModel)
            } else {
                Text("Select a project")
                    .font(.headingS)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .windowBackgroundColor))
            }
        }
        .toolbar {
            if #available(macOS 26.0, *) {
                ToolbarItem(placement: .navigation) {
                    issueFetchLimitTitleMenu
                }
                .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .navigation) {
                    issueFetchLimitTitleMenu
                }
            }

            ToolbarItem(placement: .automatic) {
                Button {
                    isIssueInspectorPresented.toggle()
                } label: {
                    Image(systemName: "sidebar.right")
                }
                .help(isIssueInspectorPresented ? "Hide detail" : "Show detail")
            }
        }
        .navigationTitle("")
    }

    private var issueFetchLimitTitleMenu: some View {
        IssueFetchLimitTitleMenu(
            title: viewModel.currentProjectTitle,
            issueFetchLimit: issueFetchLimit,
            onSelectLimit: selectIssueFetchLimit
        )
    }

    private func projectContent(_ projectViewModel: ProjectViewModel) -> some View {
        BacklogView(
            projectID: projectViewModel.projectID,
            issues: projectViewModel.issues,
            kanbanColumnOrder: projectViewModel.kanbanColumnOrder,
            issueTypes: projectViewModel.issueTypes,
            creationMetadata: projectViewModel.creationMetadata,
            currentUser: projectViewModel.currentUser,
            assignableUsers: projectViewModel.assignableUsers,
            savedSprintOrder: projectViewModel.backlogSprintOrder,
            savedCollapsedGroupIDs: projectViewModel.collapsedBacklogGroupIDs,
            savedSelectedSprintFilter: projectViewModel.selectedSprintFilter,
            savedHiddenKanbanColumnTitles: projectViewModel.hiddenKanbanColumnTitles,
            selectedIssueID: $router.selectedIssueID,
            isLoadingInitialData: projectViewModel.isLoadingInitialData,
            isRefreshing: viewModel.isRefreshing || projectViewModel.isRefreshing,
            isLoadingIssueCreation: projectViewModel.isLoadingIssueCreation,
            isCreatingIssue: projectViewModel.isCreatingIssue,
            onRefresh: {
                Task { await viewModel.refreshCurrentProject() }
            },
            onMoveIssue: { issueID, status, beforeIssueID in
                Task {
                    await projectViewModel.moveIssue(
                        id: issueID,
                        toStatus: status,
                        beforeIssueID: beforeIssueID
                    )
                }
            },
            onMoveIssueToSprint: { issueID, sprintName in
                Task {
                    await projectViewModel.updateSprint(issueID: issueID, sprintName: sprintName)
                }
            },
            onUpdateStoryPoints: { issueID, storyPoints in
                Task {
                    await projectViewModel.updateStoryPoints(issueID: issueID, storyPoints: storyPoints)
                }
            },
            onMoveColumn: { title, beforeTitle in
                Task {
                    await projectViewModel.moveKanbanColumn(title, before: beforeTitle)
                }
            },
            onAssignIssueToCurrentUser: { issueID in
                Task {
                    await projectViewModel.assignIssueToCurrentUser(issueID: issueID)
                }
            },
            onUnassignIssue: { issueID in
                Task {
                    await projectViewModel.unassignIssue(issueID: issueID)
                }
            },
            onAssignIssue: { issueID, user in
                Task {
                    await projectViewModel.assignIssue(issueID: issueID, to: user)
                }
            },
            onDeleteIssue: { issueID in
                Task {
                    let deletedIDs = await projectViewModel.deleteIssue(issueID: issueID)
                    if deletedIDs.contains(router.selectedIssueID ?? "") {
                        router.selectedIssueID = nil
                    }
                }
            },
            onLoadIssueCreationOptions: {
                Task {
                    await projectViewModel.loadIssueCreationOptions()
                }
            },
            onLoadCreationMetadata: { issueTypeID in
                Task {
                    await projectViewModel.loadCreationMetadata(issueTypeID: issueTypeID)
                }
            },
            onSaveDisplayPreferences: { sprintOrder, collapsedGroupIDs, selectedSprintFilter in
                projectViewModel.saveBacklogDisplayPreferences(
                    sprintOrder: sprintOrder,
                    collapsedGroupIDs: collapsedGroupIDs,
                    selectedSprintFilter: selectedSprintFilter
                )
            },
            onSaveHiddenKanbanColumns: projectViewModel.saveHiddenKanbanColumnTitles,
            onCreateIssue: { draft in
                if let issue = await projectViewModel.createIssue(draft: draft) {
                    router.selectedIssueID = issue.id
                    return true
                }

                return false
            }
        )
        .environment(\.jiraBaseURL, jiraBaseURL(for: projectViewModel.projectID))
        .inspector(isPresented: $isIssueInspectorPresented) {
            issueDetailInspector(projectViewModel)
                .inspectorColumnWidth(min: 280, ideal: 400, max: 640)
        }
    }

    private func issueDetailInspector(_ projectViewModel: ProjectViewModel) -> some View {
        let selectedIssue = projectViewModel.issue(id: router.selectedIssueID)

        return IssueDetailView(
            issue: selectedIssue,
            parentIssue: projectViewModel.parent(for: selectedIssue),
            subtasks: projectViewModel.subtasks(for: selectedIssue),
            statusOptions: orderedStatusOptions(projectViewModel),
            subtaskIssueTypes: projectViewModel.subtaskIssueTypes,
            assignableUsers: projectViewModel.assignableUsers,
            commentAuthorName: projectViewModel.currentUser?.displayName,
            currentUser: projectViewModel.currentUser,
            isLoadingChangelog: projectViewModel.isLoadingChangelog(for: selectedIssue?.id),
            isAddingComment: projectViewModel.isAddingComment(to: selectedIssue?.id),
            isCreatingIssue: projectViewModel.isCreatingIssue,
            onChangeStatus: { issueID, status in
                Task {
                    await projectViewModel.moveIssue(id: issueID, toStatus: status, beforeIssueID: nil)
                }
            },
            onUpdateStoryPoints: { issueID, storyPoints in
                Task {
                    await projectViewModel.updateStoryPoints(issueID: issueID, storyPoints: storyPoints)
                }
            },
            onUpdateSummary: { issueID, summary in
                await projectViewModel.updateSummary(issueID: issueID, summary: summary)
            },
            onUpdateDescription: { issueID, descriptionText in
                await projectViewModel.updateDescription(issueID: issueID, descriptionText: descriptionText)
            },
            onAddComment: { issueID, bodyText, parentComment in
                await projectViewModel.addComment(issueID: issueID, bodyText: bodyText, replyTo: parentComment)
            },
            onLoadSubtaskCreationOptions: {
                Task {
                    await projectViewModel.loadSubtaskCreationOptionsIfNeeded()
                }
            },
            onCreateSubtask: { issueID, draft in
                if let subtask = await projectViewModel.createSubtask(parentIssueID: issueID, draft: draft) {
                    router.selectedIssueID = subtask.id
                    return true
                }

                return false
            },
            onDeleteComment: { issueID, commentID in
                Task {
                    await projectViewModel.deleteComment(issueID: issueID, commentID: commentID)
                }
            },
            onDeleteIssue: { issueID in
                Task {
                    let deletedIDs = await projectViewModel.deleteIssue(issueID: issueID)
                    if deletedIDs.contains(router.selectedIssueID ?? "") {
                        router.selectedIssueID = nil
                    }
                }
            },
            onAssignIssueToCurrentUser: { issueID in
                Task {
                    await projectViewModel.assignIssueToCurrentUser(issueID: issueID)
                }
            },
            onUnassignIssue: { issueID in
                Task {
                    await projectViewModel.unassignIssue(issueID: issueID)
                }
            },
            onAssignIssue: { issueID, user in
                Task {
                    await projectViewModel.assignIssue(issueID: issueID, to: user)
                }
            },
            onSelectIssue: { issueID in
                router.selectedIssueID = issueID
            },
            onDetailsPageVisible: { issueID in
                Task {
                    await projectViewModel.loadChangelogIfNeeded(issueID: issueID)
                }
            }
        )
        .environment(\.jiraBaseURL, jiraBaseURL(for: projectViewModel.projectID))
    }

    private func jiraBaseURL(for projectID: Project.ID) -> URL? {
        viewModel.workspaces.first { workspace in
            workspace.projects.contains { $0.id == projectID }
        }?.baseURL
    }

    private func orderedStatusOptions(_ projectViewModel: ProjectViewModel) -> [String] {
        let statusOptions = (projectViewModel.kanbanColumnOrder + projectViewModel.issues.map(\.status))
            .reduce(into: [String]()) { result, status in
                guard !result.contains(status) else { return }
                result.append(status)
            }
        let knownStatuses = projectViewModel.kanbanColumnOrder.filter { statusOptions.contains($0) }
        let newStatuses = statusOptions.filter { !knownStatuses.contains($0) }
        return knownStatuses + newStatuses
    }

    private var currentErrorMessage: String? {
        viewModel.errorMessage ?? viewModel.currentProjectViewModel?.errorMessage
    }

    private var errorPresentation: Binding<Bool> {
        Binding(
            get: { currentErrorMessage != nil },
            set: { isPresented in
                if isPresented == false {
                    clearError()
                }
            }
        )
    }

    private func clearError() {
        viewModel.clearGlobalError()
        viewModel.currentProjectViewModel?.errorMessage = nil
    }

    private func selectIssueFetchLimit(_ limit: Int) {
        guard limit != issueFetchLimit else { return }
        issueFetchLimit = limit
        NotificationCenter.default.post(name: .refreshRequested, object: nil)
    }
}
