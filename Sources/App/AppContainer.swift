import Foundation

@Observable
final class AppContainer {
    let displayPreferencesRepository: DisplayPreferencesRepository
    let authService: AuthService
    let jiraConnectionService: JiraConnectionService
    let jiraSessionUseCase: JiraSessionUseCase
    let projectIssuesUseCase: ProjectIssuesUseCase
    let issueBoardUseCase: IssueBoardUseCase
    let issueHierarchyUseCase: IssueHierarchyUseCase
    let issueDetailUseCase: IssueDetailUseCase
    let issueCreationUseCase: IssueCreationUseCase
    let projectUsersManager: ProjectUsersManager
    let personalDataReportingService: PersonalDataReportingService

    init(
        displayPreferencesRepository: DisplayPreferencesRepository,
        authService: AuthService,
        jiraConnectionService: JiraConnectionService,
        jiraSessionUseCase: JiraSessionUseCase,
        projectIssuesUseCase: ProjectIssuesUseCase,
        issueBoardUseCase: IssueBoardUseCase,
        issueHierarchyUseCase: IssueHierarchyUseCase,
        issueDetailUseCase: IssueDetailUseCase,
        issueCreationUseCase: IssueCreationUseCase,
        projectUsersManager: ProjectUsersManager,
        personalDataReportingService: PersonalDataReportingService
    ) {
        self.displayPreferencesRepository = displayPreferencesRepository
        self.authService = authService
        self.jiraConnectionService = jiraConnectionService
        self.jiraSessionUseCase = jiraSessionUseCase
        self.projectIssuesUseCase = projectIssuesUseCase
        self.issueBoardUseCase = issueBoardUseCase
        self.issueHierarchyUseCase = issueHierarchyUseCase
        self.issueDetailUseCase = issueDetailUseCase
        self.issueCreationUseCase = issueCreationUseCase
        self.projectUsersManager = projectUsersManager
        self.personalDataReportingService = personalDataReportingService
    }

    static func live() -> AppContainer {
        do {
            let database = try AppDatabase.openDefault()
            let secretStore: SecretStore = LoggingSecretStore(
                wrapping: KeychainSecretStore(service: "dev.matteofauchon.myjira")
            )
            let authService: AuthService = LoggingAuthService(
                wrapping: AtlassianAuthService(secretStore: secretStore)
            )
            let jiraDataService: JiraDataService = LoggingJiraDataService(
                wrapping: JiraCloudDataService(authService: authService)
            )
            let workspaceRepository = LocalWorkspaceRepository(database: database)
            let issueRepository = LocalIssueRepository(database: database)
            let kanbanColumnOrderRepository = LocalKanbanColumnOrderRepository(database: database)
            let displayPreferencesRepository = LocalDisplayPreferencesRepository(database: database)
            let personalDataRepository = LocalPersonalDataRepository(database: database)
            let personalDataReportingService = AtlassianPersonalDataReportingService(
                authService: authService,
                repository: personalDataRepository
            )
            let jiraConnectionService: JiraConnectionService = LoggingJiraConnectionService(
                wrapping: DefaultJiraConnectionService(
                    authService: authService,
                    jiraDataService: jiraDataService,
                    workspaceRepository: workspaceRepository
                )
            )
            let syncService: SyncService = LoggingSyncService(
                wrapping: PollingSyncService(
                    workspaceRepository: workspaceRepository,
                    issueRepository: issueRepository,
                    kanbanColumnOrderRepository: kanbanColumnOrderRepository,
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
                displayPreferencesRepository: displayPreferencesRepository,
                authService: authService,
                jiraConnectionService: jiraConnectionService,
                jiraSessionUseCase: jiraSessionUseCase,
                projectIssuesUseCase: projectIssuesUseCase,
                issueBoardUseCase: issueBoardUseCase,
                issueHierarchyUseCase: issueHierarchyUseCase,
                issueDetailUseCase: issueDetailUseCase,
                issueCreationUseCase: issueCreationUseCase,
                projectUsersManager: projectUsersManager,
                personalDataReportingService: personalDataReportingService
            )
        } catch {
            fatalError("Unable to open local database: \(error)")
        }
    }
}
