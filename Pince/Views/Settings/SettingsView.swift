import SwiftUI
import VialetKit
import PinceCore

struct SettingsView: View {
    @Environment(AppState.self) private var state
    private let hotKey = HotKeyController.shared
    @State private var trusted = Paster.isTrusted
    @AppStorage("PinceMenuBar") private var menuBarVisible = true
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var loginNeedsApproval = LaunchAtLogin.needsApproval
    @State private var appearance = AppearanceChoice.current(defaultsKey: Brand.key("Appearance"))

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("Réglages").font(Theme.display(26)).foregroundStyle(Theme.ink)
                Text(".").font(Theme.display(26)).foregroundStyle(Brand.accent)
            }

            SettingsCard(icon: "keyboard", color: Theme.sea, title: "Raccourci global") {
                HStack(spacing: 12) {
                    ShortcutRecorder(controller: hotKey)
                    Button("Rétablir") { hotKey.shortcut = .default }
                        .buttonStyle(.plain)
                        .font(Theme.ui(12, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                        .opacity(hotKey.shortcut == .default ? 0 : 1)
                }
                Text(hotKey.isTaken
                     ? "Cette combinaison est déjà utilisée par une autre app. Choisissez-en une autre."
                     : "Depuis n'importe quelle app : ouvre le panneau de l'historique, ↩ remet l'élément choisi dans le presse-papiers.")
                    .font(Theme.ui(12))
                    .foregroundStyle(hotKey.isTaken ? Theme.danger : Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            SettingsCard(icon: "power", color: Theme.pine, title: "Toujours là") {
                Toggle("Ouvrir \(Brand.displayName) à la connexion", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in
                        launchAtLogin = LaunchAtLogin.set(on)
                        loginNeedsApproval = LaunchAtLogin.needsApproval
                    }
                if loginNeedsApproval {
                    HStack(spacing: 6) {
                        Text("À autoriser dans Réglages Système › Ouverture.")
                            .font(Theme.ui(12)).foregroundStyle(Theme.coral)
                        Button("Ouvrir") { LaunchAtLogin.openSystemSettings() }
                            .buttonStyle(.link).font(Theme.ui(12, weight: .semibold))
                    }
                }
                Toggle("Icône dans la barre des menus", isOn: $menuBarVisible)
                Text("Fermer la fenêtre ne quitte pas \(Brand.displayName) : le raccourci reste actif. ⌘Q pour quitter.")
                    .font(Theme.ui(12)).foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            SettingsCard(icon: "doc.on.clipboard", color: Brand.accent, title: "Historique") {
                @Bindable var state = state
                Picker("Conserver", selection: $state.historyLimit) {
                    Text("100 éléments").tag(100)
                    Text("500 éléments").tag(500)
                    Text("2 000 éléments").tag(2000)
                    Text("Sans limite").tag(0)
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
                Button("Effacer l'historique (garder les épingles)") { state.clearHistory(keepPinned: true) }
                    .controlSize(.small)
            }

            SettingsCard(icon: "arrow.down.circle", color: Theme.coral, title: "Mises à jour") {
                UpdateCard(updater: Updater.shared)
            }

            SettingsCard(icon: "circle.lefthalf.filled", color: Theme.lavender, title: "Apparence") {
                Picker("", selection: $appearance) {
                    ForEach(AppearanceChoice.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .onChange(of: appearance) { _, choice in choice.apply(defaultsKey: Brand.key("Appearance")) }
            }
        }
        .toggleStyle(.switch)
        .font(Theme.ui(13))
        .padding(26)
        .frame(width: 480)
        .background(Theme.paper)
        .fontDesign(.rounded)
    }
}
