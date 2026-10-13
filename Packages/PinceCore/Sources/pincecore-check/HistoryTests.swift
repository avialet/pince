import Foundation
import PinceCore

private func store() throws -> ClipStore {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("pince-tests-\(UUID().uuidString)")
    return try ClipStore(database: AppDatabase.inMemory(), imagesDirectory: dir)
}

private let t0 = Date(timeIntervalSince1970: 1_790_000_000)

/// n textes, du plus ancien (0) au plus recent ; renvoie les ids dans cet ordre.
private func fill(_ s: ClipStore, _ n: Int) throws -> [String] {
    try (0..<n).map { try s.record(text: "texte \($0)", sourceApp: nil, now: t0.addingTimeInterval(Double($0)))!.id }
}

let historyTests: (String, [Test]) = ("History", [
    Test("limitDefaultsTo15AndRespectsExplicitChoice") {
        expectEqual(HistoryLimit.defaultValue, 15)
        expectEqual(HistoryLimit.choices, [15, 25, 50, 100, 500, 0])
        expectEqual(HistoryLimit.resolve(stored: nil), 15, "aucun choix : 15")
        expectEqual(HistoryLimit.resolve(stored: 500), 500, "ancien choix explicite garde")
        expectEqual(HistoryLimit.resolve(stored: 2000), 2000, "ancienne valeur hors liste gardee")
        expectEqual(HistoryLimit.resolve(stored: 0), 0, "sans limite")
        expectEqual(HistoryLimit.resolve(stored: -3), 15, "valeur absurde")
        expectEqual(HistoryLimit.resolve(stored: "x"), 15)
    },
    Test("limitChoicesIncludeCurrentNonStandardValue") {
        expectEqual(HistoryLimit.choices(including: 50), [15, 25, 50, 100, 500, 0])
        expectEqual(HistoryLimit.choices(including: 2000), [15, 25, 50, 100, 500, 2000, 0])
        expectEqual(HistoryLimit.choices(including: 10), [10, 15, 25, 50, 100, 500, 0])
    },
    Test("limitLabels") {
        expectEqual(HistoryLimit.label(15), "15 derniers")
        expectEqual(HistoryLimit.label(2000), "2 000 derniers")
        expectEqual(HistoryLimit.label(0), "Tout")
    },
    Test("overflowCountIgnoresPinned") {
        let s = try store()
        let ids = try fill(s, 20)
        try s.setPinned(ids[0], true)
        try s.setPinned(ids[1], true)
        expectEqual(try s.overflowCount(limit: 15), 3, "18 non epingles - 15")
        expectEqual(try s.overflowCount(limit: 50), 0)
        expectEqual(try s.overflowCount(limit: 0), 0, "Tout : rien a supprimer")
        try s.trim(to: 15)
        expectEqual(try s.overflowCount(limit: 15), 0)
        let left = try s.items(matching: nil, kind: nil, limit: 100).map(\.id)
        expectEqual(left.count, 17, "15 + 2 epingles")
        expect(left.contains(ids[0]) && left.contains(ids[1]), "epingles jamais purges")
    },
    Test("deleteManyReturnsUndoableSnapshot") {
        let s = try store()
        let ids = try fill(s, 5)
        try s.setPinned(ids[2], true)
        let removed = try s.delete(ids: [ids[1], ids[2], "inconnu"])
        expectEqual(removed.count, 2)
        expectEqual(try s.items(matching: nil, kind: nil, limit: 10).count, 3)
        try s.restore(removed)
        let back = try s.items(matching: nil, kind: nil, limit: 10)
        expectEqual(back.map(\.id), [ids[4], ids[3], ids[2], ids[1], ids[0]], "restaures a leur place")
        expectEqual(back.first { $0.id == ids[2] }?.pinned, true, "epingle conservee")
    },
    Test("restoreSkipsContentCopiedAgainMeanwhile") {
        let s = try store()
        let ids = try fill(s, 2)
        let removed = try s.delete(ids: [ids[0]])
        _ = try s.record(text: "texte 0", sourceApp: nil, now: t0.addingTimeInterval(100))
        try s.restore(removed)
        expectEqual(try s.items(matching: nil, kind: nil, limit: 10).count, 2, "pas de doublon")
    },
    Test("clearKeepsPinnedAndIsUndoable") {
        let s = try store()
        let ids = try fill(s, 4)
        try s.setPinned(ids[3], true)
        let removed = try s.clear(keepPinned: true)
        expectEqual(removed.count, 3)
        expectEqual(try s.items(matching: nil, kind: nil, limit: 10).map(\.id), [ids[3]])
        try s.restore(removed)
        expectEqual(try s.items(matching: nil, kind: nil, limit: 10).count, 4)
    },
    Test("deleteAndRestoreImageFile") {
        let s = try store()
        let png = Data([0x89, 0x50, 0x4E, 0x47, 9, 8, 7])
        let item = try s.record(imageData: png, sourceApp: nil, now: t0)!
        let url = s.imageURL(for: item)!
        let removed = try s.delete(ids: [item.id])
        expect(!FileManager.default.fileExists(atPath: url.path), "fichier supprime")
        try s.restore(removed)
        expectEqual(try? Data(contentsOf: url), png, "fichier restaure")
    },
])

let selectionTests: (String, [Test]) = ("Selection", [
    Test("plainClickSelectsOne") {
        var sel = ClipSelection()
        sel.click("b", in: ["a", "b", "c"])
        expectEqual(sel.ids, ["b"])
        expectEqual(sel.primary, "b")
    },
    Test("commandClickToggles") {
        var sel = ClipSelection(primary: "a")
        sel.click("c", in: ["a", "b", "c"], toggle: true)
        expectEqual(sel.ids, ["a", "c"])
        expectEqual(sel.primary, "c")
        sel.click("a", in: ["a", "b", "c"], toggle: true)
        expectEqual(sel.ids, ["c"])
        expectEqual(sel.primary, "c")
    },
    Test("shiftClickSelectsRangeFromAnchor") {
        let order = ["a", "b", "c", "d", "e"]
        var sel = ClipSelection(primary: "b")
        sel.click("d", in: order, extend: true)
        expectEqual(sel.ids, ["b", "c", "d"])
        sel.click("a", in: order, extend: true)
        expectEqual(sel.ids, ["a", "b"], "l'ancre reste b")
        expectEqual(sel.primary, "a")
    },
    Test("moveCollapsesToOne") {
        var sel = ClipSelection(primary: "a")
        sel.click("c", in: ["a", "b", "c"], toggle: true)
        sel.select("b")
        expectEqual(sel.ids, ["b"])
    },
    Test("pruneKeepsVisibleAndPicksNextAfterDeletion") {
        let order = ["a", "b", "c", "d"]
        expectEqual(ClipSelection.next(afterDeleting: ["b", "c"], in: order), "d")
        expectEqual(ClipSelection.next(afterDeleting: ["d"], in: order), "c")
        expectEqual(ClipSelection.next(afterDeleting: ["a", "b", "c", "d"], in: order), nil)
        var sel = ClipSelection(primary: "a")
        sel.click("c", in: order, toggle: true)
        sel.prune(to: ["c", "d"])
        expectEqual(sel.ids, ["c"])
        expectEqual(sel.primary, "c")
        sel.prune(to: ["d"])
        expectEqual(sel.primary, "d", "rien de visible : le premier")
    },
])
