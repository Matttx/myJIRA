import Foundation
import GRDB

final class LocalIssueRepository: IssueRepository, @unchecked Sendable {
    private let database: AppDatabase
    private let seedDataProvider: SeedDataProvider

    init(database: AppDatabase, seedDataProvider: SeedDataProvider) {
        self.database = database
        self.seedDataProvider = seedDataProvider
    }

    func issues(projectID: Project.ID) async throws -> [Issue] {
        return try await database.writer.read { db in
            try IssueRecord
                .filter(Column("projectID") == projectID)
                .order(Column("updatedAt").desc)
                .fetchAll(db)
                .map(\.domainValue)
        }
    }

    func issue(id: Issue.ID) async throws -> Issue? {
        try await database.writer.read { db in
            try IssueRecord.fetchOne(db, key: id)?.domainValue
        }
    }

    func refreshIssues(projectID: Project.ID) async throws {
        try await seedDataProvider.populate(database: database)
    }

    func upsertIssue(_ issue: Issue) async throws {
        try await database.writer.write { db in
            try IssueRecord(issue: issue).upsert(db)
        }
    }

    func deleteIssue(issueID: Issue.ID) async throws {
        _ = try await database.writer.write { db in
            try IssueRecord
                .filter(Column("id") == issueID)
                .deleteAll(db)
        }
    }

    func replaceIssues(projectID: Project.ID, issues: [Issue]) async throws {
        try await database.writer.write { db in
            let existingChangesByID = try IssueRecord
                .filter(Column("projectID") == projectID)
                .fetchAll(db)
                .reduce(into: [Issue.ID: [IssueChange]]()) { result, record in
                    result[record.id] = record.domainValue.changes
                }

            try IssueRecord
                .filter(Column("projectID") == projectID)
                .deleteAll(db)

            for issue in issues {
                var nextIssue = issue
                if nextIssue.changes.isEmpty, let existingChanges = existingChangesByID[issue.id] {
                    nextIssue.changes = existingChanges
                }

                try IssueRecord(issue: nextIssue).upsert(db)
            }
        }
    }

    func updateStatus(issueID: Issue.ID, status: String) async throws {
        _ = try await database.writer.write { db in
            try IssueRecord
                .filter(Column("id") == issueID)
                .updateAll(db, [
                    Column("status").set(to: status),
                    Column("updatedAt").set(to: Date())
                ])
        }
    }

    func updateAssignee(issueID: Issue.ID, assigneeName: String?) async throws {
        _ = try await database.writer.write { db in
            try IssueRecord
                .filter(Column("id") == issueID)
                .updateAll(db, [
                    Column("assigneeName").set(to: assigneeName),
                    Column("updatedAt").set(to: Date())
                ])
        }
    }

    func updateSprint(issueID: Issue.ID, sprintID: Int?, sprintName: String?, sprintState: String?) async throws {
        _ = try await database.writer.write { db in
            try IssueRecord
                .filter(Column("id") == issueID)
                .updateAll(db, [
                    Column("sprintID").set(to: sprintID),
                    Column("sprintName").set(to: sprintName),
                    Column("sprintState").set(to: sprintState),
                    Column("updatedAt").set(to: Date())
                ])
        }
    }

    func updateStoryPoints(issueID: Issue.ID, storyPoints: Double?) async throws {
        _ = try await database.writer.write { db in
            try IssueRecord
                .filter(Column("id") == issueID)
                .updateAll(db, [
                    Column("storyPoints").set(to: storyPoints),
                    Column("updatedAt").set(to: Date())
                ])
        }
    }

    func updateSummary(issueID: Issue.ID, summary: String) async throws {
        _ = try await database.writer.write { db in
            try IssueRecord
                .filter(Column("id") == issueID)
                .updateAll(db, [
                    Column("summary").set(to: summary),
                    Column("updatedAt").set(to: Date())
                ])
        }
    }

    func updateDescription(issueID: Issue.ID, descriptionText: String?) async throws {
        _ = try await database.writer.write { db in
            try IssueRecord
                .filter(Column("id") == issueID)
                .updateAll(db, [
                    Column("descriptionText").set(to: descriptionText),
                    Column("updatedAt").set(to: Date())
                ])
        }
    }

    func updateComments(issueID: Issue.ID, comments: [IssueComment]) async throws {
        let encoder = JSONEncoder()
        let commentsJSON = String(data: try encoder.encode(comments), encoding: .utf8) ?? "[]"

        _ = try await database.writer.write { db in
            try IssueRecord
                .filter(Column("id") == issueID)
                .updateAll(db, [
                    Column("commentsJSON").set(to: commentsJSON),
                    Column("updatedAt").set(to: Date())
                ])
        }
    }

    func updateChanges(issueID: Issue.ID, changes: [IssueChange]) async throws {
        let encoder = JSONEncoder()
        let changesJSON = String(data: try encoder.encode(changes), encoding: .utf8) ?? "[]"

        _ = try await database.writer.write { db in
            try IssueRecord
                .filter(Column("id") == issueID)
                .updateAll(db, [
                    Column("changesJSON").set(to: changesJSON)
                ])
        }
    }
}
