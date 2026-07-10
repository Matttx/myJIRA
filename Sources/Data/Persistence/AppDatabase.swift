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

        migrator.registerMigration("addIssueHierarchy") { db in
            try db.alter(table: IssueRecord.databaseTableName) { table in
                table.add(column: "parentID", .text)
                table.add(column: "parentKey", .text)
                table.add(column: "isSubtask", .boolean).notNull().defaults(to: false)
                table.add(column: "subtaskIDsJSON", .text).notNull().defaults(to: "[]")
            }
        }

        migrator.registerMigration("addIssueStatusCategory") { db in
            try db.alter(table: IssueRecord.databaseTableName) { table in
                table.add(column: "statusCategoryKey", .text)
            }
        }

        migrator.registerMigration("addIssueDetailFields") { db in
            try db.alter(table: IssueRecord.databaseTableName) { table in
                table.add(column: "descriptionText", .text)
                table.add(column: "commentsJSON", .text).notNull().defaults(to: "[]")
                table.add(column: "issueTypeName", .text)
                table.add(column: "priorityName", .text)
                table.add(column: "reporterName", .text)
                table.add(column: "labelsJSON", .text).notNull().defaults(to: "[]")
                table.add(column: "createdAt", .datetime)
            }
        }

        migrator.registerMigration("addIssueChangelog") { db in
            try db.alter(table: IssueRecord.databaseTableName) { table in
                table.add(column: "changesJSON", .text).notNull().defaults(to: "[]")
            }
        }

        migrator.registerMigration("addIssueSprintID") { db in
            try db.alter(table: IssueRecord.databaseTableName) { table in
                table.add(column: "sprintID", .integer)
            }
        }

        migrator.registerMigration("addIssueStoryPoints") { db in
            try db.alter(table: IssueRecord.databaseTableName) { table in
                table.add(column: "storyPoints", .double)
            }
        }

        migrator.registerMigration("addIssueStoryPointsFieldID") { db in
            try db.alter(table: IssueRecord.databaseTableName) { table in
                table.add(column: "storyPointsFieldID", .text)
            }
        }

        migrator.registerMigration("createKanbanColumnOrders") { db in
            try db.create(table: KanbanColumnOrderRecord.databaseTableName) { table in
                table.column("projectID", .text).notNull().references(ProjectRecord.databaseTableName, onDelete: .cascade)
                table.column("status", .text).notNull()
                table.column("position", .integer).notNull()
                table.primaryKey(["projectID", "status"])
            }
        }

        return migrator
    }
}
