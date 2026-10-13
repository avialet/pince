import SwiftUI
import VialetKit

/// Identite de l'app : le seul fichier Swift qui connait son nom.
enum Brand {
    static let name = "Pince"
    static let displayName = "Pince"
    static let accent = Color(hex: 0x2F6FEB)
    /// Teintes de l'affiche (sites, plaques, DMG), calculees par scripts/teintes.py : texte `deep` sur `background`.
    static let background: UInt32 = 0x2F6FEB
    static let deep: UInt32 = 0x00001F
    static let pale: UInt32 = 0xEBF2FF
    static let night: UInt32 = 0x0F1A2F
    static let nightInk: UInt32 = 0xC4D8FD
    /// Pictogramme de la plaque : sous-ensemble SVG absolu (M L H V C Q Z), boite 0-100, trait non rempli.
    static let glyph = "M 24 20 L 44 50 L 24 80 M 76 20 L 56 50 L 76 80"
    static let updater = UpdaterConfiguration(repository: "avialet/pince", appName: name,
                                              bundleIdentifier: "fr.vialet.pince", displayName: displayName)

    /// Cles UserDefaults, prefixees par le nom de l'app.
    static func key(_ suffix: String) -> String { name + suffix }
}

extension Updater {
    static let shared = Updater(configuration: Brand.updater)
}

extension HotKeyController {
    /// ⌃⇧Espace par defaut : chaque app vialet.app a son propre raccourci (Pico garde ⇧⌘Espace).
    static let shared = HotKeyController(defaultsKey: Brand.key("HotKey"), logName: Brand.displayName,
                                         initial: .space([.control, .shift]))
}
