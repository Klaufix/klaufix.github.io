import CreatureSystem
import Foundation
import GameContent
import GameCore
import GameState

/// Der Beginn einer Partie.
public enum NewGame {

    /// Erzeugt einen Spielstand mit einer Startkreatur.
    ///
    /// Persönlichkeit und Anlagen werden aus dem Startwert gewürfelt, nicht aus
    /// `Int.random` (ADR-006): Dieselbe Partie lässt sich damit exakt
    /// wiederherstellen — und ein Test kann sich auf sie berufen.
    public static func start(
        content: ContentBundle,
        speciesID: SpeciesID,
        seed: UInt64,
        deviceID: DeviceID,
        now: Date
    ) -> GameState {
        var random = RandomSource(seed: seed)

        let personality = rollPersonality(&random)
        let talents = rollTalents(&random)
        let creatureID = CreatureID("creature_\(seed)")

        let individual = CreatureIndividual(
            id: creatureID,
            speciesID: speciesID,
            personality: personality,
            talents: talents,
            variant: .standard,
            nickname: nil,
            bornAt: now,
            parents: []
        )

        let record = CreatureRecord(
            individual: individual,
            state: CreatureState(cursor: TimeCursor(startingAt: now))
        )

        let player = PlayerState(
            deviceID: deviceID,
            activeCreatureID: creatureID,
            random: random,
            cursor: TimeCursor(startingAt: now),
            firstPlayedAt: now
        )

        return GameState(player: player, creatures: [record])
    }

    // MARK: - Würfeln

    static func rollPersonality(_ source: inout RandomSource) -> Personality {
        var generator = source.generator(for: .spawn)
        var personality = Personality()

        for axis in PersonalityAxis.allCases {
            personality[axis] = Double(generator.next() % 101)
        }

        return personality
    }

    static func rollTalents(_ source: inout RandomSource) -> CreatureTalents {
        var generator = source.generator(for: .spawn)

        return CreatureTalents(
            vitality: Int(generator.next() % 6),
            power: Int(generator.next() % 6),
            resilience: Int(generator.next() % 6),
            speed: Int(generator.next() % 6)
        )
    }
}
