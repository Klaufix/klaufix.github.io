/// Wachstumsstufen. Fest im Code, weil die Reihenfolge Bedeutung hat und jedes
/// System sie kennt - anders als Elemente oder Wetterlagen, die reiner Inhalt sind.
public enum GrowthStage: String, Sendable, Codable, CaseIterable, Comparable {
    case egg
    case hatchling
    case youngling
    case adult
    case zenith

    public var order: Int {
        switch self {
        case .egg: 0
        case .hatchling: 1
        case .youngling: 2
        case .adult: 3
        case .zenith: 4
        }
    }

    /// Ab dieser Stufe darf gezuechtet werden.
    public var canBreed: Bool { order >= GrowthStage.adult.order }

    public static func < (lhs: GrowthStage, rhs: GrowthStage) -> Bool {
        lhs.order < rhs.order
    }
}

public enum Rarity: String, Sendable, Codable, CaseIterable, Comparable {
    case common
    case rare
    case epic
    case mythic

    public var order: Int {
        switch self {
        case .common: 0
        case .rare: 1
        case .epic: 2
        case .mythic: 3
        }
    }

    public static func < (lhs: Rarity, rhs: Rarity) -> Bool {
        lhs.order < rhs.order
    }
}

/// Varianten sind unabhaengig von der Seltenheit der Art: Auch eine gewoehnliche
/// Art kann als Schimmerform auftreten.
public enum CreatureVariant: String, Sendable, Codable, CaseIterable {
    case standard
    case shimmer
    case seasonal
    case event
}

public enum Season: String, Sendable, Codable, CaseIterable {
    case spring
    case summer
    case autumn
    case winter

    /// Der Kalender richtet sich nach der Hemisphaere des Spielers - auf der
    /// Suedhalbkugel ist im Dezember Sommer, und das Spiel soll das wissen.
    public var opposite: Season {
        switch self {
        case .spring: .autumn
        case .summer: .winter
        case .autumn: .spring
        case .winter: .summer
        }
    }
}

public enum TimeOfDay: String, Sendable, Codable, CaseIterable {
    case morning
    case day
    case evening
    case night

    /// Grobe Einteilung des Tages. Feinere Zeitfenster (etwa die Schlafenszeit
    /// einer Art) stehen im Content, nicht hier.
    public static func from(hour: Int) -> TimeOfDay {
        switch hour {
        case 5..<10: .morning
        case 10..<18: .day
        case 18..<22: .evening
        default: .night
        }
    }
}

public enum MoonPhase: String, Sendable, Codable, CaseIterable {
    case new
    case waxing
    case full
    case waning
}

/// Voruebergehende Zustaende einer Kreatur.
///
/// Jeder Zustand hat eine Loesung und ein Ende - keiner sperrt Inhalte.
/// Deshalb traegt jeder Eintrag eine Ablaufzeit statt eines Dauerzustands.
public enum CreatureCondition: String, Sendable, Codable, CaseIterable {
    case sniffles
    case tummyAche
    case gloom
    case exhausted
}
