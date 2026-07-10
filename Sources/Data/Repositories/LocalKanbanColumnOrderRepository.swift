import Foundation
import GRDB

final class LocalKanbanColumnOrderRepository: KanbanColumnOrderRepository, @unchecked Sendable {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func columnOrder(projectID: Project.ID) async throws -> [String] {
        try await database.writer.read { db in
            try KanbanColumnOrderRecord
                .filter(Column("projectID") == projectID)
                .order(Column("position").asc)
                .fetchAll(db)
                .map(\.status)
        }
    }

    func saveColumnOrder(projectID: Project.ID, statuses: [String]) async throws {
        try await database.writer.write { db in
            try KanbanColumnOrderRecord
                .filter(Column("projectID") == projectID)
                .deleteAll(db)

            for (position, status) in statuses.enumerated() {
                try KanbanColumnOrderRecord(
                    projectID: projectID,
                    status: status,
                    position: position
                )
                .insert(db)
            }
        }
    }
}
