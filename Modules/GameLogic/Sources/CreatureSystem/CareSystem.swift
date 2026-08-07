import Foundation
import GameContent
import GameCore

/// Eine Absicht des Spielers. Kann scheitern, verändert selbst nichts.
public enum CareCommand: GameCommand, Sendable, Hashable {
    case feed(CreatureID, ItemID)
    case pet(CreatureID)
    case putToSleep(CreatureID)
    case wake(CreatureID)
}

/// Eine Tatsache. Ist geschehen, kann nicht scheitern, ist idempotent anwendbar.
public enum CareEvent: GameEvent, Sendable {
    /// Traegt Wirkung und Tags **mit**, statt sie beim Anwenden im Content
    /// nachzuschlagen. Ein Event ist eine Tatsache: Wenn ein Balance-Update die
    /// Sonnenbeere spaeter schwaecher macht, darf das die letzte Woche nicht
    /// rueckwirkend veraendern. Genau daran haengt spaeter der Sync-Replay.
    case fed(
        creature: CreatureID,
        item: ItemID,
        effects: [NeedEffect],
        tags: [String],
        liked: Bool
    )
    case petted(creature: CreatureID, friendship: Double, mood: Double)
    case sleepChanged(creature: CreatureID, asleep: Bool)

    public static var eventType: String { "care" }

    public var creature: CreatureID {
        switch self {
        case .fed(let creature, _, _, _, _): creature
        case .petted(let creature, _, _): creature
        case .sleepChanged(let creature, _): creature
        }
    }
}

/// Pflege: die Handlungen, die den Kern des Spiels ausmachen.
///
/// Getrennt in `handle` (prüft Regeln, erzeugt Tatsachen) und `apply` (wendet
/// Tatsachen an). Diese Trennung ist der Grund, warum später ein Server
/// dieselben Commands prüfen kann, ohne dass die Spiellogik sich ändert.
public enum CareSystem {

    /// Wieviel Freundschaft eine Streicheleinheit bringt.
    static let pettingFriendship: Double = 1.5
    static let pettingMood: Double = 5
    /// Lieblingsessen macht zusätzlich Freude.
    static let likedFoodMood: Double = 8
    static let likedFoodFriendship: Double = 1.0

    public static func handle(
        _ command: CareCommand,
        record: CreatureRecord,
        species: SpeciesDefinition,
        content: ContentBundle
    ) -> [CareEvent] {
        switch command {
        case .feed(let id, let itemID):
            guard let item = content.items[itemID], item.kind == .food || item.kind == .medicine
            else { return [] }

            let liked = !Set(item.allTags).isDisjoint(with: Set(species.likes.loves))
            return [
                .fed(
                    creature: id,
                    item: itemID,
                    effects: item.allEffects,
                    tags: item.allTags,
                    liked: liked
                )
            ]

        case .pet(let id):
            // Streicheln ist nie „zu viel". Es gibt keinen Zustand, in dem
            // Zuwendung schadet.
            return [.petted(creature: id, friendship: pettingFriendship, mood: pettingMood)]

        case .putToSleep(let id):
            guard !record.state.isAsleep else { return [] }
            return [.sleepChanged(creature: id, asleep: true)]

        case .wake(let id):
            guard record.state.isAsleep else { return [] }
            return [.sleepChanged(creature: id, asleep: false)]
        }
    }

    public static func apply(_ event: CareEvent, to record: inout CreatureRecord) {
        switch event {
        case .fed(_, _, let effects, let tags, let liked):
            for effect in effects {
                record.state.needs[effect.need].adjust(by: effect.amount)
            }
            if liked {
                record.state.needs.mood.adjust(by: likedFoodMood)
                record.state.friendship.increase(by: likedFoodFriendship)
            }
            for tag in tags {
                record.state.foodEatenByTag[tag, default: 0] += 1
            }
            record.state.careActions += 1

        case .petted(_, let friendship, let mood):
            record.state.friendship.increase(by: friendship)
            record.state.needs.mood.adjust(by: mood)
            record.state.careActions += 1

        case .sleepChanged(_, let asleep):
            record.state.isAsleep = asleep
        }
    }
}
