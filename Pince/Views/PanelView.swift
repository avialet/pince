import SwiftUI
import VialetKit

/// Contenu du panneau flottant ouvert par le raccourci global.
struct PanelView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: 0) {
            ClipList(compact: true)
            Divider().overlay(Theme.line)
            HStack(spacing: 14) {
                hint("↑↓", "choisir")
                hint("↩", state.directPaste && Paster.isTrusted ? "coller" : "copier")
                hint("⌘P", "épingler")
                hint("⌘⌫", "supprimer")
                hint("esc", "fermer")
                Spacer()
                Text("\(state.items.count) élément\(state.items.count > 1 ? "s" : "")")
                    .font(Theme.ui(11.5, weight: .semibold)).foregroundStyle(Theme.inkSoft)
            }
            .padding(.horizontal, 16).padding(.vertical, 9)
        }
        .frame(width: AppState.panelSize.width - 32, height: AppState.panelSize.height - 24)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.card).shadow(color: .black.opacity(0.22), radius: 18, y: 8))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 16)
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key).font(Theme.ui(11, weight: .bold))
                .padding(.horizontal, 5).padding(.vertical, 1)
                .background(RoundedRectangle(cornerRadius: 4).fill(Theme.ink.opacity(0.07)))
            Text(label).font(Theme.ui(11.5))
        }
        .foregroundStyle(Theme.inkSoft)
    }
}
