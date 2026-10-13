import SwiftUI
import VialetKit
import PinceCore

struct MenuBarContent: View {
    @Environment(AppState.self) private var state

    var body: some View {
        let recent = Array(state.items.prefix(7))
        if recent.isEmpty {
            Text("Historique vide")
        } else {
            ForEach(recent) { item in
                Button {
                    state.use(item)
                } label: {
                    Label(String(item.preview.prefix(48)) + (item.preview.count > 48 ? "…" : ""), systemImage: item.kind.icon)
                }
            }
        }
        Divider()
        Button("Afficher le panneau") { state.togglePanel() }
        Button("Ouvrir \(Brand.displayName)") { WindowSummoner.show() }
        Button("Tout effacer (garder les épingles)") { state.clearHistory(keepPinned: true) }
        Divider()
        SettingsLink { Text("Réglages…") }
        Button("Quitter") { NSApp.terminate(nil) }
    }
}
