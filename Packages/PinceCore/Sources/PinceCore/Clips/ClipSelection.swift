import Foundation

/// Selection de la liste : un element principal (clavier, apercu) et, dans la fenetre,
/// plusieurs elements par ⇧-clic (plage depuis l'ancre) et ⌘-clic (ajout ou retrait).
public struct ClipSelection: Equatable, Sendable {
    public private(set) var ids: Set<String> = []
    public private(set) var primary: String?
    private var anchor: String?

    public init(primary: String? = nil) {
        select(primary)
    }

    /// Un seul element (ou aucun).
    public mutating func select(_ id: String?) {
        primary = id
        anchor = id
        ids = id.map { [$0] } ?? []
    }

    /// Plusieurs elements (restaures, par exemple) ; le principal est le premier affiche.
    /// Liste vide : selection inchangee.
    public mutating func select(all chosen: [String], in order: [String]) {
        let set = Set(chosen)
        guard let first = order.first(where: { set.contains($0) }) ?? chosen.first else { return }
        ids = set
        primary = first
        anchor = first
    }

    /// Clic sur `id` ; `order` : les ids dans l'ordre affiche.
    public mutating func click(_ id: String, in order: [String], extend: Bool = false, toggle: Bool = false) {
        if extend, let anchor, let a = order.firstIndex(of: anchor), let b = order.firstIndex(of: id) {
            ids = Set(order[min(a, b)...max(a, b)])
            primary = id
        } else if toggle {
            if ids.contains(id) {
                ids.remove(id)
                if primary == id { primary = order.first { ids.contains($0) } }
            } else {
                ids.insert(id)
                primary = id
                anchor = id
            }
        } else {
            select(id)
        }
    }

    /// Ne garde que les elements encore affiches ; s'il n'en reste aucun, le premier affiche.
    public mutating func prune(to order: [String]) {
        let visible = Set(order)
        ids.formIntersection(visible)
        if let primary, ids.contains(primary) { return }
        if let first = order.first(where: { ids.contains($0) }) {
            primary = first
            if let anchor, !visible.contains(anchor) { self.anchor = first }
        } else {
            select(order.first)
        }
    }

    /// Element a choisir apres la suppression de `deleted` : le suivant, sinon le precedent.
    public static func next(afterDeleting deleted: Set<String>, in order: [String]) -> String? {
        guard let first = order.firstIndex(where: { deleted.contains($0) }) else { return order.first }
        return order[first...].first { !deleted.contains($0) } ?? order[..<first].last
    }
}
