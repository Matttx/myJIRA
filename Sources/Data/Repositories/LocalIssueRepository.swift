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

    func replaceIssues(projectID: Project.ID, issues: [Issue]) async throws {
        try await database.writer.write { db in
            try IssueRecord
                .filter(Column("projectID") == projectID)
                .deleteAll(db)

            for issue in issues {
                try IssueRecord(issue: issue).upsert(db)
            }
        }
    }
}
