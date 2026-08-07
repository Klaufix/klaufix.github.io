import AlbumSystem
import BreedingSystem
import CreatureSystem
import Foundation
import GameContent
import GameCore
import Testing

@testable import GameEngine

private let origin = Date(timeIntervalSince1970: 1_750_000_000)

private func makeProgressEngine(seed: UInt64 = 4711) -> GameEngine {
    let content = ContentBundle.sample
    let state = NewGame.start(
        content: content,
        speciesID: "sprout_youngling",
        seed: seed,
        deviceID: "test",
        now: origin
    )
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
    return GameEngine(state: state, content: content, calendar: calendar)
}

@Suite("Erfahrung")
struct GrowthTests {

    @Test("Pflege bringt Erfahrung")
    func careGivesExperience() {
        var engine = makeProgressEngine()
        let id = engine.state.activeCreature!.id

        engine.perform(.pet(id))

        #expect(engine.state.activeCreature!.state.experience > 0)
    }

    @Test("Genug Erfahrung hebt die Stufe")
    func experienceLevelsUp() {
        var engine = makeProgressEngine()
        let id = engine.state.activeCreature!.id

        for _ in 0..<40 {
            engine.perform(.pet(id))
        }

        #expect(engine.state.activeCreature!.state.level > 1)
    }

    @Test("Die Kurve steigt, aber bleibt endlich")
    func curveGrows() {
        #expect(Growth.experienceToAdvance(from: 1) < Growth.experienceToAdvance(from: 10))
        #expect(Growth.experienceToAdvance(from: 10) < Growth.experienceToAdvance(from: 30))
        #expect(Growth.experienceToAdvance(from: Growth.maximumLevel) == Int.max)
    }

    @Test("Die Höchststufe wird nicht überschritten")
    func maximumLevelHolds() {
        var state = CreatureState(cursor: TimeCursor(startingAt: origin))

        Growth.award(10_000_000, to: &state)

        #expect(state.level == Growth.maximumLevel)
    }

    @Test("Schlechte Stunden bringen keine Erfahrung, kosten aber auch keine")
    func unhealthyHoursGiveNothing() {
        var state = CreatureState(cursor: TimeCursor(startingAt: origin))
        state.needs.satiation = NeedValue(10)

        #expect(Growth.healthyHours(10, state: state) == 0)

        state.needs.satiation = NeedValue(80)
        #expect(Growth.healthyHours(10, state: state) == 10)
    }
}

@Suite("Entwicklung")
struct EvolutionTests {

    @Test("Sind die Bedingungen erfüllt, entwickelt sich die Kreatur")
    func evolutionTriggers() {
        var engine = makeProgressEngine()
        let id = engine.state.activeCreature!.id

        // Der Weg im Fixture verlangt Stufe 5 und Freundschaft 20 — beides
        // erreichbar durch reine Zuwendung, ohne einen einzigen Kampf.
        for _ in 0..<60 {
            engine.perform(.pet(id))
        }
        let events = engine.checkEvolutions(now: origin)

        #expect(!events.isEmpty)
        #expect(engine.state.activeCreature!.individual.speciesID == "sprout_adult_bloom")
    }

    @Test("Eine Entwicklung wechselt die Art, nicht das Individuum")
    func identitySurvivesEvolution() {
        var engine = makeProgressEngine()
        let id = engine.state.activeCreature!.id
        let personality = engine.state.activeCreature!.individual.personality
        let bornAt = engine.state.activeCreature!.individual.bornAt

        for _ in 0..<60 {
            engine.perform(.pet(id))
        }
        _ = engine.checkEvolutions(now: origin)

        let after = engine.state.activeCreature!
        #expect(after.id == id)
        #expect(after.individual.personality == personality)
        #expect(after.individual.bornAt == bornAt)
    }

    @Test("Ohne erfüllte Bedingungen passiert nichts")
    func noPrematureEvolution() {
        var engine = makeProgressEngine()

        let events = engine.checkEvolutions(now: origin)

        #expect(events.isEmpty)
        #expect(engine.state.activeCreature!.individual.speciesID == "sprout_youngling")
    }

    @Test("Offene Bedingungen werden als Hinweise gemeldet")
    func hintsExplainWhatIsMissing() {
        let engine = makeProgressEngine()
        let id = engine.state.activeCreature!.id

        let hints = engine.evolutionHints(for: id, now: origin)

        // Daraus macht das Album „dazu fehlt noch …" statt „gesperrt".
        #expect(!hints.isEmpty)
        #expect(hints.allSatisfy { !$0.isReachableNow })
        #expect(hints.contains { $0.isPeaceful })
    }

    @Test("Eine Entwicklung landet im Album")
    func evolutionIsRecorded() {
        var engine = makeProgressEngine()
        let id = engine.state.activeCreature!.id
        let before = engine.state.album.discoveredCount

        for _ in 0..<60 {
            engine.perform(.pet(id))
        }
        _ = engine.checkEvolutions(now: origin)

        #expect(engine.state.album.discoveredCount > before)
        #expect(engine.state.album.hasDiscovered("sprout_adult_bloom"))
    }
}

@Suite("Zucht in der Engine")
struct EngineBreedingTests {

    /// Baut eine Partie mit zwei ausgewachsenen Kreaturen.
    private func engineWithTwoAdults() -> GameEngine {
        var engine = makeProgressEngine()
        let content = engine.content
        let second = NewGame.start(
            content: content,
            speciesID: "sprout_adult_bloom",
            seed: 2,
            deviceID: "test",
            now: origin
        )
        engine.state.creatures.append(second.creatures[0])
        engine.state.creatures[0].individual.speciesID = "sprout_adult_bloom"
        return engine
    }

    @Test("Zwei ausgewachsene Kreaturen legen ein Ei")
    func breedingProducesEgg() {
        var engine = engineWithTwoAdults()
        let ids = engine.state.creatures.map(\.id)

        let result = engine.breed(ids[0], ids[1], now: origin)

        guard case .success = result else {
            Issue.record("Kein Ei entstanden.")
            return
        }
        #expect(engine.state.eggs.count == 1)
    }

    @Test("Ein reifes Ei schlüpft")
    func eggHatches() {
        var engine = engineWithTwoAdults()
        let ids = engine.state.creatures.map(\.id)
        _ = engine.breed(ids[0], ids[1], now: origin)
        let before = engine.state.creatures.count

        let hatched = engine.hatchDueEggs(now: origin.addingTimeInterval(60 * 60 * 24))

        #expect(hatched.count == 1)
        #expect(engine.state.creatures.count == before + 1)
        #expect(engine.state.eggs.isEmpty)
    }

    @Test("Ein Ei schlüpft nicht vor seiner Zeit")
    func eggNeedsTime() {
        var engine = engineWithTwoAdults()
        let ids = engine.state.creatures.map(\.id)
        _ = engine.breed(ids[0], ids[1], now: origin)

        #expect(engine.hatchDueEggs(now: origin).isEmpty)
        #expect(engine.state.eggs.count == 1)
    }

    @Test("Der Nachwuchs kennt seine Eltern")
    func offspringKnowsItsParents() {
        var engine = engineWithTwoAdults()
        let ids = engine.state.creatures.map(\.id)
        _ = engine.breed(ids[0], ids[1], now: origin)

        let hatched = engine.hatchDueEggs(now: origin.addingTimeInterval(60 * 60 * 24))
        let child = engine.state.creature(hatched[0])

        #expect(child?.individual.parents == [ids[0], ids[1]])
    }

    @Test("Zweimaliges Schlüpfen erzeugt keine zweite Kreatur")
    func hatchingIsIdempotent() {
        var engine = engineWithTwoAdults()
        let ids = engine.state.creatures.map(\.id)
        _ = engine.breed(ids[0], ids[1], now: origin)
        let later = origin.addingTimeInterval(60 * 60 * 24)

        _ = engine.hatchDueEggs(now: later)
        let count = engine.state.creatures.count
        _ = engine.hatchDueEggs(now: later)

        #expect(engine.state.creatures.count == count)
    }
}
