import Foundation

/// Nombre d'elements non epingles gardes dans l'historique. 0 : « Tout » (sans limite).
public enum HistoryLimit {
    public static let defaultValue = 15
    /// Choix des Reglages, « Tout » en dernier.
    public static let choices = [15, 25, 50, 100, 500, 0]

    /// Valeur enregistree dans les reglages (nil : jamais choisie) -> limite appliquee.
    /// Un choix explicite est respecte, meme hors de la liste (ancien 2 000).
    public static func resolve(stored: Any?) -> Int {
        guard let value = stored as? Int, value >= 0 else { return defaultValue }
        return value
    }

    /// Les choix, plus la valeur courante si elle n'en fait pas partie (a sa place, « Tout » en dernier).
    public static func choices(including current: Int) -> [Int] {
        guard !choices.contains(current) else { return choices }
        return (choices.filter { $0 > 0 } + [current]).sorted() + [0]
    }

    public static func label(_ limit: Int) -> String {
        guard limit > 0 else { return "Tout" }
        let f = NumberFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.numberStyle = .decimal
        let n = (f.string(from: NSNumber(value: limit)) ?? "\(limit)").replacingOccurrences(of: "\u{202F}", with: " ")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
        return "\(n) derniers"
    }
}
