import Foundation
import PinceCore
import VialetKit

private func store() throws -> ClipStore {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("pince-tests-\(UUID().uuidString)")
    return try ClipStore(database: AppDatabase.inMemory(), imagesDirectory: dir)
}

private let t0 = Date(timeIntervalSince1970: 1_790_000_000) // 2026-09-21

let storeTests: (String, [Test]) = ("Store", [
    Test("previewIsSingleLineAndShort") {
        let p = ClipItem.preview(for: "  première ligne\n\tdeuxième   ligne  \n" + String(repeating: "x", count: 300))
        expect(!p.contains("\n") && !p.contains("\t"), "pas de retour a la ligne")
        expect(p.hasPrefix("première ligne ⏎ deuxième ligne"), p)
        expect(p.count <= 160, "trop long : \(p.count)")
        expect(p.hasSuffix("…"), "troncature signalee")
    },
    Test("recordTextDetectsKindAndDedupes") {
        let s = try store()
        let a = try s.record(text: "https://vialet.app", sourceApp: "com.apple.Safari", now: t0)!
        expectEqual(a.kind, .url)
        expectEqual(a.sourceApp, "com.apple.Safari")
        _ = try s.record(text: "Bonjour", sourceApp: nil, now: t0.addingTimeInterval(10))
        let again = try s.record(text: "https://vialet.app", sourceApp: nil, now: t0.addingTimeInterval(20))!
        expectEqual(again.id, a.id, "meme contenu, meme entree")
        let all = try s.items(matching: nil, kind: nil, limit: 10)
        expectEqual(all.map(\.text), ["https://vialet.app", "Bonjour"])
        expectEqual(all.first?.createdAt, t0.addingTimeInterval(20), "remonte en tete")
        expect(try s.record(text: "   ", sourceApp: nil, now: t0) == nil, "vide ignore")
    },
    Test("searchIgnoresAccentsAndCaseAndFiltersKind") {
        let s = try store()
        _ = try s.record(text: "Réunion élèves lundi", sourceApp: nil, now: t0)
        _ = try s.record(text: "https://eleves.example.org", sourceApp: nil, now: t0.addingTimeInterval(1))
        expectEqual(try s.items(matching: "ELEVES", kind: nil, limit: 10).count, 2)
        expectEqual(try s.items(matching: "eleves", kind: .url, limit: 10).map(\.kind), [.url])
        expectEqual(try s.items(matching: "introuvable", kind: nil, limit: 10).count, 0)
    },
    Test("pinDeleteClearTrim") {
        let s = try store()
        var ids: [String] = []
        for i in 0..<6 { ids.append(try s.record(text: "texte \(i)", sourceApp: nil, now: t0.addingTimeInterval(Double(i)))!.id) }
        try s.setPinned(ids[0], true)
        expectEqual(try s.items(matching: nil, kind: nil, limit: 10).first { $0.id == ids[0] }?.pinned, true)
        expectEqual(try s.pinned().map(\.id), [ids[0]])
        try s.trim(to: 3)
        let afterTrim = try s.items(matching: nil, kind: nil, limit: 10).map(\.id)
        expectEqual(afterTrim, [ids[5], ids[4], ids[3], ids[0]], "3 recents + l'epingle")
        try s.delete(ids[5])
        expectEqual(try s.items(matching: nil, kind: nil, limit: 10).count, 3)
        try s.clear(keepPinned: true)
        expectEqual(try s.items(matching: nil, kind: nil, limit: 10).map(\.id), [ids[0]])
        try s.clear(keepPinned: false)
        expectEqual(try s.items(matching: nil, kind: nil, limit: 10).count, 0)
    },
    Test("recordFilesKeepsPathsAndPreviewsNames") {
        let s = try store()
        let item = try s.record(files: [URL(fileURLWithPath: "/tmp/a.pdf"), URL(fileURLWithPath: "/tmp/dossier/b.png")], sourceApp: "com.apple.finder", now: t0)
        expectEqual(item?.kind, .files)
        expectEqual(item?.fileURLs.map(\.path), ["/tmp/a.pdf", "/tmp/dossier/b.png"])
        expectEqual(item?.preview, "a.pdf, b.png")
        expect(try s.record(files: [], sourceApp: nil, now: t0) == nil)
    },
    Test("recordImageWritesAndDeleteRemovesFile") {
        let s = try store()
        let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3])
        let item = try s.record(imageData: png, sourceApp: nil, now: t0)!
        expectEqual(item.kind, .image)
        expectEqual(item.byteCount, png.count)
        let url = s.imageURL(for: item)!
        expect(FileManager.default.fileExists(atPath: url.path), "fichier image ecrit")
        let dup = try s.record(imageData: png, sourceApp: nil, now: t0.addingTimeInterval(5))!
        expectEqual(dup.id, item.id, "meme image, meme entree")
        try s.delete(item.id)
        expect(!FileManager.default.fileExists(atPath: url.path), "fichier image supprime")
    },
])
