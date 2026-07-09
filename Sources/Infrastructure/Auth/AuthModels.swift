import Foundation

struct JiraOAuthConfiguration: Sendable {
    var clientID: String
    var clientSecret: String
    var redirectURI: URL
    var scopes: [String]
}

struct JiraTokenSet: Codable, Sendable {
    var accessToken: String
    var refreshToken: String?
    var expiresAt: Date
    var scope: String?
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
        }
    }
}
