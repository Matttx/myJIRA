import Foundation
import GRDB

final class LocalPersonalDataRepository: PersonalDataRepository, @unchecked Sendable {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func accountsDueForReporting(at date: Date) async throws -> [PersonalDataAccount] {
        try await database.writer.read { db in
            try PersonalDataAccountRecord
                .filter(Column("nextReportAt") == nil || Column("nextReportAt") <= date)
                .order(Column("oldestRetrievedAt"))
                .fetchAll(db)
                .map {
                    PersonalDataAccount(
                        accountID: $0.accountID,
                        oldestRetrievedAt: $0.oldestRetrievedAt
                    )
                }
        }
    }

    func scheduleNextReport(for accountIDs: Set<String>, at date: Date) async throws {
        guard !accountIDs.isEmpty else { return }

        _ = try await database.writer.write { db in
            try PersonalDataAccountRecord
                .filter(accountIDs.contains(Column("accountID")))
                .updateAll(db, Column("nextReportAt").set(to: date))
        }
    }

    func erasePersonalData(for accountIDs: Set<String>) async throws {
        guard !accountIDs.isEmpty else { return }

        try await database.writer.write { db in
            let issueIDs = try String.fetchAll(
                db,
                PersonalDataReferenceRecord
                    .select(Column("issueID"), as: String.self)
                    .filter(accountIDs.contains(Column("accountID")))
                    .distinct()
            )

            for issueID in issueIDs {
                guard let record = try IssueRecord.fetchOne(db, key: issueID) else { continue }
                var issue = record.domainValue

                if let accountID = issue.reporterAccountID, accountIDs.contains(accountID) {
                    issue.reporterName = nil
                    issue.reporterAccountID = nil
                }

                if let accountID = issue.assigneeAccountID, accountIDs.contains(accountID) {
                    issue.assigneeName = nil
                    issue.assigneeAccountID = nil
                }

                for index in issue.comments.indices {
                    guard let accountID = issue.comments[index].authorAccountID,
                          accountIDs.contains(accountID)
                    else { continue }
                    issue.comments[index].authorName = nil
                    issue.comments[index].authorAccountID = nil
                }

                for index in issue.changes.indices {
                    guard let accountID = issue.changes[index].authorAccountID,
                          accountIDs.contains(accountID)
                    else { continue }
                    issue.changes[index].authorName = nil
                    issue.changes[index].authorAccountID = nil
                }

                try IssueRecord(issue: issue).update(db)
            }

            try PersonalDataAccountRecord
                .filter(accountIDs.contains(Column("accountID")))
                .deleteAll(db)
        }
    }
}
