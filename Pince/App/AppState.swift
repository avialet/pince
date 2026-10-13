import AppKit
import SwiftUI
import Observation
import PinceCore
import VialetKit

/// Filtre de la liste.
enum ClipFilter: Hashable {
    case all, pinned, kind(ContentKind)

    var label: String {
        switch self {
        case .all: "Tout"
        case .pinned: "Épinglés"
        case .kind(let k): k.label
        }
    }

    var icon: String {
        switch self {
        case .all: "clock"
        case .pinned: "pin"
        case .kind(let k): k.icon
        }
    }

    static let sidebar: [ClipFilter] = [.all, .pinned] + [.text, .url, .image, .files, .color, .code, .json, .email, .path, .number].map(ClipFilter.kind)
}

/// Etat partage : l'historique, la recherche, le panneau, les reglages.
@MainActor
@Observable
final class AppState {
    static let shared = AppState()
    static let panelSize = CGSize(width: 680, height: 460)

    let database: AppDatabase
    let store: ClipStore
    private let watcher = PasteboardWatcher()

    private(set) var items: [ClipItem] = []
    var query = "" { didSet { reload() } }
    var filter: ClipFilter = .all { didSet { reload() } }
    var selectedId: String?
    /// Incremente a chaque ouverture du panneau : la vue redonne le focus au champ.
    private(set) var panelOpenCount = 0
    private(set) var panel: FloatingPanelController<AnyView>?

    // Reglages
    var historyLimit: Int {
        didSet { UserDefaults.standard.set(historyLimit, forKey: Brand.key("HistoryLimit")); try? store.trim(to: historyLimit); reload() }
    }
    var directPaste: Bool {
        didSet { UserDefaults.standard.set(directPaste, forKey: Brand.key("DirectPaste")) }
    }
    var excludedApps: String {
        didSet { UserDefaults.standard.set(excludedApps, forKey: Brand.key("ExcludedApps")); watcher.excludedApps = Self.parseApps(excludedApps) }
    }

    private init() {
        do {
            database = try AppDatabase.open()
            store = try ClipStore(database: database, imagesDirectory: AppDatabase.defaultURL.deletingLastPathComponent().appendingPathComponent("images", isDirectory: true))
        } catch {
            fatalError("Impossible d'ouvrir la base \(AppDatabase.defaultURL.path) : \(error)")
        }
        let defaults = UserDefaults.standard
        historyLimit = defaults.object(forKey: Brand.key("HistoryLimit")) as? Int ?? 500
        directPaste = defaults.bool(forKey: Brand.key("DirectPaste"))
        excludedApps = defaults.string(forKey: Brand.key("ExcludedApps")) ?? ""
        watcher.excludedApps = Self.parseApps(excludedApps)
        watcher.onCapture = { [weak self] capture, source in self?.capture(capture, from: source) }
        reload()
    }

    private static func parseApps(_ text: String) -> Set<String> {
        Set(text.split(whereSeparator: { $0 == "," || $0 == " " || $0.isNewline }).map { String($0) }.filter { !$0.isEmpty })
    }

    func start() {
        watcher.start()
    }

    // MARK: Historique

    private func capture(_ capture: PasteboardWatcher.Capture, from source: String?) {
        do {
            switch capture {
            case .text(let text): try store.record(text: text, sourceApp: source)
            case .files(let urls): try store.record(files: urls, sourceApp: source)
            case .image(let data): try store.record(imageData: data, sourceApp: source)
            }
            if historyLimit > 0 { try store.trim(to: historyLimit) }
        } catch {
            NSLog("Pince : enregistrement impossible : \(error)")
        }
        reload()
    }

    func reload() {
        do {
            switch filter {
            case .all: items = try store.items(matching: query, kind: nil)
            case .pinned: items = try store.items(matching: query, kind: nil).filter(\.pinned)
            case .kind(let k): items = try store.items(matching: query, kind: k)
            }
        } catch {
            NSLog("Pince : lecture impossible : \(error)")
            items = []
        }
        if let selectedId, !items.contains(where: { $0.id == selectedId }) { self.selectedId = items.first?.id }
        if selectedId == nil { selectedId = items.first?.id }
    }

    var pinnedItems: [ClipItem] { items.filter(\.pinned) }
    var unpinnedItems: [ClipItem] { items.filter { !$0.pinned } }

    /// Sections : « Épinglés », puis par anciennete.
    var sections: [(title: String, items: [ClipItem])] {
        var out: [(String, [ClipItem])] = []
        if filter != .pinned, !pinnedItems.isEmpty { out.append(("Épinglés", pinnedItems)) }
        let now = Date()
        var current: String?
        var bucket: [ClipItem] = []
        for item in (filter == .pinned ? items : unpinnedItems) {
            let label = TimeBucket.bucket(for: item.createdAt, now: now).sectionLabel
            if label != current {
                if let current, !bucket.isEmpty { out.append((current, bucket)) }
                current = label; bucket = []
            }
            bucket.append(item)
        }
        if let current, !bucket.isEmpty { out.append((current, bucket)) }
        return out
    }

    func imageURL(for item: ClipItem) -> URL? { store.imageURL(for: item) }

    func togglePin(_ item: ClipItem) {
        try? store.setPinned(item.id, !item.pinned)
        reload()
    }

    func delete(_ item: ClipItem) {
        try? store.delete(item.id)
        reload()
    }

    func clearHistory(keepPinned: Bool) {
        try? store.clear(keepPinned: keepPinned)
        reload()
    }

    /// Remet l'element dans le presse-papiers ; colle directement si l'option est active et autorisee.
    func use(_ item: ClipItem) {
        watcher.write(item, imageURL: imageURL(for: item))
        // Remonte l'element en tete : meme contenu, meme entree, date mise a jour.
        switch item.kind {
        case .files: _ = try? store.record(files: item.fileURLs, sourceApp: nil)
        case .image: break
        default: if let text = item.text { _ = try? store.record(text: text, sourceApp: nil) }
        }
        hidePanel()
        if directPaste, Paster.isTrusted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { Paster.simulatePaste() }
        }
        reload()
    }

    // MARK: Selection clavier

    func moveSelection(by delta: Int) {
        let ordered = sections.flatMap(\.items)
        guard !ordered.isEmpty else { return }
        let index = ordered.firstIndex { $0.id == selectedId } ?? 0
        let next = min(max(0, index + delta), ordered.count - 1)
        selectedId = ordered[next].id
    }

    var selectedItem: ClipItem? { items.first { $0.id == selectedId } }

    // MARK: Panneau

    func togglePanel() {
        let panel = self.panel ?? FloatingPanelController(size: Self.panelSize) { AnyView(PanelView().environment(AppState.shared)) }
        self.panel = panel
        if panel.isVisible {
            panel.hide()
        } else {
            query = ""
            selectedId = items.first?.id
            panelOpenCount += 1
            panel.show()
        }
    }

    func hidePanel() { panel?.hide() }
}
