import Foundation
import GameCore
import Testing

@testable import SyncCore

/// Kennung aus dem Namen abgeleitet.
///
/// Dasselbe Ereignis in zwei Listen muss dieselbe Kennung haben, sonst prüft
/// der Test nichts. Bewusst über FNV statt über `hashValue`: Der ist pro
/// Programmstart neu gesalzen, und ein Test, der beim zweiten Lauf etwas
/// anderes prüft, ist schlimmer als keiner.
private func stableID(_ name: String) -> UUID {
    var hash: UInt64 = 0xCBF2_9CE4_8422_2325
    for byte in name.utf8 {
        hash ^= UInt64(byte)
        hash = hash &* 0x0000_0100_0000_01B3
    }

    let digits = String(format: "%012llu", hash % 1_000_000_000_000)
    return UUID(uuidString: "00000000-0000-0000-0000-\(digits)") ?? UUID()
}

private func event(
    _ name: String,
    device: String,
    lamport: UInt64,
    at seconds: TimeInterval = 0
) -> EventEnvelope {
    EventEnvelope(
        id: stableID(name),
        type: name,
        deviceID: DeviceID(device),
        lamport: lamport,
        wallClock: Date(timeIntervalSince1970: 1_750_000_000 + seconds),
        payload: Data(name.utf8)
    )
}

@Suite("Ereignis-Journal")
struct EventJournalTests {

    @Test("Dasselbe Ereignis wird nicht zweimal aufgenommen")
    func appendIsIdempotent() {
        var journal = EventJournal()
        let single = event("fed", device: "a", lamport: 1)

        journal.append(single)
        journal.append(single)

        #expect(journal.entries.count == 1)
    }

    @Test("Zusammenführen meldet nur das, was wirklich neu war")
    func mergeReportsOnlyNew() {
        var journal = EventJournal(entries: [event("fed", device: "a", lamport: 1)])

        let applied = journal.merge([
            event("fed", device: "a", lamport: 1),
            event("petted", device: "b", lamport: 2),
        ])

        #expect(applied.count == 1)
        #expect(applied.first?.type == "petted")
    }

    @Test("Die Reihenfolge des Eintreffens ändert das Ergebnis nicht")
    func mergeIsOrderIndependent() {
        let first = event("fed", device: "a", lamport: 1)
        let second = event("petted", device: "b", lamport: 2)
        let third = event("slept", device: "a", lamport: 3)

        var forward = EventJournal()
        forward.merge([first, second, third])

        var backward = EventJournal()
        backward.merge([third, second, first])

        // Das ist die Kernzusage des Abgleichs: Zwei Geräte kommen zum selben
        // Spielstand, egal in welcher Reihenfolge die Pakete ankommen.
        #expect(forward.entries == backward.entries)
    }

    @Test("Zweimal zusammenführen ändert nichts")
    func mergeIsIdempotent() {
        let remote = [
            event("fed", device: "a", lamport: 1),
            event("petted", device: "b", lamport: 2),
        ]

        var journal = EventJournal()
        journal.merge(remote)
        let after = journal.entries
        let second = journal.merge(remote)

        #expect(second.isEmpty)
        #expect(journal.entries == after)
    }

    @Test("Bei gleicher Uhr entscheidet das Gerät, dann die Kennung")
    func tieBreakIsDeterministic() {
        var journal = EventJournal()

        journal.merge([
            event("z", device: "geraet-b", lamport: 5),
            event("a", device: "geraet-a", lamport: 5),
        ])

        // Ohne diese Ordnung kämen zwei Geräte bei gleicher logischer Uhr zu
        // unterschiedlichen Spielständen.
        #expect(journal.entries.first?.deviceID == "geraet-a")
    }

    @Test("Die nächste logische Uhr liegt über allem Bekannten")
    func nextLamportBeatsEverything() {
        var journal = EventJournal()
        journal.merge([event("fremd", device: "b", lamport: 42)])

        // Auch über dem, was gerade erst von der Gegenstelle kam.
        #expect(journal.nextLamport() == 43)
    }

    @Test("Der Zeiger trennt Gesehenes von Neuem")
    func cursorSeparatesSeen() {
        var journal = EventJournal()
        journal.merge([
            event("alt", device: "a", lamport: 1),
            event("neu", device: "a", lamport: 9),
        ])

        let pending = journal.entries(after: SyncCursor(lamport: 5))

        #expect(pending.count == 1)
        #expect(pending.first?.type == "neu")
    }

    @Test("Kappen entfernt nur, was beide Seiten gesehen haben")
    func pruningRespectsCursor() {
        var journal = EventJournal()
        journal.merge([
            event("alt", device: "a", lamport: 1),
            event("neu", device: "a", lamport: 9),
        ])

        journal.prune(upTo: SyncCursor(lamport: 5))

        // Ein Journal, das nie kürzer wird, wächst über Jahre ins Unbrauchbare -
        // gekappt wird trotzdem nur Bestätigtes.
        #expect(journal.entries.count == 1)
        #expect(journal.entries.first?.type == "neu")
    }

    @Test("Das Journal überlebt eine Kodier-Runde")
    func survivesRoundTrip() throws {
        var journal = EventJournal()
        journal.merge([event("fed", device: "a", lamport: 1)])
        journal.cursor = SyncCursor(lamport: 1)

        let decoded = try JSONDecoder().decode(
            EventJournal.self, from: JSONEncoder().encode(journal)
        )

        #expect(decoded == journal)
    }
}

@Suite("Abgleich")
struct SyncSessionTests {

    @Test("Fremde Ereignisse werden angewendet, eigene verschickt")
    func reconcileSplitsBothDirections() {
        var journal = EventJournal(entries: [event("meins", device: "a", lamport: 3)])

        let outcome = SyncSession.reconcile(
            journal: &journal,
            remote: [event("fremd", device: "b", lamport: 4)]
        )

        #expect(outcome.applied.map(\.type) == ["fremd"])
        #expect(outcome.pushed.map(\.type) == ["meins"])
    }

    @Test("Was die Gegenstelle schon hat, wird nicht noch einmal geschickt")
    func doesNotPushKnownEvents() {
        let shared = event("beide", device: "a", lamport: 2)
        var journal = EventJournal(entries: [shared])

        let outcome = SyncSession.reconcile(journal: &journal, remote: [shared])

        #expect(outcome.pushed.isEmpty)
        #expect(outcome.applied.isEmpty)
    }

    @Test("Der Zeiger steht danach auf dem höchsten bekannten Stand")
    func cursorAdvances() {
        var journal = EventJournal()

        let outcome = SyncSession.reconcile(
            journal: &journal,
            remote: [event("fremd", device: "b", lamport: 7)]
        )

        #expect(outcome.cursor.lamport == 7)
    }

    @Test("Ein zweiter Abgleich ohne Neues tut nichts")
    func secondPassIsQuiet() {
        var journal = EventJournal(entries: [event("meins", device: "a", lamport: 1)])
        let remote = [event("fremd", device: "b", lamport: 2)]

        _ = SyncSession.reconcile(journal: &journal, remote: remote)
        let second = SyncSession.reconcile(journal: &journal, remote: remote)

        #expect(second.applied.isEmpty)
        #expect(second.pushed.isEmpty)
    }

    @Test("Der Abgleich nimmt niemals etwas weg")
    func reconcileNeverRemoves() {
        var journal = EventJournal(entries: [
            event("meins-1", device: "a", lamport: 1),
            event("meins-2", device: "a", lamport: 2),
        ])
        let before = journal.entries.count

        _ = SyncSession.reconcile(
            journal: &journal,
            remote: [event("fremd", device: "b", lamport: 3)]
        )

        // Additiv, nie löschend: Ein Abgleich, der etwas wegnimmt, träfe
        // jemanden, der alles richtig gemacht hat.
        #expect(journal.entries.count == before + 1)
    }
}

@Suite("Abgleich ohne Konto")
struct LocalOnlyBackendTests {

    @Test("Ohne Backend läuft alles weiter, nur ohne Abgleich")
    func localOnlyIsHarmless() async throws {
        let backend = LocalOnlySyncBackend()

        try await backend.push(events: [event("fed", device: "a", lamport: 1)])
        let pulled = try await backend.pull(since: .beginning)
        let snapshot = try await backend.latestSnapshot()

        // Cloud ist Komfort, nicht Voraussetzung.
        #expect(pulled.isEmpty)
        #expect(snapshot == nil)
    }
}
