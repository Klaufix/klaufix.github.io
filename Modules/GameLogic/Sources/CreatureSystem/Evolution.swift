import Foundation
import GameContent
import GameCore
import GameRules

public enum EvolutionEvent: GameEvent, Sendable {
    case evolved(creature: CreatureID, from: SpeciesID, to: SpeciesID, evolution: EvolutionID)

    public static var eventType: String { "evolution" }
}

/// Ein erreichbarer Entwicklungsweg mit dem, was noch fehlt.
///
/// Das Album zeigt daraus Hinweise statt Sperren: „Dazu fehlt noch Nebel" ist
/// eine Einladung, „gesperrt" ist eine Wand (UI-Konzept, Regel 3).
public struct EvolutionHint: Sendable, Hashable {
    public let evolution: EvolutionID
    public let target: SpeciesID
    public let hintKey: String
    public let isPeaceful: Bool
    public let unmet: [ConditionExpression]

    public var isReachableNow: Bool { unmet.isEmpty }
}

public enum EvolutionCheck {

    /// Der erste Weg, dessen Bedingungen erfüllt sind.
    ///
    /// Reihenfolge ist Absicht: Ein seltener Sonderweg kann im Content vor dem
    /// Standardweg stehen und gewinnt dann.
    public static func opportunity(
        for record: CreatureRecord,
        evolutions: [EvolutionDefinition],
        facts: some FactProvider
    ) -> EvolutionEvent? {
        for definition in evolutions.sorted(by: { $0.id.rawValue < $1.id.rawValue })
        where definition.from == record.individual.speciesID {
            for branch in definition.branches
            where ConditionEvaluator.isSatisfied(branch.requires, by: facts) {
                return .evolved(
                    creature: record.id,
                    from: record.individual.speciesID,
                    to: branch.to,
                    evolution: definition.id
                )
            }
        }
        return nil
    }

    /// Alle Wege dieser Art, samt der offenen Bedingungen.
    public static func hints(
        for record: CreatureRecord,
        evolutions: [EvolutionDefinition],
        facts: some FactProvider
    ) -> [EvolutionHint] {
        evolutions
            .filter { $0.from == record.individual.speciesID }
            .sorted { $0.id.rawValue < $1.id.rawValue }
            .flatMap { definition in
                definition.branches.map { branch in
                    EvolutionHint(
                        evolution: definition.id,
                        target: branch.to,
                        hintKey: branch.hintKey,
                        isPeaceful: branch.isPeaceful,
                        unmet: ConditionEvaluator.unmetChecks(in: branch.requires, by: facts)
                    )
                }
            }
    }

    /// Wendet eine Entwicklung an.
    ///
    /// Es wechselt **nur** die Art. Name, Persönlichkeit, Anlagen, Freundschaft,
    /// Geburtsdatum und Stammbaum bleiben — der Spieler behält seine Kreatur,
    /// sie sieht nur anders aus.
    public static func apply(_ event: EvolutionEvent, to record: inout CreatureRecord) {
        switch event {
        case .evolved(_, _, let target, _):
            record.individual.speciesID = target
        }
    }
}
