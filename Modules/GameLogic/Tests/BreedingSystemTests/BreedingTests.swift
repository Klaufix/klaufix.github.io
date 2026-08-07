import Foundation
import GameContent
import GameCore
import Testing

@testable import BreedingSystem

private func parent(
    _ id: CreatureID,
    species: SpeciesDefinition,
    personality: Personality = Personality(),
    talents: CreatureTalents = CreatureTalents()
) -> BreedingParent {
    BreedingParent(
        creatureID: id,
        species: species,
        personality: personality,
        talents: talents
    )
}

private let adult = ContentBundle.sample.species["sprout_adult_bloom"]!
private let youngling = ContentBundle.sample.species["sprout_youngling"]!
private let balancing = ContentBundle.sample.balancing
private let now = Date(timeIntervalSince1970: 1_750_000_000)

@Suite("Zucht")
struct BreedingTests {

    @Test("Zwei ausgewachsene Kreaturen legen ein Ei")
    func adultsProduceEgg() {
        var random = RandomSource(seed: 1)
        var pity = 0

        let result = BreedingSystem.pair(
            parent("a", species: adult),
            parent("b", species: adult),
            balancing: balancing,
            random: &random,
            pityCounter: &pity,
            now: now
        )

        guard case .success(let egg) = result else {
            Issue.record("Kein Ei entstanden.")
            return
        }
        #expect(egg.parents == ["a", "b"])
        #expect(egg.hatchesAt > egg.laidAt)
    }

    @Test("Jungtiere züchten nicht")
    func younglingsCannotBreed() {
        var random = RandomSource(seed: 1)
        var pity = 0

        let result = BreedingSystem.pair(
            parent("a", species: youngling),
            parent("b", species: adult),
            balancing: balancing,
            random: &random,
            pityCounter: &pity,
            now: now
        )

        #expect(result == .failure(.notAdult))
    }

    @Test("Eine Kreatur züchtet nicht mit sich selbst")
    func noSelfBreeding() {
        var random = RandomSource(seed: 1)
        var pity = 0

        let result = BreedingSystem.pair(
            parent("a", species: adult),
            parent("a", species: adult),
            balancing: balancing,
            random: &random,
            pityCounter: &pity,
            now: now
        )

        #expect(result == .failure(.sameCreature))
    }

    @Test("Derselbe Startwert ergibt dasselbe Ei")
    func breedingIsDeterministic() {
        func run() -> PendingEgg? {
            var random = RandomSource(seed: 77)
            var pity = 0
            guard
                case .success(let egg) = BreedingSystem.pair(
                    parent("a", species: adult),
                    parent("b", species: adult),
                    balancing: balancing,
                    random: &random,
                    pityCounter: &pity,
                    now: now
                )
            else { return nil }
            return egg
        }

        #expect(run() == run())
    }
}

@Suite("Vererbung")
struct InheritanceTests {

    @Test("Die Persönlichkeit liegt in der Nähe des Elternmittels")
    func personalityStaysNearBlend() {
        var generator = SeededRandom(seed: 5)
        let first = Personality(courage: 80, curiosity: 80, playfulness: 80, calm: 80,
                                stubbornness: 80)
        let second = Personality(courage: 20, curiosity: 20, playfulness: 20, calm: 20,
                                 stubbornness: 20)

        let child = BreedingSystem.inheritPersonality(first, second, using: &generator)

        // Mittelwert 50, Streuung ±10: Wiedererkennung mit Spielraum.
        for axis in PersonalityAxis.allCases {
            #expect(child[axis] >= 40)
            #expect(child[axis] <= 60)
        }
    }

    @Test("Anlagen erben den besseren Elternwert")
    func talentsInheritTheBetterValue() {
        var generator = SeededRandom(seed: 3)
        let first = CreatureTalents(vitality: 5, power: 0, resilience: 5, speed: 0)
        let second = CreatureTalents(vitality: 0, power: 5, resilience: 0, speed: 5)

        let child = BreedingSystem.inheritTalents(first, second, using: &generator)

        // Genau eine Anlage wird neu gewürfelt — sonst endete Zucht nach
        // wenigen Generationen bei lauter Fünfen.
        let values = [child.vitality, child.power, child.resilience, child.speed]
        #expect(values.filter { $0 == 5 }.count >= 3)
    }

    @Test("Anlagen bleiben im gültigen Bereich")
    func talentsStayInRange() {
        var generator = SeededRandom(seed: 9)
        let maxed = CreatureTalents(vitality: 5, power: 5, resilience: 5, speed: 5)

        let child = BreedingSystem.inheritTalents(maxed, maxed, using: &generator)

        for value in [child.vitality, child.power, child.resilience, child.speed] {
            #expect(value >= 0 && value <= 5)
        }
    }
}

@Suite("Mitleidszähler")
struct PityTests {

    @Test("Nach genug erfolglosen Bruten ist die nächste garantiert besonders")
    func pityGuarantees() {
        var generator = SeededRandom(seed: 11)
        var pity = balancing.shimmerPityThreshold

        let variant = BreedingSystem.rollVariant(
            balancing: balancing,
            pityCounter: &pity,
            using: &generator
        )

        // Zufall darf enttäuschen, aber nicht zermürben.
        #expect(variant == .shimmer)
        #expect(pity == 0)
    }

    @Test("Ohne Treffer zählt der Zähler hoch")
    func pityCounts() {
        var generator = SeededRandom(seed: 12)
        var pity = 0

        for _ in 0..<10 {
            _ = BreedingSystem.rollVariant(
                balancing: balancing,
                pityCounter: &pity,
                using: &generator
            )
        }

        // Bei 1:150 sind zehn Fehlschläge der Normalfall.
        #expect(pity > 0)
    }

    @Test("Die Reifezeit hängt an der Seltenheit")
    func incubationScalesWithRarity() {
        #expect(
            BreedingSystem.incubationHours(for: .common)
                < BreedingSystem.incubationHours(for: .mythic)
        )
    }

    @Test("Die Kennung des Schlüpflings hängt am Ei, nicht am Zufall")
    func hatchIDIsDerived() {
        // Voraussetzung für Idempotenz: Zweimaliges Anwenden desselben
        // Schlüpf-Events darf keine zweite Kreatur erzeugen.
        #expect(
            BreedingSystem.creatureID(forEgg: "egg_1") == BreedingSystem.creatureID(forEgg: "egg_1")
        )
        #expect(
            BreedingSystem.creatureID(forEgg: "egg_1") != BreedingSystem.creatureID(forEgg: "egg_2")
        )
    }
}
