import SwiftUI
import VialetKit

/// Contenu du panneau flottant ouvert par le raccourci global.
struct PanelView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        PanelCard {
            VStack(spacing: 0) {
                ClipList(compact: true)
                Divider().overlay(Theme.line)
                HStack(spacing: 14) {
                    KeyHint("↑↓", "choisir")
                    KeyHint("↩", state.directPaste && Paster.isTrusted ? "coller" : "copier")
                    KeyHint("⌘P", "épingler")
                    KeyHint("⌘⌫", "supprimer")
                    KeyHint("esc", "fermer")
                    Spacer()
                    Text("\(state.items.count) élément\(state.items.count > 1 ? "s" : "")")
                        .font(Theme.ui(11.5, weight: .semibold)).foregroundStyle(Theme.inkSoft)
                }
                .padding(.horizontal, 16).padding(.vertical, 9)
            }
            .frame(width: AppState.panelSize.width - 32, height: AppState.panelSize.height - 24)
        }
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 16)
    }
}
