import Foundation

final class AtlassianAuthService: AuthService, @unchecked Sendable {
    private let secretStore: SecretStore
    private let urlSession: URLSession
    private let tokenAccount = "jira.oauth.tokens"

    init(secretStore: SecretStore, urlSession: URLSession = .shared) {
        self.secretStore = secretStore
        self.urlSession = urlSession
    }

    func connect(configuration: JiraOAuthConfiguration) async throws -> [JiraAccessibleResource] {
        guard
            !configuration.clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !configuration.clientSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            let callbackScheme = configuration.redirectURI.scheme
        else {
            throw AuthError.invalidConfiguration
        }

        let state = UUID().uuidString
        let authorizeURL = try authorizeURL(configuration: configuration, state: state)
        let callbackURL = try await OAuthWebSession().start(url: authorizeURL, callbackScheme: callbackScheme)
        let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)

        guard components?.queryItems?.first(where: { $0.name == "state" })?.value == state else {
            throw AuthError.invalidState
        }

        if let error = components?.queryItems?.first(where: { $0.name == "error" })?.value {
            let description = components?.queryItems?.first(where: { $0.name == "error_description" })?.value
            throw AuthError.authorizationDenied(description ?? error)
        }

        guard let code = components?.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw AuthError.missingAuthorizationCode
        }

        let tokenSet = try await exchangeCode(code, configuration: configuration)
        try saveToken(tokenSet)
        return try await accessibleResources(accessToken: tokenSet.accessToken)
    }

    func currentToken() throws -> JiraTokenSet? {
        guard let data = try secretStore.read(account: tokenAccount) else {
            return nil
        }

        return try JSONDecoder().decode(JiraTokenSet.self, from: data)
    }

    func disconnect() throws {
        try secretStore.delete(account: tokenAccount)
    }

    private func saveToken(_ tokenSet: JiraTokenSet) throws {
        let data = try JSONEncoder().encode(tokenSet)
        try secretStore.save(data, account: tokenAccount)
    }

    private func authorizeURL(configuration: JiraOAuthConfiguration, state: String) throws -> URL {
        var components = URLComponents(string: "https://auth.atlassian.com/authorize")
        components?.queryItems = [
            URLQueryItem(name: "audience", value: "api.atlassian.com"),
            URLQueryItem(name: "client_id", value: configuration.clientID),
            URLQueryItem(name: "scope", value: configuration.scopes.joined(separator: " ")),
            URLQueryItem(name: "redirect_uri", value: configuration.redirectURI.absoluteString),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "prompt", value: "consent")
        ]

        guard let url = components?.url else {
            throw AuthError.invalidConfiguration
        }

        return url
    }

    private func exchangeCode(_ code: String, configuration: JiraOAuthConfiguration) async throws -> JiraTokenSet {
        var request = URLRequest(url: URL(string: "https://auth.atlassian.com/oauth/token")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(TokenRequest(
            grantType: "authorization_code",
            clientID: configuration.clientID,
            clientSecret: configuration.clientSecret,
            code: code,
            redirectURI: configuration.redirectURI.absoluteString
        ))

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidServerResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Atlassian token exchange failed."
            throw AuthError.failedTokenExchange(message)
        }

        let tokenResponse: TokenResponse
        do {
            tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        } catch {
            let payload = String(data: data, encoding: .utf8) ?? "<non-utf8 response>"
            throw AuthError.failedTokenExchange("Unable to decode Atlassian token response: \(payload)")
        }
        return JiraTokenSet(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn)),
            scope: tokenResponse.scope
        )
    }

    private func accessibleResources(accessToken: String) async throws -> [JiraAccessibleResource] {
        var request = URLRequest(url: URL(string: "https://api.atlassian.com/oauth/token/accessible-resources")!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidServerResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unable to load Atlassian resources."
            throw AuthError.failedTokenExchange(message)
        }

        do {
            return try JSONDecoder().decode([JiraAccessibleResource].self, from: data)
        } catch {
            let payload = String(data: data, encoding: .utf8) ?? "<non-utf8 response>"
            throw AuthError.failedTokenExchange("Unable to decode Atlassian resources: \(payload)")
        }
    }
}

private struct TokenRequest: Encodable {
    var grantType: String
    var clientID: String
    var clientSecret: String
    var code: String
    var redirectURI: String

    enum CodingKeys: String, CodingKey {
        case grantType = "grant_type"
        case clientID = "client_id"
        case clientSecret = "client_secret"
        case code
        case redirectURI = "redirect_uri"
    }
}

private struct TokenResponse: Decodable {
    var accessToken: String
    var refreshToken: String?
    var expiresIn: Int
    var scope: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case scope
    }
}
