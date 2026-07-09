import Foundation

final class JiraCloudDataService: JiraDataService, @unchecked Sendable {
    private let authService: AuthService
    private let urlSession: URLSession

    init(authService: AuthService, urlSession: URLSession = .shared) {
        self.authService = authService
        self.urlSession = urlSession
    }

    func projects(for resource: JiraAccessibleResource) async throws -> [Project] {
        guard let token = try authService.currentToken() else {
            throw AuthError.invalidConfiguration
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.atlassian.com"
        components.path = "/ex/jira/\(resource.id)/rest/api/3/project/search"
        components.queryItems = [
            URLQueryItem(name: "maxResults", value: "100")
        ]

        guard let url = components.url else {
            throw AuthError.invalidConfiguration
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidServerResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unable to load Jira projects."
            throw AuthError.failedTokenExchange(message)
        }

        let page = try JSONDecoder().decode(ProjectSearchResponse.self, from: data)
        return page.values.map {
            Project(id: "\(resource.id):\($0.id)", key: $0.key, name: $0.name, workspaceID: resource.id)
        }
    }

    func issues(for project: Project) async throws -> [Issue] {
        guard let token = try authService.currentToken() else {
            throw AuthError.invalidConfiguration
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.atlassian.com"
        components.path = "/ex/jira/\(project.workspaceID)/rest/api/3/search/jql"
        var fieldNames = ["summary", "status", "assignee", "updated"]
        if let sprintFieldID = try await sprintFieldID(accessToken: token.accessToken, cloudID: project.workspaceID) {
            fieldNames.append(sprintFieldID)
        }

        components.queryItems = [
            URLQueryItem(name: "jql", value: "project = \(project.key) ORDER BY updated DESC"),
            URLQueryItem(name: "maxResults", value: "100"),
            URLQueryItem(name: "fields", value: fieldNames.joined(separator: ","))
        ]

        guard let url = components.url else {
            throw AuthError.invalidConfiguration
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidServerResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unable to load Jira issues."
            throw AuthError.failedTokenExchange(message)
        }

        do {
            let page = try jiraDecoder.decode(IssueSearchResponse.self, from: data)
            return page.issues.map {
                Issue(
                    id: "\(project.workspaceID):\($0.id)",
                    key: $0.key,
                    projectID: project.id,
                    summary: $0.fields.summary,
                    status: $0.fields.status.name,
                    sprintName: $0.fields.sprintName,
                    sprintState: $0.fields.sprintState,
                    assigneeName: $0.fields.assignee?.displayName,
                    updatedAt: $0.fields.updated
                )
            }
        } catch {
            let payload = String(data: data, encoding: .utf8) ?? "<non-utf8 response>"
            throw AuthError.failedTokenExchange("Unable to decode Jira issues: \(payload)")
        }
    }

    private func sprintFieldID(accessToken: String, cloudID: String) async throws -> String? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.atlassian.com"
        components.path = "/ex/jira/\(cloudID)/rest/api/3/field"

        guard let url = components.url else {
            throw AuthError.invalidConfiguration
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidServerResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            return nil
        }

        let fields = try JSONDecoder().decode([JiraFieldDTO].self, from: data)
        return fields.first {
            $0.name.localizedCaseInsensitiveCompare("Sprint") == .orderedSame
                || $0.schema?.custom == "com.pyxis.greenhopper.jira:gh-sprint"
        }?.id
    }

    private var jiraDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withTimeZone]

            if let date = dateFormatter.date(from: value) {
                return date
            }

            let fractionalDateFormatter = ISO8601DateFormatter()
            fractionalDateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withTimeZone]

            if let date = fractionalDateFormatter.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid Jira date: \(value)")
        }
        return decoder
    }
}

private struct ProjectSearchResponse: Decodable {
    var values: [ProjectDTO]
}

private struct ProjectDTO: Decodable {
    var id: String
    var key: String
    var name: String
}

private struct IssueSearchResponse: Decodable {
    var issues: [IssueDTO]
}

private struct IssueDTO: Decodable {
    var id: String
    var key: String
    var fields: IssueFieldsDTO
}

private struct IssueFieldsDTO: Decodable {
    var summary: String
    var status: IssueStatusDTO
    var sprintName: String?
    var sprintState: String?
    var assignee: IssueUserDTO?
    var updated: Date

    private enum CodingKeys: String, CodingKey {
        case summary
        case status
        case assignee
        case updated
    }

    init(from decoder: Decoder) throws {
        let knownValues = try decoder.container(keyedBy: CodingKeys.self)
        summary = try knownValues.decode(String.self, forKey: .summary)
        status = try knownValues.decode(IssueStatusDTO.self, forKey: .status)
        assignee = try knownValues.decodeIfPresent(IssueUserDTO.self, forKey: .assignee)
        updated = try knownValues.decode(Date.self, forKey: .updated)

        let customValues = try decoder.container(keyedBy: DynamicCodingKey.self)
        let sprintInfo = customValues.allKeys
            .lazy
            .filter { $0.stringValue.hasPrefix("customfield_") }
            .compactMap { key -> IssueSprintInfo? in
                if let sprints = try? customValues.decodeIfPresent([IssueSprintDTO].self, forKey: key) {
                    guard let sprint = sprints.last else { return nil }
                    return IssueSprintInfo(name: sprint.name, state: sprint.state)
                }

                if let sprint = try? customValues.decodeIfPresent(IssueSprintDTO.self, forKey: key) {
                    return IssueSprintInfo(name: sprint.name, state: sprint.state)
                }

                return nil
            }
            .first

        sprintName = sprintInfo?.name
        sprintState = sprintInfo?.state
    }
}

private struct IssueStatusDTO: Decodable {
    var name: String
}

private struct IssueUserDTO: Decodable {
    var displayName: String
}

private struct IssueSprintDTO: Decodable {
    var name: String
    var state: String?
}

private struct IssueSprintInfo {
    var name: String
    var state: String?
}

private struct JiraFieldDTO: Decodable {
    var id: String
    var name: String
    var schema: JiraFieldSchemaDTO?
}

private struct JiraFieldSchemaDTO: Decodable {
    var custom: String?
}

private struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        stringValue = "\(intValue)"
        self.intValue = intValue
    }
}
