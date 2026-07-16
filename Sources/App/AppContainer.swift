import Foundation

@Observable
final class AppContainer {
    let database: AppDatabase
    let workspaceRepository: WorkspaceRepository
    let issueRepository: IssueRepository
    let kanbanColumnOrderRepository: KanbanColumnOrderRepository
    let displayPreferencesRepository: DisplayPreferencesRepository
    let syncService: SyncService
    let authService: AuthService
    let secretStore: SecretStore
    let jiraDataService: JiraDataService
    let jiraConnectionService: JiraConnectionService
    let jiraSessionUseCase: JiraSessionUseCase
    let projectIssuesUseCase: ProjectIssuesUseCase
    let issueBoardUseCase: IssueBoardUseCase
    let issueHierarchyUseCase: IssueHierarchyUseCase
    let issueDetailUseCase: IssueDetailUseCase
    let issueCreationUseCase: IssueCreationUseCase
    let projectUsersManager: ProjectUsersManager

    init(
        database: AppDatabase,
        workspaceRepository: WorkspaceRepository,
        issueRepository: IssueRepository,
        kanbanColumnOrderRepository: KanbanColumnOrderRepository,
        displayPreferencesRepository: DisplayPreferencesRepository,
        syncService: SyncService,
        authService: AuthService,
        secretStore: SecretStore,
        jiraDataService: JiraDataService,
        jiraConnectionService: JiraConnectionService,
        jiraSessionUseCase: JiraSessionUseCase,
        projectIssuesUseCase: ProjectIssuesUseCase,
        issueBoardUseCase: IssueBoardUseCase,
        issueHierarchyUseCase: IssueHierarchyUseCase,
        issueDetailUseCase: IssueDetailUseCase,
        issueCreationUseCase: IssueCreationUseCase,
        projectUsersManager: ProjectUsersManager
    ) {
        self.database = database
        self.workspaceRepository = workspaceRepository
        self.issueRepository = issueRepository
        self.kanbanColumnOrderRepository = kanbanColumnOrderRepository
        self.displayPreferencesRepository = displayPreferencesRepository
        self.syncService = syncService
        self.authService = authService
        self.secretStore = secretStore
        self.jiraDataService = jiraDataService
        self.jiraConnectionService = jiraConnectionService
        self.jiraSessionUseCase = jiraSessionUseCase
        self.projectIssuesUseCase = projectIssuesUseCase
        self.issueBoardUseCase = issueBoardUseCase
        self.issueHierarchyUseCase = issueHierarchyUseCase
        self.issueDetailUseCase = issueDetailUseCase
        self.issueCreationUseCase = issueCreationUseCase
        self.projectUsersManager = projectUsersManager
    }

    static func live() -> AppContainer {
        do {
            let database = try AppDatabase.openDefault()
            let seed = SeedDataProvider()
            let secretStore: SecretStore = LoggingSecretStore(
                wrapping: KeychainSecretStore(service: "dev.matteofauchon.myjira")
            )
            let authService: AuthService = LoggingAuthService(
                wrapping: AtlassianAuthService(secretStore: secretStore)
            )
            let jiraDataService: JiraDataService = LoggingJiraDataService(
                wrapping: JiraCloudDataService(authService: authService)
            )
            let workspaceRepository = LocalWorkspaceRepository(database: database, seedDataProvider: seed)
            let issueRepository = LocalIssueRepository(database: database, seedDataProvider: seed)
            let kanbanColumnOrderRepository = LocalKanbanColumnOrderRepository(database: database)
            let displayPreferencesRepository = LocalDisplayPreferencesRepository(database: database)
            let jiraConnectionService: JiraConnectionService = LoggingJiraConnectionService(
                wrapping: DefaultJiraConnectionService(
                    authService: authService,
                    jiraDataService: jiraDataService,
                    workspaceRepository: workspaceRepository,
                    secretStore: secretStore
                )
            )
            let syncService: SyncService = LoggingSyncService(
                wrapping: PollingSyncService(
                    workspaceRepository: workspaceRepository,
                    issueRepository: issueRepository,
                    jiraDataService: jiraDataService
                )
            )
            let jiraSessionUseCase = JiraSessionUseCase(
                workspaceRepository: workspaceRepository,
                jiraConnectionService: jiraConnectionService
            )
            let projectIssuesUseCase = ProjectIssuesUseCase(
                issueRepository: issueRepository,
                kanbanColumnOrderRepository: kanbanColumnOrderRepository,
                syncService: syncService
            )
            let issueBoardUseCase = IssueBoardUseCase(
                issueRepository: issueRepository,
                kanbanColumnOrderRepository: kanbanColumnOrderRepository,
                jiraDataService: jiraDataService
            )
            let issueHierarchyUseCase = IssueHierarchyUseCase()
            let issueDetailUseCase = IssueDetailUseCase(
                issueRepository: issueRepository,
                jiraDataService: jiraDataService
            )
            let issueCreationUseCase = IssueCreationUseCase(
                workspaceRepository: workspaceRepository,
                issueRepository: issueRepository,
                jiraDataService: jiraDataService
            )
            let projectUsersManager = ProjectUsersManager(
                workspaceRepository: workspaceRepository,
                jiraDataService: jiraDataService
            )

            return AppContainer(
                database: database,
                workspaceRepository: workspaceRepository,
                issueRepository: issueRepository,
                kanbanColumnOrderRepository: kanbanColumnOrderRepository,
                displayPreferencesRepository: displayPreferencesRepository,
                syncService: syncService,
                authService: authService,
                secretStore: secretStore,
                jiraDataService: jiraDataService,
                jiraConnectionService: jiraConnectionService,
                jiraSessionUseCase: jiraSessionUseCase,
                projectIssuesUseCase: projectIssuesUseCase,
                issueBoardUseCase: issueBoardUseCase,
                issueHierarchyUseCase: issueHierarchyUseCase,
                issueDetailUseCase: issueDetailUseCase,
                issueCreationUseCase: issueCreationUseCase,
                projectUsersManager: projectUsersManager
            )
        } catch {
            fatalError("Unable to open local database: \(error)")
        }
    }
}
