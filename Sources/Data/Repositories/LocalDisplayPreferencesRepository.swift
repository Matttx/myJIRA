import Foundation
import GRDB

final class LocalDisplayPreferencesRepository: DisplayPreferencesRepository, @unchecked Sendable {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func projectOrder(workspaceID: Workspace.ID) async throws -> [Project.ID] {
        try await database.writer.read { db in
            try ProjectDisplayOrderRecord
                .filter(Column("workspaceID") == workspaceID)
                .order(Column("position").asc)
                .fetchAll(db)
                .map(\.projectID)
        }
    }

    func saveProjectOrder(workspaceID: Workspace.ID, projectIDs: [Project.ID]) async throws {
        try await database.writer.write { db in
            try ProjectDisplayOrderRecord
                .filter(Column("workspaceID") == workspaceID)
                .deleteAll(db)

            for (position, projectID) in projectIDs.enumerated() {
                try ProjectDisplayOrderRecord(
                    workspaceID: workspaceID,
                    projectID: projectID,
                    position: position
                )
                .insert(db)
            }
        }
    }

    func backlogSprintOrder(projectID: Project.ID) async throws -> [String] {
        try await database.writer.read { db in
            try BacklogSprintOrderRecord
                .filter(Column("projectID") == projectID)
                .order(Column("position").asc)
                .fetchAll(db)
                .map(\.groupID)
        }
    }

    func saveBacklogSprintOrder(projectID: Project.ID, groupIDs: [String]) async throws {
        try await database.writer.write { db in
            try BacklogSprintOrderRecord
                .filter(Column("projectID") == projectID)
                .deleteAll(db)

            for (position, groupID) in groupIDs.enumerated() {
                try BacklogSprintOrderRecord(
                    projectID: projectID,
                    groupID: groupID,
                    position: position
                )
                .insert(db)
            }
        }
    }

    func collapsedBacklogGroupIDs(projectID: Project.ID) async throws -> Set<String> {
        try await database.writer.read { db in
            let groupIDs = try BacklogCollapsedGroupRecord
                .filter(Column("projectID") == projectID)
                .fetchAll(db)
                .map(\.groupID)

            return Set(groupIDs)
        }
    }

    func saveCollapsedBacklogGroupIDs(projectID: Project.ID, groupIDs: Set<String>) async throws {
        try await database.writer.write { db in
            try BacklogCollapsedGroupRecord
                .filter(Column("projectID") == projectID)
                .deleteAll(db)

            for groupID in groupIDs {
                try BacklogCollapsedGroupRecord(
                    projectID: projectID,
                    groupID: groupID
                )
                .insert(db)
            }
        }
    }

    func selectedSprintFilter(projectID: Project.ID) async throws -> SprintFilter {
        try await database.writer.read { db in
            let record = try BacklogSelectedSprintFilterRecord.fetchOne(db, key: projectID)
            return SprintFilter.saved(id: record?.filterID)
        }
    }

    func saveSelectedSprintFilter(projectID: Project.ID, filter: SprintFilter) async throws {
        try await database.writer.write { db in
            try BacklogSelectedSprintFilterRecord(
                projectID: projectID,
                filterID: filter.id
            )
            .upsert(db)
        }
    }
}
