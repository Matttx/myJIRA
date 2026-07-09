import Foundation
import GRDB

final class AppDatabase: @unchecked Sendable {
    let writer: DatabaseWriter

    init(writer: DatabaseWriter) throws {
        self.writer = writer
        try migrator.migrate(writer)
    }

    static func openDefault() throws -> AppDatabase {
        let fileManager = FileManager.default
        let supportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        .appendingPathComponent("myJIRA", isDirectory: true)

        try fileManager.createDirectory(at: supportURL, withIntermediateDirectories: true)

        let databaseURL = supportURL.appendingPathComponent("myjira.sqlite")
        let queue = try DatabaseQueue(path: databaseURL.path)
        return try AppDatabase(writer: queue)
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("createWorkspaces") { db in
            try db.create(table: WorkspaceRecord.databaseTableName) { table in
                table.column("id", .text).primaryKey()
                table.column("name", .text).notNull()
                table.column("baseURL", .text).notNull()
            }
        }

        migrator.registerMigration("createProjects") { db in
            try db.create(table: ProjectRecord.databaseTableName) { table in
                table.column("id", .text).primaryKey()
                table.column("key", .text).notNull()
                table.column("name", .text).notNull()
                table.column("workspaceID", .text).notNull().indexed().references(WorkspaceRecord.databaseTableName, onDelete: .cascade)
            }
        }

        migrator.registerMigration("createIssues") { db in
            try db.create(table: IssueRecord.databaseTableName) { table in
                table.column("id", .text).primaryKey()
                table.column("key", .text).notNull()
                table.column("projectID", .text).notNull().indexed().references(ProjectRecord.databaseTableName, onDelete: .cascade)
                table.column("summary", .text).notNull()
                table.column("status", .text).notNull()
                table.column("assigneeName", .text)
                table.column("updatedAt", .datetime).notNull()
            }
        }

        migrator.registerMigration("addIssueSprint") { db in
            try db.alter(table: IssueRecord.databaseTableName) { table in
                table.add(column: "sprintName", .text)
            }
        }

        migrator.registerMigration("addIssueSprintState") { db in
            try db.alter(table: IssueRecord.databaseTableName) { table in
                table.add(column: "sprintState", .text)
            }
        }

        return migrator
    }
}
