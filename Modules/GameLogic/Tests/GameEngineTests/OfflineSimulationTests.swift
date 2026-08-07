import ClimateSystem
import CreatureSystem
import Foundation
import GameContent
import GameCore
import Testing

@testable import GameEngine

/// Baut eine Engine mit fester Ausgangslage und UTC-Kalender.
///
/// UTC ist hier kein Detail: Sonst hinge das Ergebnis von der Zeitzone des
/// Rechners ab, auf dem die Tests laufen — und der CI-Runner steht anderswo als
/// der Entwickler.
private func makeEngine(at date: Date, seed: UInt64 = 4711) -> GameEngine {
    let content = ContentBundle.sample
    let state = NewGame.start(
        content: content,
        speciesID: "sprout_youngling",
        seed: seed,
        deviceID: "test",
        now: date
    )
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
    return GameEngine(state: state, content: content, calendar: calendar)
}

/// Der wichtigste Test des Projekts: Was passiert, wenn jemand lange weg war?
///
/// Genau daran scheitert das Vorbild. Tamagotchi bestraft Abwesenheit — der
/// Grund, warum die meisten Exemplare in einer Schublade endeten. Diese Suite
/// hält fest, dass unser Spiel es anders macht: nicht als Absichtserklärung,
/// sondern als überprüfbare Zusage.
@Suite("Abwesenheit")
struct OfflineSimulationTests {

    private let start = Date(timeIntervalSince1970: 1_750_000_000)

    @Test("Eine Kreatur übersteht 30 Tage Abwesenheit ohne Schaden am Kern")
    func thirtyDaysOffline() {
        var engine = makeEngine(at: start)
        let floor = engine.content.balancing.offlineFloor

        _ = engine.resolveTime(now: start.addingTimeInterval(60 * 60 * 24 * 30))

        let needs = engine.state.activeCreature!.state.needs
        #expect(needs.satiation.value >= floor)
        #expect(needs.energy.value >= floor)
        #expect(needs.mood.value >= floor)
        // Gesundheit hat ihren eigenen, höheren Boden: krank ja, verloren nie.
        #expect(needs.health.value >= 40)
    }

    @Test("Zwei Wochen sind kaum schlimmer als zwei Tage")
    func longAbsenceIsNotProportional() {
        var short = makeEngine(at: start)
        var long = makeEngine(at: start)

        _ = short.resolveTime(now: start.addingTimeInterval(60 * 60 * 48))
        _ = long.resolveTime(now: start.addingTimeInterval(60 * 60 * 24 * 14))

        let shortSatiation = short.state.activeCreature!.state.needs.satiation.value
        let longSatiation = long.state.activeCreature!.state.needs.satiation.value

        #expect(longSatiation <= shortSatiation)
        #expect(shortSatiation - longSatiation < 5)
    }

    @Test("Nach längerer Abwesenheit gibt es ein Wiedersehen, keinen Vorwurf")
    func reunionInsteadOfPunishment() {
        var engine = makeEngine(at: start)
        let before = engine.state.activeCreature!.state.friendship.value

        let summary = engine.resolveTime(now: start.addingTimeInterval(60 * 60 * 30))

        #expect(summary.isReunion)
        #expect(engine.state.activeCreature!.state.friendship.value > before)
    }

    @Test("Kurze Abwesenheit löst keine Wiedersehen-Szene aus")
    func shortAbsenceIsQuiet() {
        var engine = makeEngine(at: start)

        let summary = engine.resolveTime(now: start.addingTimeInterval(60 * 60 * 3))

        #expect(!summary.isReunion)
    }

    @Test("Freundschaft sinkt auch über lange Abwesenheit nie")
    func friendshipNeverDrops() {
        var engine = makeEngine(at: start)
        let before = engine.state.activeCreature!.state.friendship.value

        _ = engine.resolveTime(now: start.addingTimeInterval(60 * 60 * 24 * 60))

        #expect(engine.state.activeCreature!.state.friendship.value >= before)
    }

    @Test("Eine zurückgestellte Uhr verändert nichts")
    func backwardsClockIsIgnored() {
        var engine = makeEngine(at: start)
        let before = engine.state.activeCreature!.state.needs

        _ = engine.resolveTime(now: start.addingTimeInterval(-60 * 60 * 24))

        #expect(engine.state.activeCreature!.state.needs == before)
    }

    @Test("Dieselbe Ausgangslage ergibt exakt dasselbe Ergebnis")
    func simulationIsDeterministic() {
        var first = makeEngine(at: start)
        var second = makeEngine(at: start)
        let later = start.addingTimeInterval(60 * 60 * 100)

        _ = first.resolveTime(now: later)
        _ = second.resolveTime(now: later)

        #expect(first.state.activeCreature!.state == second.state.activeCreature!.state)
    }

    @Test("Die Sättigung sinkt über die Zeit überhaupt")
    func timeActuallyPasses() {
        var engine = makeEngine(at: start)
        let before = engine.state.activeCreature!.state.needs.satiation.value

        _ = engine.resolveTime(now: start.addingTimeInterval(60 * 60 * 6))

        // Ohne diesen Test wäre „nichts fällt unter den Boden" auch dann erfüllt,
        // wenn die Simulation gar nichts täte.
        #expect(engine.state.activeCreature!.state.needs.satiation.value < before)
    }

    @Test("Der Zeitzeiger steht danach auf jetzt")
    func cursorAdvances() {
        var engine = makeEngine(at: start)
        let now = start.addingTimeInterval(60 * 60 * 5)

        _ = engine.resolveTime(now: now)

        #expect(engine.state.activeCreature!.state.cursor.lastResolvedAt == now)
        #expect(engine.state.player.cursor.lastResolvedAt == now)
    }
}

@Suite("Pflege")
struct CareTests {

    private let start = Date(timeIntervalSince1970: 1_750_000_000)

    @Test("Füttern wirkt auf die Sättigung")
    func feedingFills() {
        var engine = makeEngine(at: start, seed: 99)
        let id = engine.state.activeCreature!.id

        // Erst Zeit vergehen lassen, damit überhaupt Platz zum Füttern ist.
        _ = engine.resolveTime(now: start.addingTimeInterval(60 * 60 * 12))
        let hungry = engine.state.activeCreature!.state.needs.satiation.value

        let events = engine.perform(.feed(id, "sun_berry"))

        #expect(!events.isEmpty)
        #expect(engine.state.activeCreature!.state.needs.satiation.value > hungry)
    }

    @Test("Lieblingsessen bringt zusätzlich Freude und Freundschaft")
    func favouriteFoodIsNoticed() {
        var engine = makeEngine(at: start, seed: 99)
        let id = engine.state.activeCreature!.id
        let before = engine.state.activeCreature!.state.friendship.value

        let events = engine.perform(.feed(id, "sun_berry"))

        guard case .fed(_, _, _, _, let liked)? = events.first else {
            Issue.record("Kein fed-Event erzeugt.")
            return
        }
        #expect(liked)
        #expect(engine.state.activeCreature!.state.friendship.value > before)
    }

    @Test("Ein unbekanntes Item erzeugt kein Event")
    func unknownItemDoesNothing() {
        var engine = makeEngine(at: start, seed: 99)
        let id = engine.state.activeCreature!.id

        #expect(engine.perform(.feed(id, "gibt_es_nicht")).isEmpty)
    }

    @Test("Streicheln ist nie zu viel")
    func pettingIsAlwaysWelcome() {
        var engine = makeEngine(at: start, seed: 99)
        let id = engine.state.activeCreature!.id

        for _ in 0..<50 {
            #expect(!engine.perform(.pet(id)).isEmpty)
        }

        // Es gibt keinen Zustand, in dem Zuwendung schadet oder abgelehnt wird.
        #expect(engine.state.activeCreature!.state.friendship.value > 0)
        #expect(engine.state.activeCreature!.state.careActions == 50)
    }

    @Test("Schlafen legen und wecken schalten um, doppelt aber nicht")
    func sleepToggles() {
        var engine = makeEngine(at: start, seed: 99)
        let id = engine.state.activeCreature!.id

        #expect(!engine.perform(.putToSleep(id)).isEmpty)
        #expect(engine.state.activeCreature!.state.isAsleep)
        // Nochmal schlafen legen ist keine neue Tatsache — also kein Event.
        #expect(engine.perform(.putToSleep(id)).isEmpty)
        #expect(!engine.perform(.wake(id)).isEmpty)
        #expect(!engine.state.activeCreature!.state.isAsleep)
    }

    @Test("Ein Event trägt alles mit, was es zum Anwenden braucht")
    func eventsCarryTheirOwnPayload() throws {
        let event = CareEvent.fed(
            creature: "c1",
            item: "sun_berry",
            effects: [NeedEffect(need: .satiation, amount: 30)],
            tags: ["sweet"],
            liked: true
        )

        // Voraussetzung dafür, dass es später aus dem Journal erneut angewendet
        // werden kann — auch wenn sich der Content inzwischen geändert hat.
        let decoded = try JSONDecoder().decode(
            CareEvent.self, from: JSONEncoder().encode(event)
        )

        #expect(decoded == event)
    }
}
