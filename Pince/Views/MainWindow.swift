import SwiftUI
import VialetKit
import PinceCore

struct MainWindow: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Wordmark(Brand.displayName)
                    .padding(.horizontal, 18).padding(.top, 22).padding(.bottom, 12)
                List(ClipFilter.sidebar, id: \.self, selection: $state.filter) { filter in
                    Label(filter.label, systemImage: filter.icon)
                        .font(Theme.ui(13, weight: .medium))
                        .foregroundStyle(Theme.ink)
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                Spacer(minLength: 0)
                ShortcutFooter(HotKeyController.shared.shortcut)
            }
            .frame(width: 200)
            .background(Theme.sidebar)
            VStack(spacing: 0) {
                UpdateNotice(updater: .shared)
                ClipList(compact: false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AmbientBackground())
        }
    }
}
