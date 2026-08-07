import Foundation
import GameContent
import GameCore

public struct AlbumEntry: Sendable, Hashable, Codable {
    public let speciesID: SpeciesID
    public var firstSeenAt: Date
    /// Entdeckte Varianten als Rohwerte, damit der Spielstand lesbar bleibt.
    public var variants: Set<String>
    public var timesOwned: Int

    public init(
        speciesID: SpeciesID,
        firstSeenAt: Date,
        variants: Set<String> = [],
        timesOwned: Int = 0
    ) {
        self.speciesID = speciesID
        self.firstSeenAt = firstSeenAt
        self.variants = variants
        self.timesOwned = timesOwned
    }

    public func hasSeen(_ variant: CreatureVariant) -> Bool {
        variants.contains(variant.rawValue)
    }
}

public enum AlbumEvent: GameEvent, Sendable {
    case discovered(species: SpeciesID, variant: CreatureVariant, at: Date)

    public static var eventType: String { "album" }
}

/// Das Sammelalbum.
///
/// Es ist der eigentliche Langzeitmotor: Nicht Wiederholung hält Spieler, sondern
/// die Frage, was es sonst noch gibt. Deshalb speichert es **Entdeckungen**, nie
/// Verluste — ein Eintrag verschwindet nie wieder, auch wenn die Kreatur längst
/// weitergezogen oder weiterentwickelt ist.
public struct AlbumState: Sendable, Hashable, Codable {
    /// Nach Art-Kennung, als Zeichenkette — lesbarer Spielstand.
    public private(set) var entries: [String: AlbumEntry]

    public init(entries: [String: AlbumEntry] = [:]) {
        self.entries = entries
    }

    public var discoveredCount: Int { entries.count }

    public func entry(for species: SpeciesID) -> AlbumEntry? {
        entries[species.rawValue]
    }

    public func hasDiscovered(_ species: SpeciesID) -> Bool {
        entries[species.rawValue] != nil
    }

    /// Trägt eine Entdeckung ein.
    ///
    /// Idempotent: Zweimaliges Anwenden desselben Ereignisses ändert nichts
    /// außer dem Besitz-Zähler, und der ist bewusst additiv. Das ist die
    /// Voraussetzung dafür, dass zwei Geräte ihre Journale zusammenführen
    /// können, ohne dass Einträge doppelt oder gar nicht entstehen.
    public mutating func apply(_ event: AlbumEvent) {
        switch event {
        case .discovered(let species, let variant, let date):
            if var existing = entries[species.rawValue] {
                existing.variants.insert(variant.rawValue)
                existing.firstSeenAt = min(existing.firstSeenAt, date)
                existing.timesOwned += 1
                entries[species.rawValue] = existing
            } else {
                entries[species.rawValue] = AlbumEntry(
                    speciesID: species,
                    firstSeenAt: date,
                    variants: [variant.rawValue],
                    timesOwned: 1
                )
            }
        }
    }
}

public enum AlbumSystem {

    /// Meilensteine als Anzahl entdeckter Arten.
    ///
    /// Bewusst früh und dicht am Anfang: Die ersten Belohnungen sollen kommen,
    /// bevor jemand sich fragt, wofür er sammelt.
    public static let milestones = [1, 3, 5, 10, 20, 35, 50]

    public static func reachedMilestone(discovered: Int) -> Int? {
        milestones.contains(discovered) ? discovered : nil
    }

    /// Fortschritt bis zum nächsten Meilenstein.
    public static func nextMilestone(after discovered: Int) -> Int? {
        milestones.first { $0 > discovered }
    }

    /// Was das Album über eine noch nicht entdeckte Art verrät.
    ///
    /// Nämlich: dass es sie gibt, und wo. Kein leerer Platzhalter — eine
    /// Silhouette mit Fundort ist eine Einladung, ein graues Feld ist keine.
    public static func teaser(for species: SpeciesDefinition) -> String {
        species.foundIn.first ?? "unbekannt"
    }
}
