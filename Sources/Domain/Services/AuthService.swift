import Foundation

protocol AuthService: Sendable {
    func connect(configuration: JiraOAuthConfiguration) async throws -> [JiraAccessibleResource]
    func currentToken() throws -> JiraTokenSet?
    func disconnect() throws
}

protocol SecretStore: Sendable {
    func save(_ data: Data, account: String) throws
    func read(account: String) throws -> Data?
    func delete(account: String) throws
}
