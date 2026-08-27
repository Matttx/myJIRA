import Foundation
import GRDB

final class LocalWorkspaceRepository: WorkspaceRepository, @unchecked Sendable {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func workspaces() async throws -> [Workspace] {
        return try await database.writer.read { db in
            let workspaceRecords = try WorkspaceRecord.fetchAll(db)
            let projectRecords = try ProjectRecord.fetchAll(db)

            return workspaceRecords.compactMap { workspaceRecord in
                guard let baseURL = URL(string: workspaceRecord.baseURL) else { return nil }
                let projects = projectRecords
                    .filter { $0.workspaceID == workspaceRecord.id }
                    .map(\.domainValue)

                return Workspace(
                    id: workspaceRecord.id,
                    name: workspaceRecord.name,
                    baseURL: baseURL,
                    projects: projects
                )
            }
        }
    }

    func replace(workspaces: [Workspace]) async throws {
        try await database.writer.write { db in
            try IssueRecord.deleteAll(db)
            try PersonalDataAccountRecord.deleteAll(db)
            try ProjectRecord.deleteAll(db)
            try WorkspaceRecord.deleteAll(db)

            for workspace in workspaces {
                try WorkspaceRecord(workspace: workspace).insert(db)
                for project in workspace.projects {
                    try ProjectRecord(project: project).insert(db)
                }
            }
        }
    }
}
