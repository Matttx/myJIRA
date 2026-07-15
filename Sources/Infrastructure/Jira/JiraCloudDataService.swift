import Foundation

final class JiraCloudDataService: JiraDataService, @unchecked Sendable {
    private let issueFetchLimit = 200
    private let changelogFetchLimit = 50
    private let replyParentPropertyKey = "myjira.parentCommentId"
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

        var fieldNames = [
            "summary",
            "description",
            "comment",
            "status",
            "assignee",
            "reporter",
            "priority",
            "labels",
            "created",
            "updated",
            "parent",
            "subtasks",
            "issuetype"
        ]
        if let sprintFieldID = try await sprintFieldID(accessToken: token.accessToken, cloudID: project.workspaceID) {
            fieldNames.append(sprintFieldID)
        }
        let storyPointsFieldIDs = try await storyPointsFieldIDs(
            projectKey: project.key,
            accessToken: token.accessToken,
            cloudID: project.workspaceID
        )
        fieldNames.append(contentsOf: storyPointsFieldIDs)

        let issueDTOs = try await searchIssues(
            project: project,
            fieldNames: fieldNames,
            accessToken: token.accessToken,
            storyPointsFieldIDs: storyPointsFieldIDs
        )

        var issues = issueDTOs.map { issue in
            Issue(
                id: "\(project.workspaceID):\(issue.id)",
                key: issue.key,
                projectID: project.id,
                summary: issue.fields.summary,
                status: issue.fields.status.name,
                statusCategoryKey: issue.fields.status.statusCategory?.key,
                descriptionText: issue.fields.descriptionText,
                comments: issue.fields.comments,
                issueTypeName: issue.fields.issueType?.name,
                priorityName: issue.fields.priority?.name,
                reporterName: issue.fields.reporter?.displayName,
                labels: issue.fields.labels,
                storyPointsFieldID: issue.fields.storyPointsFieldID ?? storyPointsFieldIDs.first,
                storyPoints: issue.fields.storyPoints,
                sprintID: issue.fields.sprintID,
                sprintName: issue.fields.sprintName,
                sprintState: issue.fields.sprintState,
                parentID: issue.fields.parent.map { "\(project.workspaceID):\($0.id)" },
                parentKey: issue.fields.parent?.key,
                isSubtask: issue.fields.issueType?.subtask ?? (issue.fields.parent != nil),
                subtaskIDs: issue.fields.subtasks.map { "\(project.workspaceID):\($0.id)" },
                assigneeName: issue.fields.assignee?.displayName,
                createdAt: issue.fields.created,
                updatedAt: issue.fields.updated
            )
        }

        let parentIDsByCommentID = (try? await commentParentIDs(
            from: issues.flatMap(\.comments).map(\.id),
            cloudID: project.workspaceID,
            accessToken: token.accessToken
        )) ?? [:]

        if parentIDsByCommentID.isEmpty == false {
            for issueIndex in issues.indices {
                for commentIndex in issues[issueIndex].comments.indices {
                    let commentID = issues[issueIndex].comments[commentIndex].id
                    guard issues[issueIndex].comments[commentIndex].parentID == nil,
                          let parentID = parentIDsByCommentID[commentID]
                    else { continue }

                    issues[issueIndex].comments[commentIndex].parentID = parentID
                }
            }
        }

        return issues
    }

    func issueTypes(for project: Project) async throws -> [IssueTypeMetadata] {
        guard let token = try authService.currentToken() else {
            throw AuthError.invalidConfiguration
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.atlassian.com"
        components.path = "/ex/jira/\(project.workspaceID)/rest/api/3/issue/createmeta/\(project.key)/issuetypes"
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
            let message = String(data: data, encoding: .utf8) ?? "Unable to load Jira issue types."
            throw AuthError.failedTokenExchange(message)
        }

        let page = try JSONDecoder().decode(JiraCreateIssueTypesPageDTO.self, from: data)
        return page.issueTypes.map {
            IssueTypeMetadata(id: $0.id, name: $0.name, isSubtask: $0.subtask)
        }
    }

    func creationMetadata(for project: Project, issueTypeID: IssueTypeMetadata.ID) async throws -> IssueCreationMetadata {
        guard let token = try authService.currentToken() else {
            throw AuthError.invalidConfiguration
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.atlassian.com"
        components.path = "/ex/jira/\(project.workspaceID)/rest/api/3/issue/createmeta/\(project.key)/issuetypes/\(issueTypeID)"
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
            let message = String(data: data, encoding: .utf8) ?? "Unable to load Jira create fields."
            throw AuthError.failedTokenExchange(message)
        }

        let page = try JSONDecoder().decode(JiraCreateIssueFieldsPageDTO.self, from: data)
        return IssueCreationMetadata(fields: page.fields.map(\.domainValue))
    }

    func createIssue(in project: Project, draft: IssueCreationDraft) async throws -> CreatedIssue {
        guard let token = try authService.currentToken() else {
            throw AuthError.invalidConfiguration
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.atlassian.com"
        components.path = "/ex/jira/\(project.workspaceID)/rest/api/3/issue"

        guard let url = components.url else {
            throw AuthError.invalidConfiguration
        }

        var fields: [String: Any] = [
            "project": ["key": project.key],
            "issuetype": ["id": draft.issueTypeID],
            "summary": draft.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        ]

        if let parentIssueKey = draft.parentIssueKey {
            fields["parent"] = ["key": parentIssueKey]
        }

        if let description = draft.descriptionText?.trimmingCharacters(in: .whitespacesAndNewlines),
           !description.isEmpty {
            fields["description"] = adfDocument(text: description)
        }

        if let storyPoints = draft.storyPoints,
           let fieldID = try await storyPointsFieldIDs(
                projectKey: project.key,
                accessToken: token.accessToken,
                cloudID: project.workspaceID
           ).first {
            fields[fieldID] = NSNumber(value: storyPoints)
        }

        if draft.assignToCurrentUser {
            let user = try await currentUser(cloudID: project.workspaceID)
            fields["assignee"] = ["accountId": user.accountID]
        }

        let payload: [String: Any] = ["fields": fields]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidServerResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unable to create Jira issue."
            throw AuthError.failedTokenExchange(message)
        }

        let createdIssue = try JSONDecoder().decode(JiraCreatedIssueDTO.self, from: data)
        if let targetSprintID = draft.targetSprintID {
            try await moveIssue(
                issueKey: createdIssue.key,
                toSprintID: targetSprintID,
                cloudID: project.workspaceID,
                accessToken: token.accessToken
            )
        }

        return CreatedIssue(id: "\(project.workspaceID):\(createdIssue.id)", key: createdIssue.key)
    }

    func currentUser(cloudID: String) async throws -> JiraUser {
        guard let token = try authService.currentToken() else {
            throw AuthError.invalidConfiguration
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.atlassian.com"
        components.path = "/ex/jira/\(cloudID)/rest/api/3/myself"

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
            let message = String(data: data, encoding: .utf8) ?? "Unable to load Jira current user."
            throw AuthError.failedTokenExchange(message)
        }

        let user = try JSONDecoder().decode(JiraUserDTO.self, from: data)
        return user.domainValue
    }

    func assignableUsers(for project: Project) async throws -> [JiraUser] {
        guard let token = try authService.currentToken() else {
            throw AuthError.invalidConfiguration
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.atlassian.com"
        components.path = "/ex/jira/\(project.workspaceID)/rest/api/3/user/assignable/multiProjectSearch"
        components.queryItems = [
            URLQueryItem(name: "projectKeys", value: project.key),
            URLQueryItem(name: "startAt", value: "0"),
            URLQueryItem(name: "maxResults", value: "1000")
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
            let message = String(data: data, encoding: .utf8) ?? "Unable to load Jira project users."
            throw AuthError.failedTokenExchange(message)
        }

        return try JSONDecoder().decode([JiraUserDTO].self, from: data).map(\.domainValue)
    }

    func assignIssueToCurrentUser(issue: Issue) async throws -> JiraUser {
        guard let cloudID = cloudID(from: issue) else {
            throw AuthError.invalidConfiguration
        }

        let user = try await currentUser(cloudID: cloudID)
        try await assignIssue(issue: issue, to: user)
        return user
    }

    func assignIssue(issue: Issue, to user: JiraUser) async throws {
        try await updateIssueAssignee(issue: issue, accountID: user.accountID)
    }

    func unassignIssue(issue: Issue) async throws {
        try await updateIssueAssignee(issue: issue, accountID: nil)
    }

    private func updateIssueAssignee(issue: Issue, accountID: String?) async throws {
        guard let token = try authService.currentToken() else {
            throw AuthError.invalidConfiguration
        }
        guard let cloudID = cloudID(from: issue) else {
            throw AuthError.invalidConfiguration
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.atlassian.com"
        components.path = "/ex/jira/\(cloudID)/rest/api/3/issue/\(issue.key)/assignee"

        guard let url = components.url else {
            throw AuthError.invalidConfiguration
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        let assigneeValue: Any = accountID ?? NSNull()
        request.httpBody = try JSONSerialization.data(withJSONObject: ["accountId": assigneeValue])
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidServerResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unable to assign Jira issue."
            throw AuthError.failedTokenExchange(message)
        }
    }

    func changelog(for issue: Issue) async throws -> [IssueChange] {
        guard let token = try authService.currentToken() else {
            throw AuthError.invalidConfiguration
        }
        guard let cloudID = cloudID(from: issue) else {
            throw AuthError.invalidConfiguration
        }

        return try await changelog(
            issueKey: issue.key,
            cloudID: cloudID,
            accessToken: token.accessToken
        )
    }

    func addComment(issue: Issue, bodyText: String, replyTo parentComment: IssueComment?) async throws -> IssueComment {
        guard let token = try authService.currentToken() else {
            throw AuthError.invalidConfiguration
        }
        guard let cloudID = cloudID(from: issue) else {
            throw AuthError.invalidConfiguration
        }

        let trimmedBody = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBody.isEmpty else {
            throw AuthError.failedTokenExchange("Comment cannot be empty.")
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.atlassian.com"
        components.path = "/ex/jira/\(cloudID)/rest/api/3/issue/\(issue.key)/comment"

        guard let url = components.url else {
            throw AuthError.invalidConfiguration
        }

        var payload: [String: Any] = [
            "body": adfCommentDocument(text: trimmedBody, mentioning: parentComment)
        ]

        if let parentComment {
            payload["properties"] = [
                [
                    "key": replyParentPropertyKey,
                    "value": ["parentCommentId": parentComment.id]
                ]
            ]
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidServerResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unable to add Jira comment."
            throw AuthError.failedTokenExchange(message)
        }

        var comment = try jiraDecoder.decode(JiraCommentDTO.self, from: data).domainValue
        if comment.parentID == nil {
            comment.parentID = parentComment?.id
        }
        return comment
    }

    func deleteComment(issue: Issue, comment: IssueComment) async throws {
        guard let token = try authService.currentToken() else {
            throw AuthError.invalidConfiguration
        }
        guard let cloudID = cloudID(from: issue) else {
            throw AuthError.invalidConfiguration
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.atlassian.com"
        components.path = "/ex/jira/\(cloudID)/rest/api/3/issue/\(issue.key)/comment/\(comment.id)"

        guard let url = components.url else {
            throw AuthError.invalidConfiguration
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidServerResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unable to delete Jira comment."
            throw AuthError.failedTokenExchange(message)
        }
    }

    func deleteIssue(_ issue: Issue, deleteSubtasks: Bool) async throws {
        guard let token = try authService.currentToken() else {
            throw AuthError.invalidConfiguration
        }
        guard let cloudID = cloudID(from: issue) else {
            throw AuthError.invalidConfiguration
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.atlassian.com"
        components.path = "/ex/jira/\(cloudID)/rest/api/3/issue/\(issue.key)"
        if deleteSubtasks {
            components.queryItems = [
                URLQueryItem(name: "deleteSubtasks", value: "true")
            ]
        }

        guard let url = components.url else {
            throw AuthError.invalidConfiguration
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidServerResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unable to delete Jira issue."
            throw AuthError.failedTokenExchange(message)
        }
    }

    func transition(issue: Issue, toStatus status: String) async throws {
        guard issue.status != status else { return }
        guard let token = try authService.currentToken() else {
            throw AuthError.invalidConfiguration
        }
        guard let cloudID = cloudID(from: issue) else {
            throw AuthError.invalidConfiguration
        }

        let transitions = try await transitions(
            issueKey: issue.key,
            cloudID: cloudID,
            accessToken: token.accessToken
        )

        guard let transition = transitions.first(where: {
            $0.to.name.localizedCaseInsensitiveCompare(status) == .orderedSame
        }) else {
            throw AuthError.failedTokenExchange(
                "No Jira transition available from \(issue.status) to \(status) for \(issue.key)."
            )
        }

        try await performTransition(
            issueKey: issue.key,
            cloudID: cloudID,
            accessToken: token.accessToken,
            transitionID: transition.id
        )
    }

    func updateSprint(issue: Issue, sprintName: String?) async throws -> IssueSprintValue {
        guard let token = try authService.currentToken() else {
            throw AuthError.invalidConfiguration
        }
        guard let cloudID = cloudID(from: issue) else {
            throw AuthError.invalidConfiguration
        }

        let trimmedSprintName = sprintName?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmedSprintName, !trimmedSprintName.isEmpty, trimmedSprintName.localizedCaseInsensitiveCompare("Backlog") != .orderedSame else {
            try await moveIssueToBacklog(issueKey: issue.key, cloudID: cloudID, accessToken: token.accessToken)
            return IssueSprintValue(id: nil, name: nil, state: nil)
        }

        let sprint = try await resolveSprint(
            named: trimmedSprintName,
            issue: issue,
            cloudID: cloudID,
            accessToken: token.accessToken
        )

        try await moveIssue(issueKey: issue.key, toSprintID: sprint.id, cloudID: cloudID, accessToken: token.accessToken)
        return IssueSprintValue(id: sprint.id, name: sprint.name, state: sprint.state)
    }

    func updateStoryPoints(issue: Issue, storyPoints: Double?) async throws {
        guard let token = try authService.currentToken() else {
            throw AuthError.invalidConfiguration
        }
        guard let cloudID = cloudID(from: issue) else {
            throw AuthError.invalidConfiguration
        }
        let fallbackFieldID: String?
        if issue.storyPointsFieldID == nil {
            fallbackFieldID = try await storyPointsFieldIDs(
                projectKey: projectKey(from: issue),
                accessToken: token.accessToken,
                cloudID: cloudID
            ).first
        } else {
            fallbackFieldID = nil
        }

        let fieldID = issue.storyPointsFieldID ?? fallbackFieldID
        guard let fieldID else {
            throw AuthError.failedTokenExchange("Unable to find the Jira Story Points field.")
        }

        try await updateIssueField(
            issueKey: issue.key,
            cloudID: cloudID,
            accessToken: token.accessToken,
            fieldID: fieldID,
            value: storyPoints
        )
    }

    func updateSummary(issue: Issue, summary: String) async throws {
        guard let token = try authService.currentToken() else {
            throw AuthError.invalidConfiguration
        }
        guard let cloudID = cloudID(from: issue) else {
            throw AuthError.invalidConfiguration
        }

        let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSummary.isEmpty else {
            throw AuthError.failedTokenExchange("Issue summary cannot be empty.")
        }

        try await updateIssueFields(
            issueKey: issue.key,
            cloudID: cloudID,
            accessToken: token.accessToken,
            fields: ["summary": trimmedSummary],
            failureMessage: "Unable to update Jira issue summary."
        )
    }

    func updateDescription(issue: Issue, descriptionText: String?) async throws {
        guard let token = try authService.currentToken() else {
            throw AuthError.invalidConfiguration
        }
        guard let cloudID = cloudID(from: issue) else {
            throw AuthError.invalidConfiguration
        }

        let trimmedDescription = descriptionText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptionValue: Any = {
            guard let trimmedDescription, !trimmedDescription.isEmpty else {
                return NSNull()
            }
            return adfDocument(text: trimmedDescription)
        }()

        try await updateIssueFields(
            issueKey: issue.key,
            cloudID: cloudID,
            accessToken: token.accessToken,
            fields: ["description": descriptionValue],
            failureMessage: "Unable to update Jira issue description."
        )
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

    private func storyPointsFieldIDs(projectKey: String, accessToken: String, cloudID: String) async throws -> [String] {
        var fieldIDs: [String] = []

        if let boardFieldID = try await storyPointsFieldIDFromBoardConfiguration(
            projectKey: projectKey,
            accessToken: accessToken,
            cloudID: cloudID
        ) {
            fieldIDs.append(boardFieldID)
        }

        let globalFieldIDs = try await storyPointsFieldIDs(accessToken: accessToken, cloudID: cloudID)
        for fieldID in globalFieldIDs where fieldIDs.contains(fieldID) == false {
            fieldIDs.append(fieldID)
        }

        return fieldIDs
    }

    private func storyPointsFieldIDFromBoardConfiguration(projectKey: String, accessToken: String, cloudID: String) async throws -> String? {
        let projectBoards: [JiraBoardDTO]
        do {
            projectBoards = try await boards(projectKey: projectKey, cloudID: cloudID, accessToken: accessToken)
        } catch {
            return nil
        }

        for board in projectBoards {
            guard let configuration = try? await boardConfiguration(
                boardID: board.id,
                cloudID: cloudID,
                accessToken: accessToken
            ) else { continue }

            guard configuration.estimation?.type == "field",
                  let fieldID = configuration.estimation?.field?.fieldId
            else { continue }

            return fieldID
        }

        return nil
    }

    private func storyPointsFieldIDs(accessToken: String, cloudID: String) async throws -> [String] {
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
            return []
        }

        let fields = try JSONDecoder().decode([JiraFieldDTO].self, from: data)
        return fields.compactMap { field in
            guard isStoryPointsFieldName(field.name) else { return nil }

            return field.id
        }
    }

    private func isStoryPointsFieldName(_ name: String) -> Bool {
        let normalizedName = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()

        if normalizedName == "story points"
            || normalizedName == "story point"
            || normalizedName == "story point estimate"
            || normalizedName == "story points estimate"
            || normalizedName == "story points estimation" {
            return true
        }

        let hasStory = normalizedName.contains("story")
        let hasPoint = normalizedName.contains("point")
        let hasEstimate = normalizedName.contains("estimate") || normalizedName.contains("estimation")
        let hasFrenchStory = normalizedName.contains("histoire")

        return (hasStory && hasPoint) || (hasStory && hasEstimate) || (hasFrenchStory && hasPoint)
    }

    private func searchIssues(
        project: Project,
        fieldNames: [String],
        accessToken: String,
        storyPointsFieldIDs: [String]
    ) async throws -> [IssueDTO] {
        var allIssues: [IssueDTO] = []
        var nextPageToken: String?
        var shouldContinue = true

        while shouldContinue && allIssues.count < issueFetchLimit {
            let remainingResults = issueFetchLimit - allIssues.count
            let pageSize = min(100, remainingResults)
            var requestedFieldNames = fieldNames
            if requestedFieldNames.contains("*all") == false {
                requestedFieldNames.append("*all")
            }
            var components = URLComponents()
            components.scheme = "https"
            components.host = "api.atlassian.com"
            components.path = "/ex/jira/\(project.workspaceID)/rest/api/3/search/jql"
            components.queryItems = [
                URLQueryItem(name: "jql", value: "project = \(project.key) ORDER BY updated DESC"),
                URLQueryItem(name: "maxResults", value: "\(pageSize)"),
                URLQueryItem(name: "fields", value: requestedFieldNames.joined(separator: ",")),
                URLQueryItem(name: "expand", value: "names")
            ]

            if let nextPageToken {
                components.queryItems?.append(URLQueryItem(name: "nextPageToken", value: nextPageToken))
            }

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
                let message = String(data: data, encoding: .utf8) ?? "Unable to load Jira issues."
                throw AuthError.failedTokenExchange(message)
            }

            do {
                let decoder = jiraDecoder
                decoder.userInfo[.storyPointsFieldIDs] = storyPointsFieldIDs
                let page = try decoder.decode(IssueSearchResponse.self, from: data)
                let pageStoryPointsFieldIDs = storyPointsFieldIDsFromFieldNames(
                    fromFieldNames: page.names,
                    appendingTo: storyPointsFieldIDs
                )
                let pageIssues = try decodeIssues(from: data, storyPointsFieldIDs: pageStoryPointsFieldIDs).issues
                allIssues.append(contentsOf: pageIssues)
                nextPageToken = page.nextPageToken
                shouldContinue = page.isLast == false && page.nextPageToken != nil && allIssues.count < issueFetchLimit
            } catch {
                let payload = String(data: data, encoding: .utf8) ?? "<non-utf8 response>"
                throw AuthError.failedTokenExchange("Unable to decode Jira issues: \(payload)")
            }
        }

        return allIssues
    }

    private func decodeIssues(from data: Data, storyPointsFieldIDs: [String]) throws -> IssueSearchResponse {
        let decoder = jiraDecoder
        decoder.userInfo[.storyPointsFieldIDs] = storyPointsFieldIDs
        return try decoder.decode(IssueSearchResponse.self, from: data)
    }

    private func commentParentIDs(from commentIDs: [String], cloudID: String, accessToken: String) async throws -> [String: String] {
        let numericIDs = Array(Set(commentIDs.compactMap(Int.init)))
        guard numericIDs.isEmpty == false else { return [:] }

        var parentIDsByCommentID: [String: String] = [:]

        for batchStart in stride(from: 0, to: numericIDs.count, by: 100) {
            let batchEnd = min(batchStart + 100, numericIDs.count)
            let batch = Array(numericIDs[batchStart..<batchEnd])

            var components = URLComponents()
            components.scheme = "https"
            components.host = "api.atlassian.com"
            components.path = "/ex/jira/\(cloudID)/rest/api/3/comment/list"
            components.queryItems = [
                URLQueryItem(name: "expand", value: "properties")
            ]

            guard let url = components.url else {
                throw AuthError.invalidConfiguration
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = try JSONSerialization.data(withJSONObject: ["ids": batch])
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthError.invalidServerResponse
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                let message = String(data: data, encoding: .utf8) ?? "Unable to load Jira comment properties."
                throw AuthError.failedTokenExchange(message)
            }

            let page = try jiraDecoder.decode(JiraCommentListDTO.self, from: data)
            for comment in page.values {
                guard let parentID = comment.parentIDFromProperties(propertyKey: replyParentPropertyKey) else { continue }
                parentIDsByCommentID[comment.id] = parentID
            }
        }

        return parentIDsByCommentID
    }

    private func storyPointsFieldIDsFromFieldNames(fromFieldNames fieldNames: [String: String], appendingTo existingFieldIDs: [String]) -> [String] {
        var fieldIDs = existingFieldIDs
        for (fieldID, name) in fieldNames where fieldID.hasPrefix("customfield_") && isStoryPointsFieldName(name) {
            if fieldIDs.contains(fieldID) == false {
                fieldIDs.append(fieldID)
            }
        }
        return fieldIDs
    }

    private func transitions(issueKey: String, cloudID: String, accessToken: String) async throws -> [IssueTransitionDTO] {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.atlassian.com"
        components.path = "/ex/jira/\(cloudID)/rest/api/3/issue/\(issueKey)/transitions"

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
            let message = String(data: data, encoding: .utf8) ?? "Unable to load Jira transitions."
            throw AuthError.failedTokenExchange(message)
        }

        return try JSONDecoder().decode(IssueTransitionsResponse.self, from: data).transitions
    }

    private func resolveSprint(
        named sprintName: String,
        issue: Issue,
        cloudID: String,
        accessToken: String
    ) async throws -> JiraSprintDTO {
        if let sprintID = issue.sprintID,
           issue.sprintName?.localizedCaseInsensitiveCompare(sprintName) == .orderedSame {
            return JiraSprintDTO(id: sprintID, name: sprintName, state: issue.sprintState)
        }

        let boards = try await boards(projectKey: projectKey(from: issue), cloudID: cloudID, accessToken: accessToken)

        for board in boards {
            let sprints = try await sprints(boardID: board.id, cloudID: cloudID, accessToken: accessToken)
            if let sprint = sprints.first(where: { $0.name.localizedCaseInsensitiveCompare(sprintName) == .orderedSame }) {
                return sprint
            }
        }

        throw AuthError.failedTokenExchange("Unable to find an active or future sprint named \(sprintName).")
    }

    private func boards(projectKey: String, cloudID: String, accessToken: String) async throws -> [JiraBoardDTO] {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.atlassian.com"
        components.path = "/ex/jira/\(cloudID)/rest/agile/1.0/board"
        components.queryItems = [
            URLQueryItem(name: "projectKeyOrId", value: projectKey),
            URLQueryItem(name: "type", value: "scrum"),
            URLQueryItem(name: "maxResults", value: "50")
        ]

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
            let message = String(data: data, encoding: .utf8) ?? "Unable to load Jira boards."
            throw AuthError.failedTokenExchange(message)
        }

        return try JSONDecoder().decode(JiraBoardPageDTO.self, from: data).values
    }

    private func boardConfiguration(boardID: Int, cloudID: String, accessToken: String) async throws -> JiraBoardConfigurationDTO {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.atlassian.com"
        components.path = "/ex/jira/\(cloudID)/rest/agile/1.0/board/\(boardID)/configuration"

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
            let message = String(data: data, encoding: .utf8) ?? "Unable to load Jira board configuration."
            throw AuthError.failedTokenExchange(message)
        }

        return try JSONDecoder().decode(JiraBoardConfigurationDTO.self, from: data)
    }

    private func sprints(boardID: Int, cloudID: String, accessToken: String) async throws -> [JiraSprintDTO] {
        var allSprints: [JiraSprintDTO] = []
        var startAt = 0
        var shouldContinue = true

        while shouldContinue {
            var components = URLComponents()
            components.scheme = "https"
            components.host = "api.atlassian.com"
            components.path = "/ex/jira/\(cloudID)/rest/agile/1.0/board/\(boardID)/sprint"
            components.queryItems = [
                URLQueryItem(name: "state", value: "active,future"),
                URLQueryItem(name: "startAt", value: "\(startAt)"),
                URLQueryItem(name: "maxResults", value: "50")
            ]

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
                let message = String(data: data, encoding: .utf8) ?? "Unable to load Jira sprints."
                throw AuthError.failedTokenExchange(message)
            }

            let page = try JSONDecoder().decode(JiraSprintPageDTO.self, from: data)
            allSprints.append(contentsOf: page.values)
            startAt += page.maxResults
            shouldContinue = startAt < page.total
        }

        return allSprints
    }

    private func moveIssue(issueKey: String, toSprintID sprintID: Int, cloudID: String, accessToken: String) async throws {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.atlassian.com"
        components.path = "/ex/jira/\(cloudID)/rest/agile/1.0/sprint/\(sprintID)/issue"

        guard let url = components.url else {
            throw AuthError.invalidConfiguration
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(MoveIssuesRequest(issues: [issueKey]))
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidServerResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unable to move Jira issue to sprint."
            throw AuthError.failedTokenExchange(message)
        }
    }

    private func moveIssueToBacklog(issueKey: String, cloudID: String, accessToken: String) async throws {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.atlassian.com"
        components.path = "/ex/jira/\(cloudID)/rest/agile/1.0/backlog/issue"

        guard let url = components.url else {
            throw AuthError.invalidConfiguration
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(MoveIssuesRequest(issues: [issueKey]))
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidServerResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unable to move Jira issue to backlog."
            throw AuthError.failedTokenExchange(message)
        }
    }

    private func updateIssueField(
        issueKey: String,
        cloudID: String,
        accessToken: String,
        fieldID: String,
        value: Double?
    ) async throws {
        let fieldValue: Any = value.map { NSNumber(value: $0) } ?? NSNull()
        try await updateIssueFields(
            issueKey: issueKey,
            cloudID: cloudID,
            accessToken: accessToken,
            fields: [fieldID: fieldValue],
            failureMessage: "Unable to update Jira story points."
        )
    }

    private func updateIssueFields(
        issueKey: String,
        cloudID: String,
        accessToken: String,
        fields: [String: Any],
        failureMessage: String
    ) async throws {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.atlassian.com"
        components.path = "/ex/jira/\(cloudID)/rest/api/3/issue/\(issueKey)"

        guard let url = components.url else {
            throw AuthError.invalidConfiguration
        }

        let payload: [String: Any] = [
            "fields": fields
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidServerResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? failureMessage
            throw AuthError.failedTokenExchange(message)
        }
    }

    private func changelog(issueKey: String, cloudID: String, accessToken: String) async throws -> [IssueChange] {
        var changes: [IssueChange] = []
        var startAt = 0
        var shouldContinue = true

        while shouldContinue && changes.count < changelogFetchLimit {
            let remainingResults = changelogFetchLimit - changes.count
            let pageSize = min(50, remainingResults)
            var components = URLComponents()
            components.scheme = "https"
            components.host = "api.atlassian.com"
            components.path = "/ex/jira/\(cloudID)/rest/api/3/issue/\(issueKey)/changelog"
            components.queryItems = [
                URLQueryItem(name: "startAt", value: "\(startAt)"),
                URLQueryItem(name: "maxResults", value: "\(pageSize)")
            ]

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
                let message = String(data: data, encoding: .utf8) ?? "Unable to load Jira changelog."
                throw AuthError.failedTokenExchange(message)
            }

            let page = try jiraDecoder.decode(JiraChangelogPageDTO.self, from: data)
            changes.append(contentsOf: page.values.flatMap(\.domainValues))

            let nextStartAt = page.startAt + page.maxResults
            shouldContinue = nextStartAt < page.total && changes.count < changelogFetchLimit
            startAt = nextStartAt
        }

        return changes.sorted { lhs, rhs in
            lhs.createdAt > rhs.createdAt
        }
    }

    private func performTransition(
        issueKey: String,
        cloudID: String,
        accessToken: String,
        transitionID: String
    ) async throws {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.atlassian.com"
        components.path = "/ex/jira/\(cloudID)/rest/api/3/issue/\(issueKey)/transitions"

        guard let url = components.url else {
            throw AuthError.invalidConfiguration
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(
            TransitionIssueRequest(transition: TransitionIDDTO(id: transitionID))
        )
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidServerResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unable to transition Jira issue."
            throw AuthError.failedTokenExchange(message)
        }
    }

    private func cloudID(from issue: Issue) -> String? {
        issue.id.split(separator: ":", maxSplits: 1).first.map(String.init)
    }

    private func projectKey(from issue: Issue) -> String {
        issue.key.split(separator: "-", maxSplits: 1).first.map(String.init) ?? issue.key
    }

    private func adfDocument(text: String) -> [String: Any] {
        let paragraphs = text
            .components(separatedBy: .newlines)
            .map { line -> [String: Any] in
                [
                    "type": "paragraph",
                    "content": line.isEmpty ? [] : [
                        [
                            "type": "text",
                            "text": line
                        ]
                    ]
                ]
            }

        return [
            "type": "doc",
            "version": 1,
            "content": paragraphs
        ]
    }

    private func adfCommentDocument(text: String, mentioning comment: IssueComment?) -> [String: Any] {
        var paragraphs = adfDocument(text: text)["content"] as? [[String: Any]] ?? []
        guard let accountID = comment?.authorAccountID,
              let authorName = comment?.authorName,
              paragraphs.isEmpty == false
        else {
            return adfDocument(text: text)
        }

        var firstParagraph = paragraphs[0]
        var content = firstParagraph["content"] as? [[String: Any]] ?? []
        let mention: [String: Any] = [
            "type": "mention",
            "attrs": [
                "id": accountID,
                "text": "@\(authorName)"
            ]
        ]
        let space: [String: Any] = [
            "type": "text",
            "text": " "
        ]
        content.insert(space, at: 0)
        content.insert(mention, at: 0)
        firstParagraph["content"] = content
        paragraphs[0] = firstParagraph

        return [
            "type": "doc",
            "version": 1,
            "content": paragraphs
        ]
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
    var isLast: Bool
    var nextPageToken: String?
    var names: [String: String]
    var issues: [IssueDTO]

    private enum CodingKeys: String, CodingKey {
        case isLast
        case nextPageToken
        case names
        case issues
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        isLast = try values.decode(Bool.self, forKey: .isLast)
        nextPageToken = try values.decodeIfPresent(String.self, forKey: .nextPageToken)
        names = try values.decodeIfPresent([String: String].self, forKey: .names) ?? [:]
        issues = try values.decode([IssueDTO].self, forKey: .issues)
    }
}

private struct IssueDTO: Decodable {
    var id: String
    var key: String
    var fields: IssueFieldsDTO
}

private struct JiraCreateIssueTypesPageDTO: Decodable {
    var issueTypes: [JiraCreateIssueTypeDTO]

    private enum CodingKeys: String, CodingKey {
        case issueTypes
        case values
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        issueTypes = try values.decodeIfPresent([JiraCreateIssueTypeDTO].self, forKey: .issueTypes)
            ?? values.decodeIfPresent([JiraCreateIssueTypeDTO].self, forKey: .values)
            ?? []
    }
}

private struct JiraCreateIssueTypeDTO: Decodable {
    var id: String
    var name: String
    var subtask: Bool
}

private struct JiraCreateIssueFieldsPageDTO: Decodable {
    var fields: [JiraCreateIssueFieldDTO]

    private enum CodingKeys: String, CodingKey {
        case fields
        case results
        case values
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        fields = try values.decodeIfPresent([JiraCreateIssueFieldDTO].self, forKey: .fields)
            ?? values.decodeIfPresent([JiraCreateIssueFieldDTO].self, forKey: .results)
            ?? values.decodeIfPresent([JiraCreateIssueFieldDTO].self, forKey: .values)
            ?? []
    }
}

private struct JiraCreateIssueFieldDTO: Decodable {
    var fieldId: String
    var name: String
    var required: Bool
    var hasDefaultValue: Bool?
    var operations: [String]?

    var domainValue: IssueCreationField {
        IssueCreationField(
            id: fieldId,
            name: name,
            isRequired: required,
            hasDefaultValue: hasDefaultValue ?? false,
            operations: operations ?? []
        )
    }
}

private struct JiraCreatedIssueDTO: Decodable {
    var id: String
    var key: String
}

private struct JiraUserDTO: Decodable {
    var accountId: String
    var displayName: String
    var avatarUrls: JiraUserAvatarURLsDTO?

    var domainValue: JiraUser {
        JiraUser(
            accountID: accountId,
            displayName: displayName,
            avatarURL: avatarUrls?.bestAvailableURL
        )
    }
}

private struct JiraUserAvatarURLsDTO: Decodable {
    var x48: URL?
    var x32: URL?
    var x24: URL?
    var x16: URL?

    private enum CodingKeys: String, CodingKey {
        case x48 = "48x48"
        case x32 = "32x32"
        case x24 = "24x24"
        case x16 = "16x16"
    }

    var bestAvailableURL: URL? {
        x48 ?? x32 ?? x24 ?? x16
    }
}

private struct IssueFieldsDTO: Decodable {
    var summary: String
    var descriptionText: String?
    var comments: [IssueComment]
    var status: IssueStatusDTO
    var storyPoints: Double?
    var sprintName: String?
    var sprintState: String?
    var assignee: IssueUserDTO?
    var reporter: IssueUserDTO?
    var priority: IssueNamedDTO?
    var labels: [String]
    var storyPointsFieldID: String?
    var sprintID: Int?
    var created: Date?
    var updated: Date
    var parent: IssueParentDTO?
    var subtasks: [IssueSubtaskDTO]
    var issueType: IssueTypeDTO?

    private enum CodingKeys: String, CodingKey {
        case summary
        case description
        case comment
        case status
        case assignee
        case reporter
        case priority
        case labels
        case created
        case updated
        case parent
        case subtasks
        case issueType = "issuetype"
    }

    init(from decoder: Decoder) throws {
        let knownValues = try decoder.container(keyedBy: CodingKeys.self)
        summary = try knownValues.decode(String.self, forKey: .summary)
        descriptionText = try knownValues.decodeIfPresent(JiraDocumentDTO.self, forKey: .description)?.plainText
        comments = try knownValues
            .decodeIfPresent(JiraCommentPageDTO.self, forKey: .comment)?
            .comments
            .map(\.domainValue) ?? []
        status = try knownValues.decode(IssueStatusDTO.self, forKey: .status)
        assignee = try knownValues.decodeIfPresent(IssueUserDTO.self, forKey: .assignee)
        reporter = try knownValues.decodeIfPresent(IssueUserDTO.self, forKey: .reporter)
        priority = try knownValues.decodeIfPresent(IssueNamedDTO.self, forKey: .priority)
        labels = try knownValues.decodeIfPresent([String].self, forKey: .labels) ?? []
        created = try knownValues.decodeIfPresent(Date.self, forKey: .created)
        updated = try knownValues.decode(Date.self, forKey: .updated)
        parent = try knownValues.decodeIfPresent(IssueParentDTO.self, forKey: .parent)
        subtasks = try knownValues.decodeIfPresent([IssueSubtaskDTO].self, forKey: .subtasks) ?? []
        issueType = try knownValues.decodeIfPresent(IssueTypeDTO.self, forKey: .issueType)

        let customValues = try decoder.container(keyedBy: DynamicCodingKey.self)
        if let storyPointsFieldIDs = decoder.userInfo[.storyPointsFieldIDs] as? [String] {
            for fieldID in storyPointsFieldIDs {
                guard let storyPointsKey = DynamicCodingKey(stringValue: fieldID) else { continue }

                if let value = try customValues.decodeIfPresent(Double.self, forKey: storyPointsKey) {
                    storyPointsFieldID = fieldID
                    storyPoints = value
                    break
                }

                if let value = try customValues.decodeIfPresent(Int.self, forKey: storyPointsKey) {
                    storyPointsFieldID = fieldID
                    storyPoints = Double(value)
                    break
                }
            }
        }

        let sprintInfo = customValues.allKeys
            .lazy
            .filter { $0.stringValue.hasPrefix("customfield_") }
            .compactMap { key -> IssueSprintInfo? in
                if let sprints = try? customValues.decodeIfPresent([IssueSprintDTO].self, forKey: key) {
                    guard let sprint = sprints.last else { return nil }
                    return IssueSprintInfo(id: sprint.id, name: sprint.name, state: sprint.state)
                }

                if let sprint = try? customValues.decodeIfPresent(IssueSprintDTO.self, forKey: key) {
                    return IssueSprintInfo(id: sprint.id, name: sprint.name, state: sprint.state)
                }

                return nil
            }
            .first

        sprintID = sprintInfo?.id
        sprintName = sprintInfo?.name
        sprintState = sprintInfo?.state
    }
}

private extension CodingUserInfoKey {
    static let storyPointsFieldIDs = CodingUserInfoKey(rawValue: "storyPointsFieldIDs")!
}

private struct IssueStatusDTO: Decodable {
    var name: String
    var statusCategory: IssueStatusCategoryDTO?
}

private struct IssueStatusCategoryDTO: Decodable {
    var key: String
}

private struct IssueTransitionsResponse: Decodable {
    var transitions: [IssueTransitionDTO]
}

private struct IssueTransitionDTO: Decodable {
    var id: String
    var name: String
    var to: IssueStatusDTO
}

private struct TransitionIssueRequest: Encodable {
    var transition: TransitionIDDTO
}

private struct TransitionIDDTO: Encodable {
    var id: String
}

private struct MoveIssuesRequest: Encodable {
    var issues: [String]
}

private struct JiraBoardPageDTO: Decodable {
    var values: [JiraBoardDTO]
}

private struct JiraBoardDTO: Decodable {
    var id: Int
}

private struct JiraBoardConfigurationDTO: Decodable {
    var estimation: JiraBoardEstimationDTO?
}

private struct JiraBoardEstimationDTO: Decodable {
    var type: String?
    var field: JiraBoardEstimationFieldDTO?
}

private struct JiraBoardEstimationFieldDTO: Decodable {
    var displayName: String?
    var fieldId: String
}

private struct JiraSprintPageDTO: Decodable {
    var maxResults: Int
    var total: Int
    var values: [JiraSprintDTO]
}

private struct JiraSprintDTO: Decodable {
    var id: Int
    var name: String
    var state: String?
}

private struct JiraChangelogPageDTO: Decodable {
    var startAt: Int
    var maxResults: Int
    var total: Int
    var values: [JiraChangelogHistoryDTO]
}

private struct JiraChangelogHistoryDTO: Decodable {
    var id: String
    var author: IssueUserDTO?
    var created: Date
    var items: [JiraChangelogItemDTO]

    var domainValues: [IssueChange] {
        items.enumerated().map { index, item in
            IssueChange(
                id: "\(id):\(index)",
                authorName: author?.displayName,
                createdAt: created,
                fieldName: item.field,
                fromValue: item.fromString,
                toValue: item.toString
            )
        }
    }
}

private struct JiraChangelogItemDTO: Decodable {
    var field: String
    var fromString: String?
    var toString: String?
}

private struct IssueUserDTO: Decodable {
    var accountId: String?
    var displayName: String
}

private struct IssueNamedDTO: Decodable {
    var name: String
}

private struct JiraCommentPageDTO: Decodable {
    var comments: [JiraCommentDTO]
}

private struct JiraCommentListDTO: Decodable {
    var values: [JiraCommentDTO]
}

private struct JiraCommentDTO: Decodable {
    var id: String
    var author: IssueUserDTO?
    var body: JiraDocumentDTO?
    var created: Date
    var updated: Date?
    var parentId: String?
    var properties: [JiraCommentPropertyDTO]

    private enum CodingKeys: String, CodingKey {
        case id
        case author
        case body
        case created
        case updated
        case parentId
        case parent
        case properties
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        author = try values.decodeIfPresent(IssueUserDTO.self, forKey: .author)
        body = try values.decodeIfPresent(JiraDocumentDTO.self, forKey: .body)
        created = try values.decode(Date.self, forKey: .created)
        updated = try values.decodeIfPresent(Date.self, forKey: .updated)
        properties = try values.decodeIfPresent([JiraCommentPropertyDTO].self, forKey: .properties) ?? []

        if let stringParentID = try? values.decodeIfPresent(String.self, forKey: .parentId) {
            parentId = stringParentID
        } else if let intParentID = try? values.decodeIfPresent(Int.self, forKey: .parentId) {
            parentId = "\(intParentID)"
        } else if let parent = try? values.decodeIfPresent(JiraCommentParentDTO.self, forKey: .parent) {
            parentId = parent.id
        } else {
            parentId = nil
        }
    }

    var domainValue: IssueComment {
        IssueComment(
            id: id,
            authorName: author?.displayName,
            authorAccountID: author?.accountId,
            bodyText: body?.plainText ?? "",
            createdAt: created,
            updatedAt: updated,
            parentID: parentId
        )
    }

    func parentIDFromProperties(propertyKey: String) -> String? {
        properties.first { $0.key == propertyKey }?.value.parentCommentID
    }
}

private struct JiraCommentParentDTO: Decodable {
    var id: String

    private enum CodingKeys: String, CodingKey {
        case id
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        if let stringID = try? values.decode(String.self, forKey: .id) {
            id = stringID
        } else {
            id = "\(try values.decode(Int.self, forKey: .id))"
        }
    }
}

private struct JiraCommentPropertyDTO: Decodable {
    var key: String
    var value: JiraCommentParentPropertyValueDTO
}

private struct JiraCommentParentPropertyValueDTO: Decodable {
    var parentCommentID: String?

    private enum CodingKeys: String, CodingKey {
        case parentCommentID = "parentCommentId"
        case parentID = "parentId"
    }

    init(from decoder: Decoder) throws {
        if let stringValue = try? decoder.singleValueContainer().decode(String.self) {
            parentCommentID = stringValue
            return
        }

        if let intValue = try? decoder.singleValueContainer().decode(Int.self) {
            parentCommentID = "\(intValue)"
            return
        }

        let values = try decoder.container(keyedBy: CodingKeys.self)
        if let stringParentID = try? values.decodeIfPresent(String.self, forKey: .parentCommentID) {
            parentCommentID = stringParentID
        } else if let intParentID = try? values.decodeIfPresent(Int.self, forKey: .parentCommentID) {
            parentCommentID = "\(intParentID)"
        } else if let stringParentID = try? values.decodeIfPresent(String.self, forKey: .parentID) {
            parentCommentID = stringParentID
        } else if let intParentID = try? values.decodeIfPresent(Int.self, forKey: .parentID) {
            parentCommentID = "\(intParentID)"
        } else {
            parentCommentID = nil
        }
    }
}

private struct JiraDocumentDTO: Decodable {
    var type: String?
    var text: String?
    var attrs: JiraDocumentAttrsDTO?
    var content: [JiraDocumentDTO]?

    var plainText: String {
        normalizedPlainText()
    }

    private func normalizedPlainText() -> String {
        let text = rawPlainText()
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }

        return lines
            .reduce(into: [String]()) { result, line in
                if line.isEmpty, result.last?.isEmpty == true {
                    return
                }
                result.append(line)
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func rawPlainText() -> String {
        switch type {
        case "text":
            return text ?? ""
        case "mention":
            return attrs?.text ?? ""
        case "hardBreak":
            return "\n"
        case "paragraph", "heading":
            return childText() + "\n\n"
        case "bulletList", "orderedList":
            return childText() + "\n"
        case "listItem":
            return "- " + childText().trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
        case "blockquote":
            return childText()
                .components(separatedBy: .newlines)
                .map { $0.isEmpty ? $0 : "> \($0)" }
                .joined(separator: "\n") + "\n"
        default:
            return childText()
        }
    }

    private func childText() -> String {
        content?.map { $0.rawPlainText() }.joined() ?? ""
    }
}

private struct JiraDocumentAttrsDTO: Decodable {
    var text: String?
}

private struct IssueParentDTO: Decodable {
    var id: String
    var key: String
}

private struct IssueSubtaskDTO: Decodable {
    var id: String
    var key: String
}

private struct IssueTypeDTO: Decodable {
    var name: String?
    var subtask: Bool
}

private struct IssueSprintDTO: Decodable {
    var id: Int
    var name: String
    var state: String?
}

private struct IssueSprintInfo {
    var id: Int
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
