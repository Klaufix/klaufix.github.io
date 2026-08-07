import Foundation
import GameContent
import GameCore

// `CreatureTalents` ist nach GameCore gewandert: Die Zucht vererbt die Anlagen
// und der Kampf liest sie, und ein System darf ein anderes nicht importieren.
// Gemeinsame Wertetypen gehoeren deshalb in den Kern. Ueber `import GameCore`
// steht der Typ hier unveraendert zur Verfuegung.

/// Die individuelle Ebene: was bei der Entstehung festgelegt wurde und sich
/// nicht mehr aendert.
public struct CreatureIndividual: Sendable, Hashable, Codable, Identifiable {
    public let id: CreatureID
    /// Die Art wechselt bei einer Entwicklung - das Individuum bleibt dasselbe.
    /// Genau deshalb sind Art und Individuum getrennt: Der Spieler soll *seine*
    /// Kreatur behalten, nicht eine neue bekommen.
    public var speciesID: SpeciesID
    public let personality: Personality
    public let talents: CreatureTalents
    public let variant: CreatureVariant
    public var nickname: String?
    public let bornAt: Date
    /// Abstammung fuer den Stammbaum im Album.
    public let parents: [CreatureID]

    public init(
        id: CreatureID,
        speciesID: SpeciesID,
        personality: Personality,
        talents: CreatureTalents,
        variant: CreatureVariant = .standard,
        nickname: String? = nil,
        bornAt: Date,
        parents: [CreatureID] = []
    ) {
        self.id = id
        self.speciesID = speciesID
        self.personality = personality
        self.talents = talents
        self.variant = variant
        self.nickname = nickname
        self.bornAt = bornAt
        self.parents = parents
    }
}

public struct Needs: Sendable, Hashable, Codable {
    public var satiation: NeedValue
    public var energy: NeedValue
    public var tiredness: NeedValue
    public var mood: NeedValue
    public var health: NeedValue

    public init(
        satiation: NeedValue = NeedValue(80),
        energy: NeedValue = NeedValue(80),
        tiredness: NeedValue = NeedValue(20),
        mood: NeedValue = NeedValue(80),
        health: NeedValue = NeedValue(100)
    ) {
        self.satiation = satiation
        self.energy = energy
        self.tiredness = tiredness
        self.mood = mood
        self.health = health
    }

    public subscript(kind: NeedKind) -> NeedValue {
        get {
            switch kind {
            case .satiation: satiation
            case .energy: energy
            case .tiredness: tiredness
            case .mood: mood
            case .health: health
            }
        }
        set {
            switch kind {
            case .satiation: satiation = newValue
            case .energy: energy = newValue
            case .tiredness: tiredness = newValue
            case .mood: mood = newValue
            case .health: health = newValue
            }
        }
    }
}

/// Ein voruebergehender Zustand mit Ablaufdatum.
///
/// Es gibt keinen Zustand ohne `expiresAt`. Ein Dauerleiden waere eine Strafe,
/// und Strafen gibt es nicht - nur Aufgaben, die vorbeigehen.
public struct ActiveCondition: Sendable, Hashable, Codable {
    public let condition: CreatureCondition
    public let startedAt: Date
    public let expiresAt: Date

    public init(condition: CreatureCondition, startedAt: Date, expiresAt: Date) {
        self.condition = condition
        self.startedAt = startedAt
        self.expiresAt = expiresAt
    }

    public func isActive(at date: Date) -> Bool { date < expiresAt }
}

/// Die veraenderliche Ebene.
public struct CreatureState: Sendable, Hashable, Codable {
    public var needs: Needs
    public var friendship: Friendship
    public var level: Int
    public var experience: Int
    public var isAsleep: Bool
    public var conditions: [ActiveCondition]
    /// Slot-Bezeichner auf Kleidungsstueck. Als Zeichenketten-Schluessel, damit
    /// der Spielstand lesbar bleibt.
    public var cosmetics: [String: CosmeticID]
    /// Bis wann die Zeit fuer diese Kreatur aufgeloest wurde.
    public var cursor: TimeCursor

    // Zaehler, die das Bedingungssystem abfragt.
    public var careActions: Int
    public var battlesWon: Int
    public var foodEatenByTag: [String: Int]

    public init(
        needs: Needs = Needs(),
        friendship: Friendship = Friendship(),
        level: Int = 1,
        experience: Int = 0,
        isAsleep: Bool = false,
        conditions: [ActiveCondition] = [],
        cosmetics: [String: CosmeticID] = [:],
        cursor: TimeCursor,
        careActions: Int = 0,
        battlesWon: Int = 0,
        foodEatenByTag: [String: Int] = [:]
    ) {
        self.needs = needs
        self.friendship = friendship
        self.level = level
        self.experience = experience
        self.isAsleep = isAsleep
        self.conditions = conditions
        self.cosmetics = cosmetics
        self.cursor = cursor
        self.careActions = careActions
        self.battlesWon = battlesWon
        self.foodEatenByTag = foodEatenByTag
    }

    public func cosmetic(in slot: CosmeticSlot) -> CosmeticID? {
        cosmetics[slot.rawValue]
    }

    public func activeConditions(at date: Date) -> [ActiveCondition] {
        conditions.filter { $0.isActive(at: date) }
    }
}

/// Individuum und Zustand zusammen - die Form, in der der Spielstand Kreaturen
/// haelt.
public struct CreatureRecord: Sendable, Hashable, Codable, Identifiable {
    public var individual: CreatureIndividual
    public var state: CreatureState

    public var id: CreatureID { individual.id }

    public init(individual: CreatureIndividual, state: CreatureState) {
        self.individual = individual
        self.state = state
    }
}
