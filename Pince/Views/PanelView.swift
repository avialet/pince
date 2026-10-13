import SwiftUI
import VialetKit

/// Contenu du panneau flottant ouvert par le raccourci global.
struct PanelView: View {
    /// Marge transparente autour de la carte : l'ombre de PanelCard (rayon 18, decalage 8) s'y estompe
    /// sans etre coupee par le bord de la fenetre, en haut comme en bas.
    static let margin: CGFloat = 32

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
            .frame(width: AppState.panelSize.width - 2 * Self.margin, height: AppState.panelSize.height - 2 * Self.margin)
        }
        .padding(Self.margin)
    }
}
