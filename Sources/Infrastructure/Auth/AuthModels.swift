import Foundation

struct JiraOAuthConfiguration: Sendable {
    var clientID: String
    var clientSecret: String
    var redirectURI: URL
    var scopes: [String]
}

extension JiraOAuthConfiguration {
    static let bundled: JiraOAuthConfiguration? = {
        guard
            let clientID = bundledValue(forInfoKey: "AtlassianOAuthClientID"),
            let clientSecret = bundledValue(forInfoKey: "AtlassianOAuthClientSecret"),
            let redirectURI = URL(string: "myjira://oauth/callback")
        else {
            return nil
        }

        return JiraOAuthConfiguration(
            clientID: clientID,
            clientSecret: clientSecret,
            redirectURI: redirectURI,
            scopes: JiraOAuthScopes.defaultScopes
        )
    }()

    private static func bundledValue(forInfoKey key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty, !trimmedValue.contains("$(") else {
            return nil
        }

        return trimmedValue
    }
}

enum JiraOAuthScopes {
    static let defaultScopes = [
        "read:jira-user",
        "read:jira-work",
        "read:user:jira",
        "read:project:jira",
        "read:application-role:jira",
        "read:avatar:jira",
        "read:group:jira",
        "write:jira-work",
        "write:issue:jira",
        "read:comment:jira",
        "read:comment.property:jira",
        "write:comment.property:jira",
        "delete:issue:jira",
        "delete:comment:jira",
        "delete:comment.property:jira",
        "offline_access"
    ]
}

struct JiraTokenSet: Codable, Sendable {
    var accessToken: String
    var refreshToken: String?
    var expiresAt: Date
    var scope: String?

    func grants(anyOf requiredScopes: Set<String>) -> Bool {
        guard let scope else { return true }
        let grantedScopes = Set(scope.split(whereSeparator: \.isWhitespace).map(String.init))
        return !grantedScopes.isDisjoint(with: requiredScopes)
    }
}

struct JiraAccessibleResource: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var url: URL
    var scopes: [String]
    var avatarURL: URL?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case url
        case scopes
        case avatarURL = "avatarUrl"
    }
}

enum AuthError: LocalizedError {
    case invalidConfiguration
    case missingAuthorizationCode
    case invalidState
    case failedTokenExchange(String)
    case invalidServerResponse
    case authorizationDenied(String)
    case missingRequiredScope

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            "OAuth configuration is incomplete."
        case .missingAuthorizationCode:
            "Atlassian did not return an authorization code."
        case .invalidState:
            "The OAuth state returned by Atlassian did not match the app state."
        case .failedTokenExchange(let message):
            message
        case .invalidServerResponse:
            "Atlassian returned an unexpected response."
        case .authorizationDenied(let message):
            message
        case .missingRequiredScope:
            "Your Jira connection does not allow issue creation. Reconnect your Atlassian account in Settings to grant the required permissions."
        }
    }
}
