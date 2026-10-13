import SwiftUI
import VialetKit

@main
struct PinceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var state = AppState.shared
    @AppStorage("PinceMenuBar") private var menuBarVisible = true

    var body: some Scene {
        Window(Brand.displayName, id: "main") {
            MainWindow()
                .environment(state)
                .fontDesign(.rounded)
                .frame(minWidth: 640, minHeight: 420)
                .onAppear { AppearanceChoice.current(defaultsKey: Brand.key("Appearance")).apply(defaultsKey: Brand.key("Appearance")) }
                .captureOpenWindow()
        }
        .windowStyle(.hiddenTitleBar)
        .windowBackgroundDragBehavior(.enabled)
        .defaultSize(width: 860, height: 560)

        Settings {
            SettingsView()
        }

        MenuBarExtra(isInserted: $menuBarVisible) {
            MenuBarContent().environment(state)
        } label: {
            Image(systemName: "app.dashed") // a adapter : symbole de l'app
        }
    }
}
