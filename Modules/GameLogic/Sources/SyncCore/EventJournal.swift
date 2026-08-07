import Foundation
import GameCore

/// Das Ereignis-Journal.
///
/// Zwei Geräte, die dasselbe Spiel spielen, erzeugen zwei Listen von Tatsachen.
/// Der Abgleich besteht darin, sie zu einer zu machen — **ohne** dass die
/// Reihenfolge des Eintreffens das Ergebnis verändert. Genau dafür trägt jedes
/// Ereignis seit Phase 4 eine Kennung, eine Geräte-ID und eine logische Uhr.
public struct EventJournal: Sendable, Hashable, Codable {
    public private(set) var entries: [EventEnvelope]
    /// Wie weit dieses Gerät die Gegenstelle schon gesehen hat.
    public var cursor: SyncCursor

    public init(entries: [EventEnvelope] = [], cursor: SyncCursor = .beginning) {
        self.entries = EventJournal.ordered(EventJournal.deduplicated(entries))
        self.cursor = cursor
    }

    public var isEmpty: Bool { entries.isEmpty }

    /// Höchste bisher gesehene logische Uhr.
    public var highestLamport: UInt64 {
        entries.map(\.lamport).max() ?? 0
    }

    public mutating func append(_ event: EventEnvelope) {
        guard !entries.contains(where: { $0.id == event.id }) else { return }
        entries = EventJournal.ordered(entries + [event])
    }

    /// Führt fremde Ereignisse ein und meldet, was davon neu war.
    ///
    /// Der Rückgabewert ist das, was die Engine noch anwenden muss — alles
    /// andere kannte sie schon.
    @discardableResult
    public mutating func merge(_ incoming: [EventEnvelope]) -> [EventEnvelope] {
        let known = Set(entries.map(\.id))
        let fresh = incoming.filter { !known.contains($0.id) }
        guard !fresh.isEmpty else { return [] }

        entries = EventJournal.ordered(EventJournal.deduplicated(entries + fresh))
        return EventJournal.ordered(EventJournal.deduplicated(fresh))
    }

    /// Alles ab einem Zeiger — das, was die Gegenstelle noch nicht hat.
    public func entries(after cursor: SyncCursor) -> [EventEnvelope] {
        entries.filter { $0.lamport > cursor.lamport }
    }

    /// Die nächste logische Uhr für ein eigenes Ereignis.
    ///
    /// Nach Lamport: höher als alles, was dieses Gerät kennt — auch höher als
    /// alles, was es gerade von der Gegenstelle bekommen hat.
    public func nextLamport() -> UInt64 {
        highestLamport &+ 1
    }

    /// Verwirft alte Einträge, deren Wirkung im Schnappschuss steckt.
    ///
    /// Ein Journal, das nie kürzer wird, wächst über Jahre ins Unbrauchbare.
    /// Gekappt wird nur, was **beide** Seiten gesehen haben — deshalb der
    /// Zeiger als Grenze und nicht ein Datum.
    public mutating func prune(upTo cursor: SyncCursor) {
        entries.removeAll { $0.lamport <= cursor.lamport }
    }

    // MARK: - Ordnung

    /// Dieselbe Reihenfolge auf jedem Gerät.
    ///
    /// Erst die logische Uhr, bei Gleichstand das Gerät, zuletzt die Kennung.
    /// Ohne den letzten Schritt könnten zwei Ereignisse desselben Geräts mit
    /// derselben Uhr unterschiedlich einsortiert werden — und zwei Geräte kämen
    /// zu unterschiedlichen Spielständen.
    static func ordered(_ events: [EventEnvelope]) -> [EventEnvelope] {
        events.sorted(by: EventEnvelope.mergeOrder)
    }

    static func deduplicated(_ events: [EventEnvelope]) -> [EventEnvelope] {
        var seen = Set<UUID>()
        var result: [EventEnvelope] = []

        for event in events where !seen.contains(event.id) {
            seen.insert(event.id)
            result.append(event)
        }

        return result
    }
}

/// Der Ablauf eines Abgleichs.
///
/// Bewusst als reine Funktion über Listen statt als Methode auf einem Dienst:
/// So lässt sich die Zusammenführung ohne Netzwerk, ohne Konto und ohne
/// Apple-Plattform prüfen — und genau das ist der Teil, der stimmen muss.
public enum SyncSession {

    public struct Outcome: Sendable, Hashable {
        /// Was von der Gegenstelle neu dazukam und angewendet werden muss.
        public var applied: [EventEnvelope]
        /// Was zur Gegenstelle geschickt werden muss.
        public var pushed: [EventEnvelope]
        public var cursor: SyncCursor

        public init(
            applied: [EventEnvelope] = [],
            pushed: [EventEnvelope] = [],
            cursor: SyncCursor = .beginning
        ) {
            self.applied = applied
            self.pushed = pushed
            self.cursor = cursor
        }
    }

    /// Führt lokales Journal und fremde Ereignisse zusammen.
    ///
    /// **Additiv, nie löschend.** Wenn zwei Geräte dieselbe Kreatur
    /// weiterentwickelt haben, behält der Spieler beides. Ein Abgleich, der
    /// etwas wegnimmt, wäre die schlimmste Form von Bestrafung — sie träfe
    /// jemanden, der alles richtig gemacht hat.
    public static func reconcile(
        journal: inout EventJournal,
        remote: [EventEnvelope]
    ) -> Outcome {
        let cursorBefore = journal.cursor
        let applied = journal.merge(remote)
        let pushed = journal.entries(after: cursorBefore).filter { event in
            !remote.contains { $0.id == event.id }
        }

        journal.cursor = SyncCursor(lamport: journal.highestLamport)

        return Outcome(applied: applied, pushed: pushed, cursor: journal.cursor)
    }
}
