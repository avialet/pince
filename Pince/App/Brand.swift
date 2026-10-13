import SwiftUI
import VialetKit

/// Identite de l'app : le seul fichier Swift qui connait son nom.
enum Brand {
    static let name = "Pince"
    static let displayName = "Pince"
    static let accent = Color(hex: 0x2F6FEB)
    static let updater = UpdaterConfiguration(repository: "avialet/pince", appName: name,
                                              bundleIdentifier: "fr.vialet.pince", displayName: displayName)

    /// Cles UserDefaults, prefixees par le nom de l'app.
    static func key(_ suffix: String) -> String { name + suffix }
}

extension Updater {
    static let shared = Updater(configuration: Brand.updater)
}

extension HotKeyController {
    static let shared = HotKeyController(defaultsKey: Brand.key("HotKey"), logName: Brand.displayName)
}
