import Foundation
import Testing

@testable import GameCore

/// Die Design-Säulen als Testfälle.
///
/// „Keine Bestrafung" ist als Absichtserklärung wertlos — in zwei Jahren erinnert
/// sich niemand mehr daran, warum irgendwo eine Untergrenze steht. Diese Tests
/// sind das Gedächtnis dafür: Wer die Regel bricht, bekommt einen roten Build
/// mit einer Begründung.
@Suite("Invarianten der Anti-Bestrafungs-Säule")
struct InvariantTests {

    @Test("Ein Bedürfnis verlässt seinen Wertebereich nie")
    func needStaysInRange() {
        var need = NeedValue(50)

        need.adjust(by: 500)
        #expect(need.value == 100)

        need.adjust(by: -500)
        #expect(need.value == 0)

        #expect(NeedValue(.nan).value == 0)
        #expect(NeedValue(.infinity).value == 100)
    }

    @Test("Verfall hält am Boden an, egal wie viel abgezogen wird")
    func decayRespectsFloor() {
        var need = NeedValue(90)

        need.decay(by: 1_000_000, notBelow: 25)

        #expect(need.value == 25)
    }

    @Test("Der Boden hält auf, aber hebt nicht an")
    func floorStopsButDoesNotLift() {
        var need = NeedValue(10)

        need.decay(by: 50, notBelow: 25)

        // Wer durch aktives Spiel unter den Boden gerutscht ist, fällt durch
        // Zeitablauf nicht tiefer — bekommt aber auch nichts geschenkt.
        #expect(need.value == 10)
    }

    @Test("Freundschaft kann nur steigen")
    func friendshipNeverDecreases() {
        var friendship = Friendship(40)

        friendship.increase(by: 10)
        #expect(friendship.value == 50)

        // Negative Beträge werden verworfen, statt zu senken.
        friendship.increase(by: -30)
        #expect(friendship.value == 50)

        friendship.increase(by: 1000)
        #expect(friendship.value == Friendship.maximum)
    }

    @Test("Zurückgestellte Uhr ergibt null Fortschritt, nie negativen")
    func clockCannotRunBackwards() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        var cursor = TimeCursor(startingAt: start)

        let elapsed = cursor.advance(to: start.addingTimeInterval(-86_400))

        #expect(elapsed == 0)
        #expect(cursor.lastResolvedAt == start)
    }

    @Test("Sehr lange Abwesenheit wird gedeckelt verrechnet")
    func longAbsenceIsCapped() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        var cursor = TimeCursor(startingAt: start)

        let elapsed = cursor.advance(to: start.addingTimeInterval(60 * 60 * 24 * 365))

        #expect(elapsed == TimeCursor.maximumJump)
    }

    @Test("Die tatsächliche Abwesenheit bleibt ablesbar, auch wenn sie gedeckelt verrechnet wird")
    func absenceIsReportedUncapped() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let cursor = TimeCursor(startingAt: start)
        let oneYear: TimeInterval = 60 * 60 * 24 * 365

        // Die Rückkehr-Szene braucht die echte Dauer: je länger weg,
        // desto herzlicher der Empfang.
        #expect(cursor.absence(until: start.addingTimeInterval(oneYear)) == oneYear)
    }
}

@Suite("Deterministischer Zufall")
struct RandomSourceTests {

    // Hinweis: `next()` ist mutierend. Die Werte werden deshalb vor dem
    // `#expect` in Konstanten gezogen - ein mutierender Aufruf innerhalb des
    // Makro-Ausdrucks wäre unnötig heikel.

    @Test("Gleicher Startwert ergibt gleiche Folge")
    func sameSeedSameSequence() {
        var first = RandomSource(seed: 42)
        var second = RandomSource(seed: 42)

        var a = first.generator(for: .breeding)
        var b = second.generator(for: .breeding)
        let left = a.next()
        let right = b.next()

        #expect(left == right)
    }

    @Test("Zwei Züge aus demselben Strom unterscheiden sich")
    func consecutiveDrawsDiffer() {
        var source = RandomSource(seed: 42)

        var first = source.generator(for: .loot)
        var second = source.generator(for: .loot)
        let left = first.next()
        let right = second.next()

        #expect(left != right)
        #expect(source.drawCount(for: .loot) == 2)
    }

    @Test("Ströme beeinflussen einander nicht")
    func streamsAreIndependent() {
        var withExtraDraw = RandomSource(seed: 7)
        var without = RandomSource(seed: 7)

        // Ein zusätzlicher Wurf beim Ausflug darf die nächste Zucht nicht
        // verschieben - sonst bricht jeder Zucht-Test, sobald jemand die
        // Beutetabelle anfasst.
        _ = withExtraDraw.generator(for: .expedition)

        var a = withExtraDraw.generator(for: .breeding)
        var b = without.generator(for: .breeding)
        let left = a.next()
        let right = b.next()

        #expect(left == right)
    }

    @Test("Der Spielstand überlebt eine Kodier-Runde mit identischer Fortsetzung")
    func survivesEncoding() throws {
        var source = RandomSource(seed: 99)
        _ = source.generator(for: .spawn)

        var restored = try JSONDecoder().decode(
            RandomSource.self,
            from: JSONEncoder().encode(source)
        )

        var a = source.generator(for: .spawn)
        var b = restored.generator(for: .spawn)
        let left = a.next()
        let right = b.next()

        #expect(left == right)
    }
}
