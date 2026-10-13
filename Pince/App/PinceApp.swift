import SwiftUI
import VialetKit

@main
struct PinceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var state = AppState.shared
    @AppStorage(Brand.key("MenuBar")) private var menuBarVisible = true

    /// Teintes de l'app avant le premier rendu (et police Bricolage Grotesque des titres).
    init() { Theme.configure(Brand.palette) }

    var body: some Scene {
        Window(Brand.displayName, id: "main") {
            MainWindow()
                .environment(state)
                .fontDesign(.rounded)
                .frame(minWidth: 760, minHeight: 480)
                .onAppear { AppearanceChoice.current(defaultsKey: Brand.key("Appearance")).apply(defaultsKey: Brand.key("Appearance")) }
                .captureOpenWindow()
        }
        .windowStyle(.hiddenTitleBar)
        .windowBackgroundDragBehavior(.enabled)
        .defaultSize(width: 920, height: 600)
        .commands {
            AboutCommands(identity: Brand.identity)
            PinceCommands(state: state)
        }

        Settings {
            SettingsView().environment(state)
        }

        MenuBarExtra(isInserted: $menuBarVisible) {
            MenuBarContent().environment(state)
        } label: {
            MenuBarIcon(glyph: Brand.glyph)
        }
    }
}

struct PinceCommands: Commands {
    let state: AppState

    var body: some Commands {
        CommandGroup(replacing: .newItem) {}
        CommandMenu("Presse-papiers") {
            Button("Afficher le panneau") { state.togglePanel() }
            Button("Copier l'élément sélectionné") { if let item = state.selectedItem { state.use(item) } }
                .keyboardShortcut(.return, modifiers: .command).disabled(state.selectedItem == nil)
            Button("Épingler / désépingler") { if let item = state.selectedItem { state.togglePin(item) } }
                .keyboardShortcut("p").disabled(state.selectedItem == nil)
            Button("Supprimer") { if let item = state.selectedItem { state.delete(item) } }
                .keyboardShortcut(.delete, modifiers: .command).disabled(state.selectedItem == nil)
            Divider()
            Button("Effacer l'historique (garder les épingles)") { state.clearHistory(keepPinned: true) }
        }
    }
}
