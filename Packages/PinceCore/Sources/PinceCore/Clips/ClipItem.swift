import Foundation
import GRDB
import VialetKit

/// Une entree de l'historique du presse-papiers.
public struct ClipItem: Codable, Sendable, Identifiable, Equatable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "clip"

    public var id: String
    public var kind: ContentKind
    /// Texte copie ; pour `.files`, les chemins separes par des retours a la ligne ; nil pour une image.
    public var text: String?
    /// Nom du fichier PNG dans le dossier des images, pour `.image`.
    public var imagePath: String?
    public var byteCount: Int
    /// SHA-256 du contenu : une meme copie ne cree pas deux entrees.
    public var contentHash: String
    /// Identifiant de bundle de l'app au premier plan au moment de la copie.
    public var sourceApp: String?
    public var createdAt: Date
    public var pinned: Bool
    /// Une ligne courte pour les listes.
    public var preview: String
    /// `preview` normalise (minuscules, sans accents) pour la recherche.
    public var searchText: String

    public var fileURLs: [URL] {
        guard kind == .files, let text else { return [] }
        return text.split(whereSeparator: \.isNewline).map { URL(fileURLWithPath: String($0)) }
    }

    /// Premiere(s) ligne(s), espaces repliees, 150 caracteres au plus.
    public static func preview(for text: String, limit: Int = 150) -> String {
        let lines = text.split(whereSeparator: \.isNewline)
            .map { $0.split(whereSeparator: { $0 == " " || $0 == "\t" }).joined(separator: " ") }
            .filter { !$0.isEmpty }
        let joined = lines.joined(separator: " ⏎ ")
        if joined.count <= limit { return joined }
        return String(joined.prefix(limit)).trimmingCharacters(in: .whitespaces) + "…"
    }
}
