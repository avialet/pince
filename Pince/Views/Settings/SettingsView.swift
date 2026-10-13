import SwiftUI
import VialetKit
import PinceCore

/// Reglages : les quatre cartes standard du kit, puis la carte Historique propre a Pince.
struct SettingsView: View {
    @Environment(AppState.self) private var state
    @State private var trusted = Paster.isTrusted

    var body: some View {
        SettingsScreen(app: Brand.identity, hotKey: HotKeyController.shared, updater: Updater.shared,
                       menuBar: MenuBarPresence.shared,
                       hotKeyHint: "Depuis n'importe quelle app : ouvre le panneau de l'historique, ↩ remet l'élément choisi dans le presse-papiers.",
                       width: 480) {
            SettingsCard(icon: "doc.on.clipboard", color: Theme.accent, title: "Historique") {
                @Bindable var state = state
                Picker("Conserver", selection: Binding(get: { state.historyLimit }, set: { state.requestHistoryLimit($0) })) {
                    ForEach(HistoryLimit.choices(including: state.historyLimit), id: \.self) { limit in
                        Text(HistoryLimit.label(limit)).tag(limit)
                    }
                }
                .alert(state.pendingLimit?.question ?? "", isPresented: Binding(get: { state.pendingLimit != nil }, set: { if !$0 { state.pendingLimit = nil } })) {
                    Button("Supprimer", role: .destructive) { if let pending = state.pendingLimit { state.applyHistoryLimit(pending.limit) } }
                    Button("Annuler", role: .cancel) { state.pendingLimit = nil }
                } message: {
                    Text("Les éléments épinglés ne comptent pas et sont toujours gardés.")
                }
                Toggle("Coller directement dans l'app active (↩)", isOn: $state.directPaste)
                    .onChange(of: state.directPaste) { _, on in if on, !Paster.isTrusted { Paster.requestTrust() }; trusted = Paster.isTrusted }
                if state.directPaste, !trusted {
                    HStack(spacing: 6) {
                        Text("À autoriser dans Réglages Système › Confidentialité et sécurité › Accessibilité.")
                            .font(Theme.ui(12)).foregroundStyle(Theme.coral).fixedSize(horizontal: false, vertical: true)
                        Button("Vérifier") { trusted = Paster.isTrusted }
                            .buttonStyle(.link).font(Theme.ui(12, weight: .semibold))
                    }
                } else {
                    Text("Sans cette option, ↩ remet l'élément dans le presse-papiers : à vous de coller avec ⌘V. Les copies marquées confidentielles par les gestionnaires de mots de passe ne sont jamais enregistrées.")
                        .font(Theme.ui(12)).foregroundStyle(Theme.inkSoft).fixedSize(horizontal: false, vertical: true)
                }
                TextField("Apps ignorées (identifiants, séparés par des virgules)", text: $state.excludedApps)
                    .textFieldStyle(.roundedBorder).font(Theme.ui(12))
                Button("Tout effacer (garder les épingles)") { state.clearHistory(keepPinned: true) }
                    .controlSize(.small)
            }
        }
    }
}
