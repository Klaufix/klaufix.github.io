import Foundation

/// Eine Absicht. Kann scheitern, veraendert selbst nichts.
public protocol GameCommand: Sendable {}

/// Eine Tatsache. Ist bereits geschehen, kann nicht scheitern.
///
/// Events muessen **idempotent** sein: Wer dasselbe Event zweimal anwendet, muss
/// denselben Zustand erhalten. Das ist keine Stilfrage, sondern die Voraussetzung
/// dafuer, dass zwei Geraete ihre Journale zusammenfuehren koennen, ohne dass ein
/// Ei doppelt schluepft. „+1 Item" ist deshalb kein gueltiges Event, „Belohnung
/// mit dieser ID eingesammelt" schon.
public protocol GameEvent: Sendable, Codable, Hashable {
    /// Stabiler Bezeichner des Event-Typs im Journal. Wird beim Dekodieren
    /// gebraucht und darf sich nie aendern - alte Spielstaende haengen daran.
    static var eventType: String { get }
}

/// Umschlag eines Events im Journal.
///
/// Die Felder sind schon jetzt vollstaendig, obwohl es noch keinen Sync gibt:
/// Sie nachtraeglich einzufuehren wuerde bedeuten, dass alte Journale sie nicht
/// haben - und genau die will man beim ersten Sync zusammenfuehren.
public struct EventEnvelope: Sendable, Hashable, Codable, Identifiable {
    public let id: UUID
    public let type: String
    public let deviceID: DeviceID
    /// Logische Uhr. Ordnet Ereignisse ueber Geraete hinweg, auch wenn deren
    /// Systemuhren auseinanderlaufen.
    public let lamport: UInt64
    public let wallClock: Date
    public let payload: Data

    public init(
        id: UUID = UUID(),
        type: String,
        deviceID: DeviceID,
        lamport: UInt64,
        wallClock: Date,
        payload: Data
    ) {
        self.id = id
        self.type = type
        self.deviceID = deviceID
        self.lamport = lamport
        self.wallClock = wallClock
        self.payload = payload
    }
}

extension EventEnvelope {
    /// Zusammenfuehrungs-Reihenfolge: erst logische Uhr, bei Gleichstand das
    /// Geraet, zuletzt die Event-ID. Das Ergebnis ist auf allen Geraeten gleich.
    public static func mergeOrder(_ lhs: EventEnvelope, _ rhs: EventEnvelope) -> Bool {
        if lhs.lamport != rhs.lamport { return lhs.lamport < rhs.lamport }
        if lhs.deviceID.rawValue != rhs.deviceID.rawValue {
            return lhs.deviceID.rawValue < rhs.deviceID.rawValue
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
