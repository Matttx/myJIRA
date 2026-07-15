import Foundation

struct IssueTypeMetadata: Identifiable, Hashable, Sendable {
    let id: String
    var name: String
    var isSubtask: Bool
}

struct IssueCreationField: Identifiable, Hashable, Sendable {
    let id: String
    var name: String
    var isRequired: Bool
    var hasDefaultValue: Bool
    var operations: [String]
}

struct IssueCreationMetadata: Hashable, Sendable {
    var fields: [IssueCreationField]

    var unsupportedRequiredFields: [IssueCreationField] {
        fields.filter { field in
            field.isRequired
                && !field.hasDefaultValue
                && !Self.supportedRequiredFieldIDs.contains(field.id)
        }
    }

    private static let supportedRequiredFieldIDs: Set<String> = [
        "project",
        "issuetype",
        "summary",
        "description"
    ]
}

struct IssueCreationDraft: Hashable, Sendable {
    var issueTypeID: String
    var summary: String
    var descriptionText: String?
    var storyPoints: Double?
    var targetSprintID: Int?
    var assignToCurrentUser: Bool
}

struct CreatedIssue: Hashable, Sendable {
    var id: String
    var key: String
}

struct JiraUser: Hashable, Sendable {
    var accountID: String
    var displayName: String
}
