import SwiftUI
import VialetKit
import PinceCore

/// Liste de l'historique avec recherche, partagee par le panneau et la fenetre.
/// Le champ garde le focus : les fleches, ↩, ⌘P et ⌘⌫ agissent sur la selection.
struct ClipList: View {
    @Environment(AppState.self) private var state
    let compact: Bool
    @FocusState private var searchFocused: Bool

    var body: some View {
        @Bindable var state = state
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.inkFaint)
                TextField("", text: $state.query, prompt: Text("Rechercher dans l'historique…").foregroundStyle(Theme.inkFaint))
                    .textFieldStyle(.plain)
                    .font(Theme.ui(compact ? 17 : 15, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .focused($searchFocused)
                    .onKeyPress(.downArrow) { state.moveSelection(by: 1); return .handled }
                    .onKeyPress(.upArrow) { state.moveSelection(by: -1); return .handled }
                    .onKeyPress(.return) { if let item = state.selectedItem { state.use(item) }; return .handled }
                    .onKeyPress(.escape) { if state.query.isEmpty { return .ignored }; state.query = ""; return .handled }
                    .onKeyPress(phases: .down) { press in
                        guard press.modifiers.contains(.command), let item = state.selectedItem else { return .ignored }
                        if press.key == "p" { state.togglePin(item); return .handled }
                        if press.key == .delete { state.delete(item); return .handled }
                        return .ignored
                    }
                if !state.query.isEmpty {
                    Button { state.query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.inkFaint) }.buttonStyle(.plain)
                }
                if compact {
                    Text("pince.").font(Theme.display(15, weight: .heavy)).foregroundStyle(Theme.inkFaint)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, compact ? 12 : 10)
            Divider().overlay(Theme.line)
            if state.items.isEmpty {
                empty
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2, pinnedViews: [.sectionHeaders]) {
                            ForEach(state.sections, id: \.title) { section in
                                Section {
                                    ForEach(section.items) { item in
                                        ClipRow(item: item, selected: item.id == state.selectedId, compact: compact)
                                            .id(item.id)
                                            .onTapGesture(count: 2) { state.use(item) }
                                            .onTapGesture { state.selectedId = item.id }
                                            .contextMenu { RowMenu(item: item) }
                                    }
                                } header: {
                                    Text(section.title)
                                        .font(Theme.ui(11, weight: .bold)).foregroundStyle(Theme.inkFaint).textCase(.uppercase)
                                        .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 4)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(compact ? Theme.card : Theme.paper.opacity(0.92))
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                    }
                    .onChange(of: state.selectedId) { _, id in if let id { withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(id, anchor: .center) } } }
                }
            }
        }
        .onAppear { searchFocused = true }
        .onChange(of: state.panelOpenCount) { _, _ in searchFocused = true }
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Image(systemName: state.query.isEmpty ? "doc.on.clipboard" : "magnifyingglass")
                .font(.system(size: 30, weight: .light)).foregroundStyle(Theme.inkFaint)
            Text(state.query.isEmpty ? "Rien pour l'instant. Copiez quelque chose : Pince le garde." : "Aucune copie ne contient « \(state.query) ».")
                .font(Theme.ui(13)).foregroundStyle(Theme.inkSoft).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

/// Actions contextuelles d'une entree.
struct RowMenu: View {
    @Environment(AppState.self) private var state
    let item: ClipItem

    var body: some View {
        Button("Copier") { state.use(item) }
        if item.kind == .url, let text = item.text, let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) {
            Button("Ouvrir le lien") { NSWorkspace.shared.open(url) }
        }
        if item.kind == .files || item.kind == .path {
            Button("Afficher dans le Finder") {
                let urls = item.kind == .files ? item.fileURLs : [URL(fileURLWithPath: ((item.text ?? "") as NSString).expandingTildeInPath)]
                NSWorkspace.shared.activateFileViewerSelecting(urls)
            }
        }
        if item.kind == .json, let text = item.text, let pretty = JSONTools.pretty(text) {
            Button("Copier le JSON formaté") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(pretty, forType: .string) }
        }
        Divider()
        Button(item.pinned ? "Désépingler" : "Épingler") { state.togglePin(item) }
        Button("Supprimer") { state.delete(item) }
    }
}

struct ClipRow: View {
    @Environment(AppState.self) private var state
    let item: ClipItem
    let selected: Bool
    let compact: Bool

    var body: some View {
        HStack(spacing: 11) {
            visual.frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.preview.isEmpty ? " " : item.preview)
                    .font(Theme.ui(13, weight: item.kind == .code || item.kind == .json ? .regular : .medium))
                    .fontDesign(item.kind == .code || item.kind == .json ? .monospaced : .rounded)
                    .foregroundStyle(Theme.ink).lineLimit(compact ? 1 : 2)
                Text(subtitle).font(Theme.ui(11)).foregroundStyle(Theme.inkSoft).lineLimit(1)
            }
            Spacer(minLength: 6)
            if item.pinned { Image(systemName: "pin.fill").font(.system(size: 10, weight: .bold)).foregroundStyle(Brand.accent) }
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(selected ? Brand.accent.opacity(0.14) : .clear))
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private var visual: some View {
        switch item.kind {
        case .color:
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color(hex: ContentDetector.hexColor(item.text ?? "") ?? 0x888888))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
        case .image:
            if let url = state.imageURL(for: item), let image = NSImage(contentsOf: url) {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                    .frame(width: 36, height: 36).clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            } else {
                icon
            }
        case .files:
            if let first = item.fileURLs.first {
                Image(nsImage: NSWorkspace.shared.icon(forFile: first.path)).resizable().frame(width: 32, height: 32)
            } else {
                icon
            }
        default:
            icon
        }
    }

    private var icon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Brand.accent.opacity(0.12))
            Image(systemName: item.kind.icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(Brand.accent)
        }
    }

    private var subtitle: String {
        var parts = [item.kind.label]
        if let app = item.sourceApp, let name = AppNames.name(for: app) { parts.append(name) }
        parts.append(Self.relative.localizedString(for: item.createdAt, relativeTo: Date()))
        if item.kind == .files { parts.append("\(item.fileURLs.count) élément\(item.fileURLs.count > 1 ? "s" : "")") }
        if item.kind == .image || item.kind == .text, item.byteCount > 2000 { parts.append(item.byteCount.fileSizeLabel) }
        return parts.joined(separator: " · ")
    }

    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.unitsStyle = .short
        return f
    }()
}

/// Nom affiche d'une app a partir de son identifiant de bundle (cache).
@MainActor
enum AppNames {
    private static var cache: [String: String?] = [:]

    static func name(for bundleId: String) -> String? {
        if let cached = cache[bundleId] { return cached }
        let name = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)
            .map { FileManager.default.displayName(atPath: $0.path).replacingOccurrences(of: ".app", with: "") }
        cache[bundleId] = name
        return name
    }
}

extension Int {
    var fileSizeLabel: String {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowedUnits = [.useKB, .useMB]
        return f.string(fromByteCount: Int64(self))
    }
}
