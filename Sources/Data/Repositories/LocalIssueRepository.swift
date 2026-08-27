import Foundation
import GRDB

final class LocalIssueRepository: IssueRepository, @unchecked Sendable {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
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

    func upsertIssue(_ issue: Issue) async throws {
        try await database.writer.write { db in
            try IssueRecord(issue: issue).upsert(db)
            try replacePersonalDataReferences(for: issue, db: db)
        }
    }

    func deleteIssue(issueID: Issue.ID) async throws {
        _ = try await database.writer.write { db in
            let deletedCount = try IssueRecord
                .filter(Column("id") == issueID)
                .deleteAll(db)
            try removeOrphanedPersonalDataAccounts(db: db)
            return deletedCount
        }
    }

    func replaceIssues(projectID: Project.ID, issues: [Issue]) async throws {
        try await database.writer.write { db in
            let existingRecords = try IssueRecord
                .filter(Column("projectID") == projectID)
                .fetchAll(db)
            let existingChangesByID = Dictionary(uniqueKeysWithValues: existingRecords.map { ($0.id, $0.domainValue.changes) })

            try IssueRecord
                .filter(Column("projectID") == projectID)
                .deleteAll(db)

            for issue in issues {
                var nextIssue = issue
                if nextIssue.changes.isEmpty, let existingChanges = existingChangesByID[issue.id] {
                    nextIssue.changes = existingChanges
                }

                try IssueRecord(issue: nextIssue).upsert(db)
                try replacePersonalDataReferences(
                    for: nextIssue,
                    cleanupOrphans: false,
                    db: db
                )
            }
            try removeOrphanedPersonalDataAccounts(db: db)
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

    func updateAssignee(issueID: Issue.ID, assigneeName: String?, assigneeAccountID: String?) async throws {
        _ = try await database.writer.write { db in
            try IssueRecord
                .filter(Column("id") == issueID)
                .updateAll(db, [
                    Column("assigneeName").set(to: assigneeName),
                    Column("assigneeAccountID").set(to: assigneeAccountID),
                    Column("updatedAt").set(to: Date())
                ])
            try refreshPersonalDataReferences(issueID: issueID, db: db)
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
            try refreshPersonalDataReferences(issueID: issueID, db: db)
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
            try refreshPersonalDataReferences(issueID: issueID, db: db)
        }
    }

    private func refreshPersonalDataReferences(
        issueID: Issue.ID,
        db: Database
    ) throws {
        guard let issue = try IssueRecord.fetchOne(db, key: issueID)?.domainValue else { return }
        try replacePersonalDataReferences(for: issue, db: db)
    }

    private func replacePersonalDataReferences(
        for issue: Issue,
        cleanupOrphans: Bool = true,
        db: Database
    ) throws {
        try PersonalDataReferenceRecord
            .filter(Column("issueID") == issue.id)
            .deleteAll(db)

        let now = Date.now
        for accountID in issue.personalDataAccountIDs {
            try PersonalDataAccountRecord(
                accountID: accountID,
                oldestRetrievedAt: now,
                nextReportAt: nil
            ).insert(db, onConflict: .ignore)
            try PersonalDataReferenceRecord(accountID: accountID, issueID: issue.id).insert(db)
        }

        if cleanupOrphans {
            try removeOrphanedPersonalDataAccounts(db: db)
        }
    }

    private func removeOrphanedPersonalDataAccounts(db: Database) throws {
        try db.execute(sql: """
            DELETE FROM \(PersonalDataAccountRecord.databaseTableName)
            WHERE accountID NOT IN (
                SELECT DISTINCT accountID FROM \(PersonalDataReferenceRecord.databaseTableName)
            )
            """)
    }
}
