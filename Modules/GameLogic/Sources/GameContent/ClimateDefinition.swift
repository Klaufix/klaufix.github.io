import GameCore

/// Das Wettermodell als Inhalt.
///
/// Simuliertes Spielwetter (ADR-003): Es gibt keine Standortabfrage. Der Vorteil
/// ist nicht nur Datenschutz - Wetter wird damit zu planbarem Inhalt. Ein Event,
/// das Nebel braucht, ist für jeden Spieler erreichbar.
public struct ClimateDefinition: Sendable, Hashable, Codable {
    public let schemaVersion: Int
    /// Wie lange eine Wetterlage anhält, in Stunden.
    public let slotHours: Int
    public let weather: [WeatherDefinition]
}

public struct WeatherDefinition: Sendable, Hashable, Codable, Identifiable {
    public let id: WeatherID
    public let nameKey: String
    /// Gewicht je Jahreszeit. Fehlt eine Jahreszeit, kommt diese Wetterlage
    /// darin nicht vor - so entsteht Schnee ohne Sonderregel im Code.
    public let weights: [String: Int]

    public func weight(in season: Season) -> Int {
        max(weights[season.rawValue] ?? 0, 0)
    }
}
