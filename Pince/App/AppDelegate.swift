import AppKit
import VialetKit
import PinceCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppState.shared.start()
        HotKeyController.shared.start { AppState.shared.togglePanel() }
        // Laisse l'app s'afficher avant le moindre appel reseau.
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            MainActor.assumeIsolated { Updater.shared.checkAutomatically() }
        }
        #if DEBUG
        runSnapshotIfRequested()
        #endif
    }

    /// Liens `pince://` : ouvre la fenetre principale.
    func application(_ application: NSApplication, open urls: [URL]) {
        WindowSummoner.show()
    }

    /// L'app reste disponible (raccourci global, barre des menus) fenetre fermee.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { WindowSummoner.show() }
        return true
    }
}

#if DEBUG
/// Mode de verification sans ecran : `Pince -PinceSnapshot /chemin/base -PinceSnapshotSeed 1`
/// (avec PINCE_DB_PATH vers une base jetable) remplit l'historique d'exemples,
/// capture la fenetre principale (`base-1.png`) puis le panneau (`base-2.png`), quitte.
extension AppDelegate {
    func runSnapshotIfRequested() {
        let defaults = UserDefaults.standard
        guard let base = defaults.string(forKey: "PinceSnapshot") else { return }
        Task { @MainActor in
            let state = AppState.shared
            if defaults.bool(forKey: "PinceSnapshotSeed") {
                let now = Date()
                let samples: [(String, String?, TimeInterval)] = [
                    ("https://developer.apple.com/documentation/appkit/nspasteboard", "com.apple.Safari", -40),
                    ("#2F6FEB", "com.figma.Desktop", -300),
                    ("{\"name\":\"Pince\",\"version\":\"0.1.0\",\"tags\":[\"mac\",\"local\"]}", "com.microsoft.VSCode", -3600 * 2),
                    ("Réunion de lancement jeudi 14 h, salle Calanque. Apporter les maquettes imprimées.", "com.apple.Notes", -3600 * 5),
                    ("a.vialet@plan-net.com", "com.microsoft.Outlook", -86400 - 600),
                    ("func toggle() {\n    isVisible ? hide() : show()\n}", "com.apple.dt.Xcode", -86400 * 3),
                    ("/Users/aurelien/Documents/PERSO/vialetapps", "com.apple.finder", -86400 * 9),
                ]
                for (text, app, age) in samples { _ = try? state.store.record(text: text, sourceApp: app, now: now.addingTimeInterval(age)) }
                _ = try? state.store.record(files: [URL(fileURLWithPath: "/Users/aurelien/Desktop/Rapport final.pdf"), URL(fileURLWithPath: "/Users/aurelien/Desktop/budget.xlsx")], sourceApp: "com.apple.finder", now: now.addingTimeInterval(-120))
                if let pinned = try? state.store.items(matching: "2F6FEB", kind: nil).first { try? state.store.setPinned(pinned.id, true) }
                state.reload()
            }
            try? await Task.sleep(for: .seconds(2))
            if let window = WindowSummoner.mainWindow { try? WindowSnapshot.write(window, to: URL(fileURLWithPath: base + "-1.png")) }
            state.togglePanel()
            try? await Task.sleep(for: .seconds(1))
            if let panelWindow = NSApp.windows.first(where: { $0 is FloatingPanel }) {
                try? WindowSnapshot.write(panelWindow, to: URL(fileURLWithPath: base + "-2.png"))
            }
            print("items: \(state.items.count), sections: \(state.sections.map { "\($0.title)=\($0.items.count)" })")
            NSApp.terminate(nil)
        }
    }
}
#endif
