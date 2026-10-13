import Foundation
import GRDB

/// Schema de la base. Une migration par version du schema, jamais modifiee
/// une fois publiee : on en ajoute une nouvelle (`v2`, `v3`...).
enum Migrations {
    static var migrator: DatabaseMigrator {
        var m = DatabaseMigrator()
        #if DEBUG
        m.eraseDatabaseOnSchemaChange = true
        #endif

        m.registerMigration("v1") { db in
            try db.create(table: "meta") { t in
                t.primaryKey("key", .text)
                t.column("value", .text).notNull()
            }
            try db.create(table: "clip") { t in
                t.primaryKey("id", .text)
                t.column("kind", .text).notNull()
                t.column("text", .text)
                t.column("imagePath", .text)
                t.column("byteCount", .integer).notNull().defaults(to: 0)
                t.column("contentHash", .text).notNull().unique()
                t.column("sourceApp", .text)
                t.column("createdAt", .datetime).notNull()
                t.column("pinned", .boolean).notNull().defaults(to: false)
                t.column("preview", .text).notNull().defaults(to: "")
                t.column("searchText", .text).notNull().defaults(to: "")
            }
            try db.create(index: "clip_createdAt", on: "clip", columns: ["createdAt"])
        }

        return m
    }
}
