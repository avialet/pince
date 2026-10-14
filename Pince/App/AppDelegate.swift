import AppKit
import VialetKit
import PinceCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        // Mode capture : ni presse-papiers, ni raccourci, ni reseau.
        if runSnapshotIfRequested() { return }
        if writeHubManifestIfRequested() { return }
        #endif
        _ = DockPresence.shared
        HubPresence.start(menuBar: MenuBarPresence.shared, actions: AppActions.shared, updater: Updater.shared)
        AppState.shared.start()
        HotKeyController.shared.start { AppState.shared.togglePanel() }
        // Laisse l'app s'afficher avant le moindre appel reseau.
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            MainActor.assumeIsolated { Updater.shared.checkAutomatically() }
        }
    }

    /// Liens `pince://` : `pince://historique` ouvre le panneau de l'historique, `pince://update` verifie
    /// les mises a jour ; le reste ouvre la fenetre principale.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where !AppActions.shared.handle(url) { WindowSummoner.show() }
    }

    /// L'app reste disponible (raccourci global, barre des menus) fenetre fermee.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { WindowSummoner.show() }
        return true
    }
}

#if DEBUG
extension AppDelegate {
    /// `Pince -PinceHubManifest <dossier>` : ecrit la fiche pour Vialet dans le dossier (sans la condition
    /// du dossier Applications, sans prevenir Vialet), imprime son chemin et quitte.
    func writeHubManifestIfRequested() -> Bool {
        guard let path = UserDefaults.standard.string(forKey: Brand.key("HubManifest")) else { return false }
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        do {
            try AppActions.shared.manifest().write(to: directory)
            print("fiche : \(HubManifest.fileURL(bundleIdentifier: Brand.identity.bundleIdentifier, in: directory).path)")
        } catch {
            print("fiche non ecrite : \(error)")
        }
        exit(0)
    }
}

/// Mode capture sans ecran : `Pince -PinceSnapshot <dossier> [-PinceSnapshotSeed 1]
/// [-PinceSnapshotAppearance dark] [-PinceSnapshotOnly a,b] [-PinceSnapshotSize 1000x720]`
/// (avec PINCE_DB_PATH vers une base jetable). Ecrit `mainWindow`, `settings`, `about`,
/// `floatingPanel`, `historique` (selection multiple, ligne survolee avec sa corbeille),
/// `annulation` (bandeau apres une suppression) et `actionHistorique` (action rapide `pince://historique`)
/// (`-sombre` en sombre), puis quitte (voir SnapshotRunner).
extension AppDelegate {
    func runSnapshotIfRequested() -> Bool {
        guard SnapshotRequest.parse(prefix: Brand.name, arguments: CommandLine.arguments) != nil else { return false }
        let state = AppState.shared
        if UserDefaults.standard.bool(forKey: Brand.key("SnapshotSeed")) { seed(state) }
        let panel = SnapshotScenario("floatingPanel") {
            state.togglePanel()
            try await Task.sleep(for: .seconds(1))
            return NSApp.windows.first { $0 is FloatingPanel && $0.isVisible }
        }
        let history = SnapshotScenario("historique") {
            try await Task.sleep(for: .seconds(2))
            let ids = state.orderedIds
            guard ids.count > 5 else { return nil }
            state.snapshotSelect([ids[1], ids[2], ids[3]])
            state.snapshotHoverId = ids[5]
            try await Task.sleep(for: .milliseconds(500))
            return WindowSummoner.mainWindow
        }
        let undo = SnapshotScenario("annulation") {
            try await Task.sleep(for: .seconds(2))
            state.snapshotHoverId = nil
            let ids = state.orderedIds
            guard ids.count > 4 else { return nil }
            state.delete(ids: [ids[2], ids[3], ids[4]])
            try await Task.sleep(for: .milliseconds(600))
            return WindowSummoner.mainWindow
        }
        // Action rapide de Vialet, par son URL : le panneau de l'historique.
        let action = SnapshotScenario("actionHistorique") {
            AppActions.shared.handle(URL(string: "pince://historique")!)
            try await Task.sleep(for: .seconds(1))
            return NSApp.windows.first { $0 is FloatingPanel && $0.isVisible }
        }
        let standard = SnapshotRunner.standardScenarios(mainWindow: { WindowSummoner.mainWindow }, identity: Brand.identity)
        return SnapshotRunner.runIfRequested(prefix: Brand.name, scenarios: standard + [panel, history, undo, action])
    }

    /// Exemples neutres, sans donnee personnelle.
    private func seed(_ state: AppState) {
        let now = Date()
        let samples: [(String, String?, TimeInterval)] = [
            ("https://developer.apple.com/documentation/appkit/nspasteboard", "com.apple.Safari", -40),
            ("#2F6FEB", "com.figma.Desktop", -300),
            ("{\"name\":\"Pince\",\"version\":\"0.2.0\",\"tags\":[\"mac\",\"local\"]}", "com.microsoft.VSCode", -3600 * 2),
            ("R\u{00E9}union de lancement jeudi 14 h, salle Calanque. Apporter les maquettes imprim\u{00E9}es.", "com.apple.Notes", -3600 * 5),
            ("contact@exemple.fr", "com.microsoft.Outlook", -86400 - 600),
            ("func toggle() {\n    isVisible ? hide() : show()\n}", "com.apple.dt.Xcode", -86400 * 3),
            ("~/Documents/Notes/reunion.md", "com.apple.finder", -86400 * 9),
        ]
        for (text, app, age) in samples { _ = try? state.store.record(text: text, sourceApp: app, now: now.addingTimeInterval(age)) }
        let files = ["/Users/Shared/Exemples/Rapport annuel.pdf", "/Users/Shared/Exemples/Budget 2026.xlsx"].map(URL.init(fileURLWithPath:))
        _ = try? state.store.record(files: files, sourceApp: "com.apple.finder", now: now.addingTimeInterval(-120))
        if let pinned = try? state.store.items(matching: "2F6FEB", kind: nil).first { try? state.store.setPinned(pinned.id, true) }
        state.reload()
    }
}
#endif
