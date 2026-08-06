import GameCore

/// Jede Content-Datei traegt ihre Schema-Version. Der Loader kann dadurch alte
/// Dateien migrieren, statt sie abzulehnen.
public enum ContentSchema {
    public static let current = 1
}

// MARK: - Hinweis zur Schreibweise
//
// Felder, die eine Content-Datei weglassen darf, sind hier `Optional` und haben
// daneben einen Zugriff mit Standardwert. Das ist kein Stilspleen: Swift setzt
// bei synthetisiertem Codable *keine* Default-Werte ein, wenn ein Schluessel
// fehlt - es wirft. Ohne Optionals muesste also jede Art-Datei jedes Feld
// auffuehren, auch die vier, die sie nicht braucht.

/// Eine Art.
///
/// Unveraenderliche Ebene des Kreaturen-Modells: Was fuer alle Exemplare dieser
/// Art gilt. Alles Individuelle (Persoenlichkeit, Anlagen, Name) und alles
/// Veraenderliche (Beduerfnisse, Level) steht woanders.
public struct SpeciesDefinition: Sendable, Hashable, Codable, Identifiable {
    public let id: SpeciesID
    public let schemaVersion: Int

    /// Lokalisierungsschluessel - niemals Anzeigetext.
    public let nameKey: String
    public let descriptionKey: String

    public let element: ElementID
    public let rarity: Rarity
    public let growthStage: GrowthStage

    public let baseStats: BaseStats
    public let preferences: SpeciesPreferences?
    public let appearance: AppearanceDefinition

    /// Wo diese Art gefunden werden kann - fuer Album und Spawn-Tabellen.
    public let habitats: [String]?

    /// Inhalte werden nie geloescht, nur ausgemustert: Spielstaende verweisen
    /// auf ihre IDs.
    public let retired: Bool?

    public var isRetired: Bool { retired ?? false }
    public var foundIn: [String] { habitats ?? [] }
    public var likes: SpeciesPreferences { preferences ?? SpeciesPreferences() }
}

public struct BaseStats: Sendable, Hashable, Codable {
    public let vitality: Int
    public let power: Int
    public let resilience: Int
    public let speed: Int
}

/// Vorlieben machen den Unterschied zwischen „Statusbalken" und „Wesen".
public struct SpeciesPreferences: Sendable, Hashable, Codable {
    public let favoriteFoodTags: [String]?
    public let dislikedFoodTags: [String]?
    public let favoriteWeather: [WeatherID]?
    /// Wann diese Art schlafen moechte (Stunde, 0-23).
    public let sleepsFrom: Int?
    public let sleepsUntil: Int?

    public init(
        favoriteFoodTags: [String]? = nil,
        dislikedFoodTags: [String]? = nil,
        favoriteWeather: [WeatherID]? = nil,
        sleepsFrom: Int? = nil,
        sleepsUntil: Int? = nil
    ) {
        self.favoriteFoodTags = favoriteFoodTags
        self.dislikedFoodTags = dislikedFoodTags
        self.favoriteWeather = favoriteWeather
        self.sleepsFrom = sleepsFrom
        self.sleepsUntil = sleepsUntil
    }

    public var loves: [String] { favoriteFoodTags ?? [] }
    public var dislikes: [String] { dislikedFoodTags ?? [] }
    public var goodWeather: [WeatherID] { favoriteWeather ?? [] }
    public var bedtimeHour: Int { sleepsFrom ?? 22 }
    public var wakeHour: Int { sleepsUntil ?? 6 }
}

public struct AppearanceDefinition: Sendable, Hashable, Codable {
    public let silhouette: String
    public let parts: [AppearancePartID]?
    public let defaultPalette: PaletteID
    /// Weitere Paletten je Variante - eine Schimmerform kostet damit eine
    /// Farbtabelle statt einer neuen Zeichnung.
    public let variantPalettes: [String: PaletteID]?

    public func palette(for variant: CreatureVariant) -> PaletteID {
        variantPalettes?[variant.rawValue] ?? defaultPalette
    }
}

/// Ein Entwicklungsweg.
///
/// Die Verzweigungen werden in Reihenfolge geprueft; die erste erfuellte
/// gewinnt. Dadurch kann ein seltener Sonderweg vor dem Standardweg stehen.
public struct EvolutionDefinition: Sendable, Hashable, Codable, Identifiable {
    public let id: EvolutionID
    public let schemaVersion: Int
    public let from: SpeciesID
    public let branches: [EvolutionBranch]
}

public struct EvolutionBranch: Sendable, Hashable, Codable {
    public let to: SpeciesID
    public let requires: ConditionExpression
    /// Hinweistext im Album, solange die Bedingung nicht erfuellt ist.
    /// Aus einer unerfuellten Bedingung wird so ein Raetsel statt einer Sperre.
    public let hintKey: String
    /// Ob dieser Weg ohne Kaempfe erreichbar ist. Der Validator besteht darauf,
    /// dass jede Art mindestens einen solchen Weg hat - Cozy-Spieler duerfen
    /// nie zum Kaempfen gezwungen werden (Design-Saeule 4).
    public let peaceful: Bool?

    public var isPeaceful: Bool { peaceful ?? false }
}

public enum ItemKind: String, Sendable, Codable, CaseIterable {
    case food
    case medicine
    case material
    case tool
    case egg
}

public struct ItemDefinition: Sendable, Hashable, Codable, Identifiable {
    public let id: ItemID
    public let schemaVersion: Int
    public let nameKey: String
    public let kind: ItemKind
    public let tags: [String]?
    public let stackSize: Int?
    /// Wirkung auf Beduerfnisse. Bewusst eine Tabelle statt fester Felder:
    /// ein Item, das Stimmung *und* Energie gibt, braucht keinen neuen Typ.
    public let effects: [NeedEffect]?
    public let retired: Bool?

    public var allTags: [String] { tags ?? [] }
    public var maximumStack: Int { stackSize ?? 99 }
    public var allEffects: [NeedEffect] { effects ?? [] }
    public var isRetired: Bool { retired ?? false }
}

public enum NeedKind: String, Sendable, Codable, CaseIterable {
    case satiation
    case energy
    case tiredness
    case mood
    case health
}

public struct NeedEffect: Sendable, Hashable, Codable {
    public let need: NeedKind
    public let amount: Double
}

public enum CosmeticSlot: String, Sendable, Codable, CaseIterable {
    case head
    case eyes
    case body
    case back
    case hand
    case ground
}

/// Kleidung ist rein kosmetisch. Die einzige mechanische Wirkung sind ihre
/// `tags`: Evolutionen und Vorlieben duerfen darauf reagieren. Das ist ein
/// Freischaltweg, kein Machtvorteil - und deshalb kein Pay-to-Win.
public struct CosmeticDefinition: Sendable, Hashable, Codable, Identifiable {
    public let id: CosmeticID
    public let schemaVersion: Int
    public let nameKey: String
    public let slot: CosmeticSlot
    public let tags: [String]?
    public let retired: Bool?

    public var allTags: [String] { tags ?? [] }
    public var isRetired: Bool { retired ?? false }
}

/// Die Elementtabelle als Inhalt statt als `switch`.
public struct ElementChart: Sendable, Hashable, Codable {
    public let schemaVersion: Int
    public let elements: [ElementID]
    /// Multiplikator je Angreifer-Element auf Verteidiger-Element.
    /// Fehlende Eintraege bedeuten neutral (1.0) - die Tabelle bleibt so klein.
    public let multipliers: [ElementMatchup]?

    public func multiplier(attacker: ElementID, defender: ElementID) -> Double {
        multipliers?
            .first { $0.attacker == attacker && $0.defender == defender }?
            .value ?? 1.0
    }
}

public struct ElementMatchup: Sendable, Hashable, Codable {
    public let attacker: ElementID
    public let defender: ElementID
    public let value: Double
}

/// Alle Zahlen, die das Spielgefuehl bestimmen - an einer Stelle, als Daten.
///
/// Hier sind alle Felder verpflichtend: Es gibt genau eine solche Datei, und
/// stillschweigende Standardwerte im Code waeren bei Balancing-Fragen die
/// schlechteste aller Antworten.
public struct BalancingDefinition: Sendable, Hashable, Codable {
    public let schemaVersion: Int

    /// Verfall je Stunde.
    public let satiationDecayPerHour: Double
    public let satiationDecayPerHourAsleep: Double
    public let energyDecayPerHour: Double
    public let moodDecayPerHour: Double

    /// Der Komfort-Korridor: Unter diesen Wert faellt nichts durch blossen
    /// Zeitablauf. Das ist die Zahl, die „keine Bestrafung" konkret macht.
    public let offlineFloor: Double

    /// Daempfung des Offline-Verfalls: Nach dieser Zeit halbiert sich die Rate,
    /// danach erneut. Zwei Wochen Abwesenheit kosten dadurch kaum mehr als zwei
    /// Tage.
    public let dampeningHalfLifeHours: Double

    /// Ab dieser Abwesenheit gibt es eine Rueckkehr-Szene statt eines Vorwurfs.
    public let reunionAfterHours: Double
    public let reunionFriendshipBonus: Double

    public let shimmerChanceWild: Double
    public let shimmerChanceBred: Double
    /// Nach so vielen erfolglosen Bruten ist die naechste garantiert besonders.
    public let shimmerPityThreshold: Int
}
