import SwiftUI
import VialetKit

/// Identite de l'app : le seul fichier Swift qui connait son nom, ses teintes et son glyphe.
enum Brand {
    static let name = "Pince"
    static let displayName = "Pince"
    /// Teintes de l'affiche (sites, plaques, DMG, interface), calculees par scripts/teintes.py :
    /// texte `deep` sur `background`.
    static let palette = AccentPalette(accent: 0x2F6FEB, background: 0x2F6FEB, deep: 0x00001F,
                                       pale: 0xEBF2FF, night: 0x0F1A2F, nightInk: 0xC4D8FD)
    /// Pictogramme de la plaque : sous-ensemble SVG absolu (M L H V C Q Z), boite 0-100, trait non rempli.
    static let glyph = "M 20 18 L 40 50 L 20 82 M 80 18 L 60 50 L 80 82"
    /// Trait du glyphe en `deep` plutot qu'en blanc (accent trop clair pour un trait blanc).
    static let strokeDeep = false
    static let identity = AppIdentity(name: name, displayName: displayName, repository: "avialet/pince",
                                      bundleIdentifier: "fr.vialet.pince", palette: palette, glyph: glyph,
                                      strokeDeep: strokeDeep)
    static let updater = UpdaterConfiguration(identity)

    /// Cles UserDefaults, prefixees par le nom de l'app.
    static func key(_ suffix: String) -> String { identity.key(suffix) }
}

extension Updater {
    static let shared = Updater(configuration: Brand.updater)
}

extension HotKeyController {
    /// ⌃⇧Espace par defaut : chaque app vialet.app a son propre raccourci (Pico garde ⇧⌘Espace).
    static let shared = HotKeyController(defaultsKey: Brand.key("HotKey"), logName: Brand.displayName,
                                         initial: .space([.control, .shift]))
}
