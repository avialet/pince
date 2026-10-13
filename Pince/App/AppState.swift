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
    /// Fenetre du panneau : carte de 648 x 436 et marge de `PanelView.margin` pour son ombre.
    static let panelSize = CGSize(width: 712, height: 500)

    let database: AppDatabase
    let store: ClipStore
    private let watcher = PasteboardWatcher()

    private(set) var items: [ClipItem] = []
    var query = "" { didSet { reload() } }
    var filter: ClipFilter = .all { didSet { reload() } }
    /// Selection : un element principal et, dans la fenetre, plusieurs par ⇧-clic et ⌘-clic.
    private(set) var selection = ClipSelection()
    var selectedId: String? {
        get { selection.primary }
        set { selection.select(newValue) }
    }
    /// Derniere suppression, pour ⌘Z et le bandeau « Annuler » : oubliee apres
    /// `DeletedClips.undoLifetime` (60 s).
    private(set) var lastDeletion: DeletedClips?
    private(set) var deletionNotice: DeletionNotice?
    private var noticeTask: Task<Void, Never>?
    private var expiryTask: Task<Void, Never>?
    /// Premiere purge apres la mise a jour (limite jamais choisie, 15 par defaut) : annulable.
    private var firstPurgePending: Bool
    /// Limite demandee qui supprimerait des elements : en attente de confirmation.
    var pendingLimit: PendingLimit?
    #if DEBUG
    /// Mode capture : ligne affichee comme survolee.
    var snapshotHoverId: String?
    #endif
    /// Incremente a chaque ouverture du panneau : la vue redonne le focus au champ.
    private(set) var panelOpenCount = 0
    private(set) var panel: FloatingPanelController<AnyView>?

    // Reglages
    /// Elements non epingles gardes (0 : tous). Les epingles ne comptent pas et ne sont jamais purges.
    private(set) var historyLimit: Int
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
        historyLimit = HistoryLimit.resolve(stored: defaults.object(forKey: Brand.key("HistoryLimit")))
        firstPurgePending = defaults.object(forKey: Brand.key("HistoryLimit")) == nil
            && !defaults.bool(forKey: Brand.key("FirstPurgeDone"))
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
            let purged = try store.trim(to: historyLimit)
            if firstPurgePending {
                firstPurgePending = false
                UserDefaults.standard.set(true, forKey: Brand.key("FirstPurgeDone"))
                remember(purged, notice: .purged(purged.count))
            }
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
        selection.prune(to: orderedIds)
    }

    /// Ids dans l'ordre affiche (sections comprises).
    var orderedIds: [String] { sections.flatMap(\.items).map(\.id) }

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

    /// Elements vises par une action sur `item` : toute la selection s'il en fait partie.
    func targets(of item: ClipItem) -> Set<String> {
        selection.ids.contains(item.id) && selection.ids.count > 1 ? selection.ids : [item.id]
    }

    func delete(_ item: ClipItem) { delete(ids: targets(of: item)) }

    func deleteSelection() { delete(ids: selection.ids) }

    func delete(ids: Set<String>) {
        guard !ids.isEmpty else { return }
        let next = ClipSelection.next(afterDeleting: ids, in: orderedIds)
        let deleted = try? store.delete(ids: ids)
        remember(deleted, notice: .deleted(deleted?.count ?? 0))
        reload()
        selection.select(next)
    }

    /// « Tout effacer » : les epingles restent ; annulable.
    func clearHistory(keepPinned: Bool) {
        let deleted = try? store.clear(keepPinned: keepPinned)
        remember(deleted, notice: .deleted(deleted?.count ?? 0))
        reload()
    }

    var canUndoDeletion: Bool { lastDeletion?.isUndoable(at: Date()) == true }

    func undoDeletion() {
        guard let deleted = lastDeletion, deleted.isUndoable(at: Date()) else { return }
        let restored = (try? store.restore(deleted)) ?? []
        lastDeletion = nil
        expiryTask?.cancel()
        reload()
        selection.select(all: restored, in: orderedIds)
        if restored.count < deleted.count {
            show(.partial(restored: restored.count, skipped: deleted.count - restored.count))
        } else {
            hideNotice()
        }
    }

    /// ⌘Z du menu : la saisie d'abord (editeur de texte qui peut annuler) ; puis la derniere
    /// suppression, seulement depuis la fenetre ou le panneau ; sinon `undo:` standard (Reglages).
    func undoCommand() {
        if !Self.textCanUndo, canUndoDeletion, Self.listWindowIsKey {
            undoDeletion()
        } else {
            NSApp.sendAction(Selector(("undo:")), to: nil, from: nil)
        }
    }

    /// Le premier repondeur est un editeur de texte qui a quelque chose a annuler.
    static var textCanUndo: Bool {
        (NSApp.keyWindow?.firstResponder as? NSTextView)?.undoManager?.canUndo == true
    }

    private static var listWindowIsKey: Bool {
        guard let window = NSApp.keyWindow else { return false }
        return window === WindowSummoner.mainWindow || window is FloatingPanel
    }

    func hideNotice() {
        noticeTask?.cancel()
        deletionNotice = nil
    }

    private func remember(_ deleted: DeletedClips?, notice: DeletionNotice) {
        guard let deleted, !deleted.isEmpty else { return }
        lastDeletion = deleted
        expiryTask?.cancel()
        expiryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(DeletedClips.undoLifetime))
            guard !Task.isCancelled, self?.lastDeletion?.date == deleted.date else { return }
            self?.lastDeletion = nil
        }
        show(notice)
    }

    private func show(_ notice: DeletionNotice) {
        deletionNotice = notice
        noticeTask?.cancel()
        noticeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled, self?.deletionNotice?.id == notice.id else { return }
            self?.deletionNotice = nil
        }
    }

    // MARK: Limite

    /// Choix des Reglages : applique tout de suite, ou demande confirmation si des elements partiraient.
    func requestHistoryLimit(_ limit: Int) {
        let overflow = (try? store.overflowCount(limit: limit)) ?? 0
        if overflow > 0 {
            pendingLimit = PendingLimit(limit: limit, overflow: overflow)
        } else {
            applyHistoryLimit(limit)
        }
    }

    func applyHistoryLimit(_ limit: Int) {
        pendingLimit = nil
        firstPurgePending = false
        historyLimit = limit
        UserDefaults.standard.set(limit, forKey: Brand.key("HistoryLimit"))
        _ = try? store.trim(to: limit)
        reload()
    }

    #if DEBUG
    /// Mode capture : plusieurs elements choisis, comme par ⌘-clic.
    func snapshotSelect(_ ids: [String]) {
        selection.select(ids.first)
        for id in ids.dropFirst() { selection.click(id, in: orderedIds, toggle: true) }
    }
    #endif

    // MARK: Clics

    /// Clic sur une ligne ; ⇧ et ⌘ etendent la selection si `multiple`.
    func click(_ item: ClipItem, multiple: Bool) {
        let flags = NSEvent.modifierFlags
        selection.click(item.id, in: orderedIds,
                        extend: multiple && flags.contains(.shift),
                        toggle: multiple && flags.contains(.command))
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
        selection.select(ordered[next].id)
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

/// Bandeau en bas de la liste apres une suppression (avec « Annuler ») ou une restauration partielle.
struct DeletionNotice: Equatable {
    let id = UUID()
    let text: String
    let undoable: Bool

    static func deleted(_ n: Int) -> DeletionNotice {
        DeletionNotice(text: n > 1 ? "\(n) éléments supprimés" : "1 élément supprimé", undoable: true)
    }

    static func purged(_ n: Int) -> DeletionNotice {
        DeletionNotice(text: n > 1 ? "\(n) anciens éléments supprimés" : "1 ancien élément supprimé", undoable: true)
    }

    static func partial(restored: Int, skipped: Int) -> DeletionNotice {
        let r = restored > 1 ? "\(restored) éléments restaurés" : "\(restored) élément restauré"
        let s = skipped > 1 ? "\(skipped) déjà copiés à nouveau" : "1 déjà copié à nouveau"
        return DeletionNotice(text: "\(r), \(s)", undoable: false)
    }
}

struct PendingLimit: Equatable {
    let limit: Int
    let overflow: Int
    var question: String {
        "Garder les \(limit) derniers et supprimer \(overflow) élément\(overflow > 1 ? "s" : "")\u{00A0}?"
    }
}
