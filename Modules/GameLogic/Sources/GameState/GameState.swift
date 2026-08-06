import CreatureSystem
import Foundation
import GameCore

/// Der Spielstand.
///
/// Ein zusammenhaengender Wertebaum - kein Objektgraph. Genau deshalb ist
/// Persistenz ein Snapshot und keine Datenbank (ADR-002): Der Zustand wird als
/// Ganzes deterministisch fortgeschrieben, gespeichert und wiederhergestellt.
///
/// `GameState` kennt die Systeme. Kein System kennt `GameState` - Systeme
/// arbeiten immer nur auf ihrem eigenen Teilzustand.
public struct GameState: Sendable, Hashable, Codable {
    /// Wird bei jeder Formatveraenderung erhoeht. Die Migrationskette in
    /// `Persistence` haengt daran.
    public static let currentVersion = 1

    public var saveVersion: Int
    public var player: PlayerState
    public var creatures: [CreatureRecord]

    public init(
        saveVersion: Int = GameState.currentVersion,
        player: PlayerState,
        creatures: [CreatureRecord] = []
    ) {
        self.saveVersion = saveVersion
        self.player = player
        self.creatures = creatures
    }

    public func creature(_ id: CreatureID) -> CreatureRecord? {
        creatures.first { $0.id == id }
    }

    public var activeCreature: CreatureRecord? {
        guard let id = player.activeCreatureID else { return creatures.first }
        return creature(id) ?? creatures.first
    }
}

public struct PlayerState: Sendable, Hashable, Codable {
    public let deviceID: DeviceID
    public var displayName: String?
    public var activeCreatureID: CreatureID?

    /// Startwert und Zaehlerstaende des Zufalls. Im Spielstand, damit ein
    /// Neustart der App dieselbe Folge fortsetzt statt neu zu wuerfeln.
    public var random: RandomSource

    /// Weltzeit-Zeiger fuer alles, was nicht an einer einzelnen Kreatur haengt:
    /// Pflanzen, Quest-Timer, Wetterverlauf.
    public var cursor: TimeCursor

    /// Logische Uhr fuer das Event-Journal. Schon vorhanden, obwohl es noch
    /// keinen Sync gibt: Nachtraeglich eingefuehrt haetten alte Journale sie
    /// nicht - und genau die sollen beim ersten Sync zusammengefuehrt werden.
    public var lamport: UInt64

    /// Freigeschaltete Systeme. Story-Fortschritt und Entwicklungs-Flags landen
    /// beide hier, damit die Oberflaeche nur eine Abfrage kennt.
    public var unlocks: Set<FeatureID>

    public var firstPlayedAt: Date

    public init(
        deviceID: DeviceID,
        displayName: String? = nil,
        activeCreatureID: CreatureID? = nil,
        random: RandomSource,
        cursor: TimeCursor,
        lamport: UInt64 = 0,
        unlocks: Set<FeatureID> = [],
        firstPlayedAt: Date
    ) {
        self.deviceID = deviceID
        self.displayName = displayName
        self.activeCreatureID = activeCreatureID
        self.random = random
        self.cursor = cursor
        self.lamport = lamport
        self.unlocks = unlocks
        self.firstPlayedAt = firstPlayedAt
    }

    public func isUnlocked(_ feature: FeatureID) -> Bool {
        unlocks.contains(feature)
    }

    /// Der Story-Skip schaltet schlicht alles frei - „ueberspringbar" heisst
    /// ueberspringbar, nicht „gesperrt, aber ohne Erklaerung".
    public mutating func unlockAll(_ features: [FeatureID]) {
        unlocks.formUnion(features)
    }
}
