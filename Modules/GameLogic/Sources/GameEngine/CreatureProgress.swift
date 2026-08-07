import AlbumSystem
import BreedingSystem
import CreatureSystem
import Foundation
import GameContent
import GameCore
import GameState

/// Was sich seit dem letzten Öffnen an der Kreatur getan hat, jenseits der
/// Bedürfnisse.
public struct ProgressSummary: Sendable, Hashable {
    public var experienceGained: Int
    public var levelsGained: Int
    public var evolutions: [EvolutionEvent]
    public var hatched: [CreatureID]
    public var albumMilestone: Int?

    public init(
        experienceGained: Int = 0,
        levelsGained: Int = 0,
        evolutions: [EvolutionEvent] = [],
        hatched: [CreatureID] = [],
        albumMilestone: Int? = nil
    ) {
        self.experienceGained = experienceGained
        self.levelsGained = levelsGained
        self.evolutions = evolutions
        self.hatched = hatched
        self.albumMilestone = albumMilestone
    }
}

extension GameEngine {

    // MARK: - Album

    /// Trägt eine Kreatur ins Album ein und meldet einen erreichten Meilenstein.
    @discardableResult
    mutating func discover(_ record: CreatureRecord, at date: Date) -> Int? {
        let before = state.album.discoveredCount
        state.album.apply(
            .discovered(
                species: record.individual.speciesID,
                variant: record.individual.variant,
                at: date
            )
        )
        let after = state.album.discoveredCount
        guard after > before else { return nil }
        return AlbumSystem.reachedMilestone(discovered: after)
    }

    // MARK: - Erfahrung und Entwicklung

    /// Vergibt Erfahrung, prüft Entwicklungen und lässt fällige Eier schlüpfen.
    ///
    /// Läuft nach der Zeitauflösung: Erst steht fest, wie es der Kreatur ging,
    /// dann zählt, was ihr das gebracht hat.
    public mutating func advanceProgress(now: Date, healthyHours: [CreatureID: Int])
        -> ProgressSummary
    {
        var summary = ProgressSummary()

        for index in state.creatures.indices {
            let id = state.creatures[index].id
            let hours = healthyHours[id] ?? 0
            let award = hours * Growth.experiencePerHealthyHour
            guard award > 0 else { continue }

            let levelBefore = state.creatures[index].state.level
            Growth.award(award, to: &state.creatures[index].state)
            summary.experienceGained += award
            summary.levelsGained += state.creatures[index].state.level - levelBefore
        }

        summary.evolutions = checkEvolutions(now: now)
        summary.hatched = hatchDueEggs(now: now)

        for id in summary.hatched {
            guard let record = state.creature(id) else { continue }
            if let milestone = discover(record, at: now) {
                summary.albumMilestone = milestone
            }
        }

        return summary
    }

    /// Prüft für jede Kreatur, ob eine Entwicklung ansteht.
    ///
    /// Entwicklung passiert von selbst und wird gefeiert, statt bestätigt zu
    /// werden: Sie ist immer ein Gewinn, nie eine Entscheidung mit Reue.
    public mutating func checkEvolutions(now: Date) -> [EvolutionEvent] {
        var events: [EvolutionEvent] = []
        let evolutions = Array(content.evolutions.values)

        for index in state.creatures.indices {
            let record = state.creatures[index]
            guard let facts = facts(for: record.id, now: now) else { continue }
            guard
                let event = EvolutionCheck.opportunity(
                    for: record,
                    evolutions: evolutions,
                    facts: facts
                )
            else { continue }

            var updated = record
            EvolutionCheck.apply(event, to: &updated)
            state.creatures[index] = updated
            events.append(event)

            discover(updated, at: now)
        }

        return events
    }

    /// Was einer Kreatur noch zu welcher Entwicklung fehlt.
    public func evolutionHints(for id: CreatureID, now: Date) -> [EvolutionHint] {
        guard let record = state.creature(id), let facts = facts(for: id, now: now) else {
            return []
        }
        return EvolutionCheck.hints(
            for: record,
            evolutions: Array(content.evolutions.values),
            facts: facts
        )
    }

    // MARK: - Zucht

    public mutating func breed(
        _ first: CreatureID,
        _ second: CreatureID,
        now: Date
    ) -> Result<PendingEgg, BreedingFailure> {
        guard let a = parent(for: first), let b = parent(for: second) else {
            return .failure(.notAdult)
        }

        let result = BreedingSystem.pair(
            a,
            b,
            balancing: content.balancing,
            random: &state.player.random,
            pityCounter: &state.player.shimmerPityCounter,
            now: now
        )

        if case .success(let egg) = result {
            state.eggs.append(egg)
            state.player.lamport &+= 1
        }

        return result
    }

    /// Lässt alle fälligen Eier schlüpfen.
    public mutating func hatchDueEggs(now: Date) -> [CreatureID] {
        var hatched: [CreatureID] = []
        let due = state.eggs.filter { $0.isReady(at: now) }

        for egg in due {
            let id = BreedingSystem.creatureID(forEgg: egg.id)
            // Idempotent: Ein zweites Anwenden desselben Schluepfens erzeugt
            // keine zweite Kreatur.
            guard state.creature(id) == nil else { continue }

            let individual = CreatureIndividual(
                id: id,
                speciesID: egg.speciesID,
                personality: egg.personality,
                talents: egg.talents,
                variant: egg.variant,
                nickname: nil,
                bornAt: now,
                parents: egg.parents
            )
            state.creatures.append(
                CreatureRecord(
                    individual: individual,
                    state: CreatureState(cursor: TimeCursor(startingAt: now))
                )
            )
            hatched.append(id)
        }

        state.eggs.removeAll { $0.isReady(at: now) }
        return hatched
    }

    // MARK: - Intern

    private func parent(for id: CreatureID) -> BreedingParent? {
        guard let record = state.creature(id),
            let species = content.species[record.individual.speciesID]
        else { return nil }

        return BreedingParent(
            creatureID: record.id,
            species: species,
            personality: record.individual.personality,
            talents: record.individual.talents
        )
    }
}
