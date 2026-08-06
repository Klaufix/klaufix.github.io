import GameCore

/// Der geladene, geprüfte Inhalt des Spiels - eine Nur-Lese-Datenbank.
///
/// Systeme fragen hier nach Definitionen, statt Zahlen zu kennen. Ein Bundle
/// wird einmal gebaut und danach nie veraendert; deshalb ist es `Sendable` und
/// kann bedenkenlos ueber Nebenlaeufigkeitsgrenzen gereicht werden.
public struct ContentBundle: Sendable {
    public let species: [SpeciesID: SpeciesDefinition]
    public let evolutions: [EvolutionID: EvolutionDefinition]
    public let items: [ItemID: ItemDefinition]
    public let cosmetics: [CosmeticID: CosmeticDefinition]
    public let elementChart: ElementChart
    public let balancing: BalancingDefinition

    public init(
        species: [SpeciesDefinition],
        evolutions: [EvolutionDefinition],
        items: [ItemDefinition],
        cosmetics: [CosmeticDefinition],
        elementChart: ElementChart,
        balancing: BalancingDefinition
    ) {
        // Bei doppelten IDs gewinnt der erste Eintrag. Ein Absturz waere hier die
        // schlechtere Antwort - der Validator meldet den Konflikt ohnehin.
        self.species = Dictionary(species.map { ($0.id, $0) }) { first, _ in first }
        self.evolutions = Dictionary(evolutions.map { ($0.id, $0) }) { first, _ in first }
        self.items = Dictionary(items.map { ($0.id, $0) }) { first, _ in first }
        self.cosmetics = Dictionary(cosmetics.map { ($0.id, $0) }) { first, _ in first }
        self.elementChart = elementChart
        self.balancing = balancing
    }

    // MARK: - Nachschlagen
    //
    // Die Woerterbuecher sind oeffentlich; hier stehen nur Abfragen, die mehr
    // tun als einen Schluessel nachzuschlagen.

    /// Alle Entwicklungswege, die von einer Art ausgehen.
    public func evolutionPaths(from id: SpeciesID) -> [EvolutionDefinition] {
        evolutions.values.filter { $0.from == id }
    }

    /// Arten, die im Spiel auftauchen duerfen. Ausgemusterte bleiben im Bundle,
    /// damit alte Spielstaende sie weiterhin aufloesen koennen - sie erscheinen
    /// nur nirgends mehr neu.
    public var activeSpecies: [SpeciesDefinition] {
        species.values.filter { !$0.isRetired }
    }
}
