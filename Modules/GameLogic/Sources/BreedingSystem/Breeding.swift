import Foundation
import GameContent
import GameCore

/// Was die Zucht von einem Elternteil wissen muss.
///
/// Bewusst **nicht** der ganze Kreaturen-Datensatz: `BreedingSystem` darf
/// `CreatureSystem` nicht importieren — Systeme kennen einander nicht. Diese
/// schmale Eingabe ist die Folge, und sie ist die bessere Schnittstelle: Die
/// Zucht braucht Abstammung, Wesen und Anlagen, sonst nichts.
public struct BreedingParent: Sendable, Hashable {
    public let creatureID: CreatureID
    public let species: SpeciesDefinition
    public let personality: Personality
    public let talents: CreatureTalents

    public init(
        creatureID: CreatureID,
        species: SpeciesDefinition,
        personality: Personality,
        talents: CreatureTalents
    ) {
        self.creatureID = creatureID
        self.species = species
        self.personality = personality
        self.talents = talents
    }
}

/// Ein gelegtes Ei, das reift.
public struct PendingEgg: Sendable, Hashable, Codable, Identifiable {
    public let id: EggID
    public let speciesID: SpeciesID
    public let parents: [CreatureID]
    public let personality: Personality
    public let talents: CreatureTalents
    public let variant: CreatureVariant
    public let laidAt: Date
    public let hatchesAt: Date

    public init(
        id: EggID,
        speciesID: SpeciesID,
        parents: [CreatureID],
        personality: Personality,
        talents: CreatureTalents,
        variant: CreatureVariant,
        laidAt: Date,
        hatchesAt: Date
    ) {
        self.id = id
        self.speciesID = speciesID
        self.parents = parents
        self.personality = personality
        self.talents = talents
        self.variant = variant
        self.laidAt = laidAt
        self.hatchesAt = hatchesAt
    }

    public func isReady(at date: Date) -> Bool { date >= hatchesAt }

    /// Wie weit die Reifung ist, 0…1 — für die Anzeige.
    public func progress(at date: Date) -> Double {
        let total = hatchesAt.timeIntervalSince(laidAt)
        guard total > 0 else { return 1 }
        return min(max(date.timeIntervalSince(laidAt) / total, 0), 1)
    }
}

public enum BreedingEvent: GameEvent, Sendable {
    case eggLaid(PendingEgg)
    case eggHatched(egg: EggID, creature: CreatureID)

    public static var eventType: String { "breeding" }
}

public enum BreedingFailure: Error, Sendable, Hashable {
    case notAdult
    case sameCreature
}

/// Zucht mit Vererbung.
///
/// Kein Zufalls-Automat: Was die Eltern ausmacht, findet sich im Nachwuchs
/// wieder. Und kein Frust-Automat: Der Mitleidszähler garantiert nach einer
/// bekannten Zahl erfolgloser Bruten eine besondere Form. Zufall darf
/// enttäuschen, aber nicht zermürben.
public enum BreedingSystem {

    /// Wie lange ein Ei reift, je nach Seltenheit der Art.
    public static func incubationHours(for rarity: Rarity) -> Double {
        switch rarity {
        case .common: 2
        case .rare: 5
        case .epic: 8
        case .mythic: 12
        }
    }

    public static func pair(
        _ first: BreedingParent,
        _ second: BreedingParent,
        balancing: BalancingDefinition,
        random: inout RandomSource,
        pityCounter: inout Int,
        now: Date
    ) -> Result<PendingEgg, BreedingFailure> {
        guard first.creatureID != second.creatureID else { return .failure(.sameCreature) }
        guard first.species.growthStage.canBreed, second.species.growthStage.canBreed else {
            return .failure(.notAdult)
        }

        var generator = random.generator(for: .breeding)

        // Art: von einem Elternteil. Kreuzungsarten kommen später als
        // Datentabelle dazu, nicht als Sonderregel hier.
        let species = generator.next() % 2 == 0 ? first.species : second.species

        let personality = inheritPersonality(
            first.personality,
            second.personality,
            using: &generator
        )
        let talents = inheritTalents(first.talents, second.talents, using: &generator)
        let variant = rollVariant(
            balancing: balancing,
            pityCounter: &pityCounter,
            using: &generator
        )

        let hours = incubationHours(for: species.rarity)
        let serial = generator.next() % 100_000

        return .success(
            PendingEgg(
                id: EggID("egg_\(Int(now.timeIntervalSince1970))_\(serial)"),
                speciesID: species.id,
                parents: [first.creatureID, second.creatureID],
                personality: personality,
                talents: talents,
                variant: variant,
                laidAt: now,
                hatchesAt: now.addingTimeInterval(hours * 3600)
            )
        )
    }

    /// Die Kennung, die das geschlüpfte Wesen bekommt.
    ///
    /// Aus der Ei-Kennung abgeleitet statt frisch gewürfelt: So ergibt zweimaliges
    /// Anwenden desselben Schlüpf-Events dieselbe Kreatur — die Idempotenz, an
    /// der später der Cloud-Abgleich hängt.
    public static func creatureID(forEgg egg: EggID) -> CreatureID {
        CreatureID("creature_\(egg.rawValue)")
    }

    // MARK: - Vererbung

    /// Mittelwert der Eltern plus Streuung.
    ///
    /// Der Mittelwert sorgt für Wiedererkennung, die Streuung dafür, dass kein
    /// Nachkomme eine Kopie ist.
    static func inheritPersonality(
        _ first: Personality,
        _ second: Personality,
        using generator: inout SeededRandom
    ) -> Personality {
        var result = Personality.blend(first, second)

        for axis in PersonalityAxis.allCases {
            let drift = Double(generator.next() % 21) - 10
            result[axis] = result[axis] + drift
        }

        return result
    }

    /// Je Anlage der bessere Elternwert — bis auf eine, die neu gewürfelt wird.
    ///
    /// Ohne den Neuwurf endete Zucht nach wenigen Generationen bei lauter Fünfen
    /// und wäre danach vorbei.
    static func inheritTalents(
        _ first: CreatureTalents,
        _ second: CreatureTalents,
        using generator: inout SeededRandom
    ) -> CreatureTalents {
        var values = [
            max(first.vitality, second.vitality),
            max(first.power, second.power),
            max(first.resilience, second.resilience),
            max(first.speed, second.speed),
        ]

        let rerolled = Int(generator.next() % 4)
        values[rerolled] = Int(generator.next() % 6)

        return CreatureTalents(
            vitality: values[0],
            power: values[1],
            resilience: values[2],
            speed: values[3]
        )
    }

    /// Variante mit Mitleidszähler.
    static func rollVariant(
        balancing: BalancingDefinition,
        pityCounter: inout Int,
        using generator: inout SeededRandom
    ) -> CreatureVariant {
        if pityCounter >= balancing.shimmerPityThreshold {
            pityCounter = 0
            return .shimmer
        }

        let roll = Double(generator.next() % 1_000_000) / 1_000_000
        if roll < balancing.shimmerChanceBred {
            pityCounter = 0
            return .shimmer
        }

        pityCounter += 1
        return .standard
    }
}
