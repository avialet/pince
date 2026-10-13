import CryptoKit
import Foundation
import GRDB
import VialetKit

/// Historique du presse-papiers : texte et metadonnees en SQLite, images en PNG
/// dans un dossier a cote. Une meme copie remonte en tete au lieu de se dupliquer.
public final class ClipStore: Sendable {
    public let database: AppDatabase
    public let imagesDirectory: URL

    public init(database: AppDatabase, imagesDirectory: URL) throws {
        self.database = database
        self.imagesDirectory = imagesDirectory
        try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
    }

    // MARK: Enregistrement

    @discardableResult
    public func record(text: String, sourceApp: String?, now: Date = Date()) throws -> ClipItem? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let kind = ContentDetector.detect(text)
        return try upsert(kind: kind, text: text, imageData: nil, byteCount: text.utf8.count,
                          hash: Self.hash(kind.rawValue, Data(text.utf8)), sourceApp: sourceApp, now: now,
                          preview: ClipItem.preview(for: text))
    }

    @discardableResult
    public func record(files: [URL], sourceApp: String?, now: Date = Date()) throws -> ClipItem? {
        guard !files.isEmpty else { return nil }
        let text = files.map(\.path).joined(separator: "\n")
        return try upsert(kind: .files, text: text, imageData: nil, byteCount: text.utf8.count,
                          hash: Self.hash("files", Data(text.utf8)), sourceApp: sourceApp, now: now,
                          preview: files.map(\.lastPathComponent).joined(separator: ", "))
    }

    @discardableResult
    public func record(imageData: Data, sourceApp: String?, now: Date = Date()) throws -> ClipItem? {
        guard !imageData.isEmpty else { return nil }
        return try upsert(kind: .image, text: nil, imageData: imageData, byteCount: imageData.count,
                          hash: Self.hash("image", imageData), sourceApp: sourceApp, now: now,
                          preview: "Image")
    }

    private func upsert(kind: ContentKind, text: String?, imageData: Data?, byteCount: Int, hash: String,
                        sourceApp: String?, now: Date, preview: String) throws -> ClipItem {
        try database.write { db in
            if var existing = try ClipItem.filter(Column("contentHash") == hash).fetchOne(db) {
                existing.createdAt = now
                if let sourceApp { existing.sourceApp = sourceApp }
                try existing.update(db)
                return existing
            }
            let id = UUID().uuidString.lowercased()
            var imagePath: String?
            if let imageData {
                imagePath = "\(id).png"
                try imageData.write(to: imagesDirectory.appendingPathComponent(imagePath!))
            }
            let item = ClipItem(id: id, kind: kind, text: text, imagePath: imagePath, byteCount: byteCount,
                                contentHash: hash, sourceApp: sourceApp, createdAt: now, pinned: false,
                                preview: preview, searchText: SearchNormalizer.normalize(text ?? preview))
            try item.insert(db)
            return item
        }
    }

    // MARK: Lecture

    /// Du plus recent au plus ancien. `query` : sous-chaine, sans distinction d'accents ni de casse.
    public func items(matching query: String?, kind: ContentKind?, limit: Int = 500) throws -> [ClipItem] {
        let needle = query.map(SearchNormalizer.normalize)?.trimmingCharacters(in: .whitespaces) ?? ""
        return try database.read { db in
            var request = ClipItem.order(Column("createdAt").desc)
            if let kind { request = request.filter(Column("kind") == kind.rawValue) }
            if !needle.isEmpty { request = request.filter(Column("searchText").like("%\(Self.escapeLike(needle))%", escape: "\\")) }
            return try request.limit(limit).fetchAll(db)
        }
    }

    public func pinned() throws -> [ClipItem] {
        try database.read { db in try ClipItem.filter(Column("pinned") == true).order(Column("createdAt").desc).fetchAll(db) }
    }

    public func item(_ id: String) throws -> ClipItem? {
        try database.read { db in try ClipItem.fetchOne(db, key: id) }
    }

    public func imageURL(for item: ClipItem) -> URL? {
        item.imagePath.map { imagesDirectory.appendingPathComponent($0) }
    }

    private static func escapeLike(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "%", with: "\\%").replacingOccurrences(of: "_", with: "\\_")
    }

    // MARK: Ecriture

    public func setPinned(_ id: String, _ pinned: Bool) throws {
        try database.write { db in
            try db.execute(sql: "UPDATE clip SET pinned = ? WHERE id = ?", arguments: [pinned, id])
        }
    }

    public func delete(_ id: String) throws {
        try delete(ids: [id])
    }

    /// Supprime ces elements (ids inconnus ignores) ; le resultat permet de les restaurer.
    @discardableResult
    public func delete(ids: Set<String>, now: Date = Date()) throws -> DeletedClips {
        let ids = Array(ids)
        return try remove(now: now) { db in try ClipItem.filter(keys: ids).fetchAll(db) }
    }

    /// Vide l'historique ; les epingles survivent si demande. Le resultat permet de restaurer.
    @discardableResult
    public func clear(keepPinned: Bool) throws -> DeletedClips {
        try remove(now: Date()) { db in keepPinned ? try ClipItem.filter(Column("pinned") == false).fetchAll(db) : try ClipItem.fetchAll(db) }
    }

    /// Remet des elements supprimes (et leurs images). Un contenu copie a nouveau entre-temps
    /// n'est pas duplique. Renvoie les ids reellement restaures.
    @discardableResult
    public func restore(_ deleted: DeletedClips) throws -> [String] {
        let restored: [ClipItem] = try database.write { db in
            var done: [ClipItem] = []
            for item in deleted.items where try ClipItem.filter(Column("contentHash") == item.contentHash).fetchCount(db) == 0
                && ClipItem.fetchOne(db, key: item.id) == nil {
                try item.insert(db)
                done.append(item)
            }
            return done
        }
        for item in restored {
            if let data = deleted.images[item.id], let url = imageURL(for: item) { try? data.write(to: url) }
        }
        return restored.map(\.id)
    }

    /// Nombre d'elements non epingles qu'une limite `limit` supprimerait (0 : sans limite).
    public func overflowCount(limit: Int) throws -> Int {
        guard limit > 0 else { return 0 }
        let count = try database.read { db in try ClipItem.filter(Column("pinned") == false).fetchCount(db) }
        return max(0, count - limit)
    }

    private func remove(now: Date, _ victims: @escaping @Sendable (Database) throws -> [ClipItem]) throws -> DeletedClips {
        let removed: [ClipItem] = try database.write { db in
            let items = try victims(db)
            for v in items { try v.delete(db) }
            return items
        }
        var images: [String: Data] = [:]
        for item in removed {
            if let url = imageURL(for: item), let data = try? Data(contentsOf: url) { images[item.id] = data }
            removeImage(of: item)
        }
        return DeletedClips(items: removed, images: images, date: now)
    }

    /// Garde les `max` entrees non epinglees les plus recentes (les epingles ne comptent pas).
    /// `max <= 0` signifie « sans limite » : ne supprime rien. Le resultat permet de restaurer.
    @discardableResult
    public func trim(to max: Int, now: Date = Date()) throws -> DeletedClips {
        guard max > 0 else { return DeletedClips(items: [], images: [:], date: now) }
        return try remove(now: now) { db in
            try ClipItem.filter(Column("pinned") == false).order(Column("createdAt").desc)
                .limit(1_000_000, offset: max).fetchAll(db)
        }
    }

    private func removeImage(of item: ClipItem) {
        if let url = imageURL(for: item) { try? FileManager.default.removeItem(at: url) }
    }

    private static func hash(_ kind: String, _ data: Data) -> String {
        var h = SHA256()
        h.update(data: Data(kind.utf8))
        h.update(data: Data([0]))
        h.update(data: data)
        return h.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

/// Elements supprimes, gardes en memoire pour « Annuler ».
public struct DeletedClips: Sendable {
    public let items: [ClipItem]
    let images: [String: Data]
    /// Moment de la suppression : « Annuler » vaut `undoLifetime` secondes.
    public let date: Date
    public static let undoLifetime: TimeInterval = 60
    public var count: Int { items.count }
    public func isUndoable(at now: Date) -> Bool { now.timeIntervalSince(date) < Self.undoLifetime }
    public var isEmpty: Bool { items.isEmpty }
}
