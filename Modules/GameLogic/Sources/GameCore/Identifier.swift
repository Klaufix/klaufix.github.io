/// Ein typisierter Bezeichner.
///
/// Content-Dateien referenzieren einander ueber Zeichenketten. Ohne Typisierung
/// laesst sich eine Art-ID versehentlich dort einsetzen, wo eine Item-ID erwartet
/// wird - und das faellt erst im laufenden Spiel auf. `Identifier` haengt jedem
/// Bezeichner ueber einen Phantom-Typ eine Bedeutung an, ohne zur Laufzeit etwas
/// zu kosten: der Compiler lehnt die Verwechslung ab.
///
/// ```swift
/// let art: SpeciesID = "sprout"
/// let item: ItemID = art        // Compilerfehler - genau so soll es sein
/// ```
///
/// Kodiert wird ausschliesslich die Zeichenkette selbst, damit Content-Dateien
/// fuer Menschen lesbar und gut diffbar bleiben.
public struct Identifier<Tag: Sendable>: Sendable, Hashable, Codable,
                                          CustomStringConvertible,
                                          ExpressibleByStringLiteral {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }

    public init(from decoder: any Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var description: String { rawValue }
}

// MARK: - Bedeutungen
//
// Ein neuer Inhaltstyp bekommt hier eine Marke und einen Aliasnamen. Mehr ist
// nicht noetig - und mehr soll es auch nicht sein.

public enum SpeciesTag: Sendable {}
public enum CreatureTag: Sendable {}
public enum ElementTag: Sendable {}
public enum WeatherTag: Sendable {}
public enum EvolutionTag: Sendable {}
public enum DeviceTag: Sendable {}
public enum ItemTag: Sendable {}
public enum CosmeticTag: Sendable {}
public enum AbilityTag: Sendable {}
public enum QuestTag: Sendable {}
public enum DungeonTag: Sendable {}
public enum ChapterTag: Sendable {}
public enum AchievementTag: Sendable {}
public enum RegionTag: Sendable {}
public enum SeasonalEventTag: Sendable {}
public enum PaletteTag: Sendable {}
public enum AppearancePartTag: Sendable {}
public enum FeatureTag: Sendable {}

public typealias SpeciesID = Identifier<SpeciesTag>
public typealias CreatureID = Identifier<CreatureTag>

/// Elemente und Wetterarten sind bewusst **keine** Aufzaehlungen im Code, sondern
/// Content. Ein achtes Element oder eine sechste Wetterlage ist damit eine
/// Datendatei - kein Eingriff in zwoelf Systeme.
public typealias ElementID = Identifier<ElementTag>
public typealias WeatherID = Identifier<WeatherTag>

public typealias EvolutionID = Identifier<EvolutionTag>
public typealias DeviceID = Identifier<DeviceTag>
public typealias ItemID = Identifier<ItemTag>
public typealias CosmeticID = Identifier<CosmeticTag>
public typealias AbilityID = Identifier<AbilityTag>
public typealias QuestID = Identifier<QuestTag>
public typealias DungeonID = Identifier<DungeonTag>
public typealias ChapterID = Identifier<ChapterTag>
public typealias AchievementID = Identifier<AchievementTag>
public typealias RegionID = Identifier<RegionTag>
public typealias SeasonalEventID = Identifier<SeasonalEventTag>
public typealias PaletteID = Identifier<PaletteTag>
public typealias AppearancePartID = Identifier<AppearancePartTag>

/// Kennzeichnet ein freischaltbares System (Story-Fortschritt) oder ein
/// Entwicklungs-Feature-Flag. Die UI kennt nur eine einzige Abfrage fuer beides.
public typealias FeatureID = Identifier<FeatureTag>
