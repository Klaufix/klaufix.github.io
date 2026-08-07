import Foundation
import GameCore

/// Wie weit ein Gerät den Abgleich schon gesehen hat.
public struct SyncCursor: Sendable, Hashable, Codable {
    public var lamport: UInt64

    public init(lamport: UInt64 = 0) {
        self.lamport = lamport
    }

    public static let beginning = SyncCursor(lamport: 0)
}

/// Die Gegenstelle des Abgleichs.
///
/// Bewusst schmal: vier Methoden, keine Annahmen über CloudKit, Firebase oder
/// einen eigenen Dienst. Die Entscheidung für ein Backend soll ein Modul kosten,
/// nicht eine Woche.
public protocol SyncBackend: Sendable {
    /// Schickt Ereignisse zur Gegenstelle. Muss mehrfaches Schicken desselben
    /// Ereignisses vertragen.
    func push(events: [EventEnvelope]) async throws

    /// Holt alles, was seit dem Zeiger dazugekommen ist.
    func pull(since cursor: SyncCursor) async throws -> [EventEnvelope]

    /// Legt einen vollständigen Spielstand ab — die Rettungsleine, wenn ein
    /// Journal einmal nicht ausreicht.
    func uploadSnapshot(_ data: Data) async throws

    func latestSnapshot() async throws -> Data?
}

/// Kein Abgleich.
///
/// Die Voreinstellung, solange kein Konto angemeldet ist. Wichtig ist, dass das
/// Spiel damit vollständig funktioniert: Cloud ist Komfort, nicht Voraussetzung.
public struct LocalOnlySyncBackend: SyncBackend {
    public init() {}

    public func push(events: [EventEnvelope]) async throws {}
    public func pull(since cursor: SyncCursor) async throws -> [EventEnvelope] { [] }
    public func uploadSnapshot(_ data: Data) async throws {}
    public func latestSnapshot() async throws -> Data? { nil }
}

public enum SyncError: Error, CustomStringConvertible, Sendable {
    case notSignedIn
    case networkUnavailable
    case backendFailure(String)

    public var description: String {
        switch self {
        case .notSignedIn:
            "Nicht bei iCloud angemeldet. Das Spiel läuft weiter, nur ohne Abgleich."
        case .networkUnavailable:
            "Keine Verbindung. Der Abgleich wird später nachgeholt."
        case .backendFailure(let detail):
            "Abgleich fehlgeschlagen: \(detail)"
        }
    }
}
