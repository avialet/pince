import SwiftUI
import VialetKit
import PinceCore

struct MainWindow: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(Brand.displayName).font(Theme.display(26)).foregroundStyle(Theme.ink)
                    Text(".").font(Theme.display(26)).foregroundStyle(Brand.accent)
                }
                .padding(.horizontal, 18).padding(.top, 22).padding(.bottom, 12)
                List(ClipFilter.sidebar, id: \.self, selection: $state.filter) { filter in
                    Label(filter.label, systemImage: filter.icon)
                        .font(Theme.ui(13, weight: .medium))
                        .foregroundStyle(Theme.ink)
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                Spacer(minLength: 0)
                UpdateBanner(updater: Updater.shared)
                Text("Raccourci \(HotKeyController.shared.shortcut.display)")
                    .font(Theme.ui(11)).foregroundStyle(Theme.inkFaint)
                    .padding(.horizontal, 18).padding(.bottom, 14)
            }
            .frame(width: 200)
            .background(Theme.sidebar)
            ClipList(compact: false)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AmbientBackground(accent: Brand.accent))
        }
    }
}
