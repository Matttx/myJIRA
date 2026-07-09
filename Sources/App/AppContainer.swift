import Foundation

@Observable
final class AppContainer {
    let database: AppDatabase
    let workspaceRepository: WorkspaceRepository
    let issueRepository: IssueRepository
    let syncService: SyncService
    let authService: AuthService
    let secretStore: SecretStore
    let jiraDataService: JiraDataService
    let jiraConnectionService: JiraConnectionService

    init(
        database: AppDatabase,
        workspaceRepository: WorkspaceRepository,
        issueRepository: IssueRepository,
        syncService: SyncService,
        authService: AuthService,
        secretStore: SecretStore,
        jiraDataService: JiraDataService,
        jiraConnectionService: JiraConnectionService
    ) {
        self.database = database
        self.workspaceRepository = workspaceRepository
        self.issueRepository = issueRepository
        self.syncService = syncService
        self.authService = authService
        self.secretStore = secretStore
        self.jiraDataService = jiraDataService
        self.jiraConnectionService = jiraConnectionService
    }

    static func live() -> AppContainer {
        do {
            let database = try AppDatabase.openDefault()
            let seed = SeedDataProvider()
            let secretStore = KeychainSecretStore(service: "dev.matteofauchon.myjira")
            let authService = AtlassianAuthService(secretStore: secretStore)
            let jiraDataService = JiraCloudDataService(authService: authService)
            let workspaceRepository = LocalWorkspaceRepository(database: database, seedDataProvider: seed)
            let issueRepository = LocalIssueRepository(database: database, seedDataProvider: seed)
            let jiraConnectionService = DefaultJiraConnectionService(
                authService: authService,
                jiraDataService: jiraDataService,
                workspaceRepository: workspaceRepository,
                secretStore: secretStore
            )
            let syncService = PollingSyncService(
                workspaceRepository: workspaceRepository,
                issueRepository: issueRepository,
                jiraDataService: jiraDataService
            )

            return AppContainer(
                database: database,
                workspaceRepository: workspaceRepository,
                issueRepository: issueRepository,
                syncService: syncService,
                authService: authService,
                secretStore: secretStore,
                jiraDataService: jiraDataService,
                jiraConnectionService: jiraConnectionService
            )
        } catch {
            fatalError("Unable to open local database: \(error)")
        }
    }
}
