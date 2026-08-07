/// Ein Beduerfniswert zwischen 0 und 100.
///
/// Der Wert kann konstruktionsbedingt nicht ausserhalb seiner Grenzen liegen -
/// auch nicht beim Dekodieren eines beschaedigten Spielstands. Ein defekter Save
/// ergibt dadurch einen unschoenen, aber gueltigen Zustand statt einer Kreatur
/// mit -40 Saettigung.
public struct NeedValue: Sendable, Hashable, Codable, Comparable {
    public static let minimum: Double = 0
    public static let maximum: Double = 100

    public private(set) var value: Double

    public init(_ value: Double) {
        self.value = NeedValue.clamped(value)
    }

    /// Verschiebt den Wert und meldet zurueck, wie viel davon tatsaechlich
    /// angekommen ist. Wer 30 Saettigung fuettert, obwohl nur 10 fehlen,
    /// soll die Differenz kennen - etwa um Ueberfuetterung zu erkennen.
    @discardableResult
    public mutating func adjust(by delta: Double) -> Double {
        let before = value
        value = NeedValue.clamped(value + delta)
        return value - before
    }

    /// Verfall gegen einen Boden. Der Wert faellt nie darunter, egal wie lange
    /// niemand nach der Kreatur gesehen hat (Design-Saeule 3).
    ///
    /// Der Boden haelt auf, er hebt nicht an: Wer durch aktives Spiel bereits
    /// unter dem Boden liegt, wird durch Zeitablauf weder tiefer gesenkt noch
    /// geschenkweise aufgefuellt.
    public mutating func decay(by amount: Double, notBelow floor: Double) {
        guard amount > 0, amount.isFinite else { return }
        let target = max(NeedValue.clamped(value - amount), NeedValue.clamped(floor))
        value = min(value, target)
    }

    public var fraction: Double { value / NeedValue.maximum }

    public static func < (lhs: NeedValue, rhs: NeedValue) -> Bool {
        lhs.value < rhs.value
    }

    /// Unendlichkeiten werden nach ihrem Vorzeichen begrenzt: `+∞` bedeutet
    /// „weit ueber dem Maximum", nicht „ganz unten". Nur `NaN` hat keine
    /// sinnvolle Lage und faellt auf das Minimum zurueck.
    private static func clamped(_ raw: Double) -> Double {
        guard !raw.isNaN else { return minimum }
        return min(max(raw, minimum), maximum)
    }

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(Double.self)
        self.init(raw)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

/// Die Freundschaft einer Kreatur zum Spieler.
///
/// Dieser Typ hat absichtlich **keine** Methode, die den Wert senkt. Die
/// Design-Regel „Freundschaft sinkt nie" ist damit keine Verabredung, an die
/// sich zwoelf Systeme erinnern muessen, sondern eine Eigenschaft des Typs:
/// Ein Rueckschritt laesst sich nicht einmal versehentlich hinschreiben.
public struct Friendship: Sendable, Hashable, Codable, Comparable {
    public static let maximum: Double = 100

    public private(set) var value: Double

    public init(_ value: Double = 0) {
        self.value = Friendship.clamped(value)
    }

    /// Einzige Veraenderung, die dieser Typ zulaesst.
    @discardableResult
    public mutating func increase(by amount: Double) -> Double {
        guard amount > 0, amount.isFinite else { return 0 }
        let before = value
        value = Friendship.clamped(value + amount)
        return value - before
    }

    /// Stufen dienen als Aufhaenger fuer Erinnerungs-Szenen und Freischaltungen.
    public var stage: Int { Int(value / 20) }

    public static func < (lhs: Friendship, rhs: Friendship) -> Bool {
        lhs.value < rhs.value
    }

    private static func clamped(_ raw: Double) -> Double {
        guard !raw.isNaN else { return 0 }
        return min(max(raw, 0), maximum)
    }

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(Double.self)
        self.init(raw)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

/// Verdeckte Anlagen, 0-5 je Wert.
///
/// Sie sind der Grund, warum zwei Exemplare derselben Art sich unterschiedlich
/// anfuehlen, ohne dass der Spieler Zahlen vergleichen muss.
///
/// Liegt im Kern und nicht im CreatureSystem, weil mehrere Systeme sie brauchen:
/// Die Zucht vererbt sie, der Kampf liest sie. Ein System darf ein anderes nicht
/// importieren - gemeinsame Wertetypen gehoeren deshalb nach unten.
public struct CreatureTalents: Sendable, Hashable, Codable {
    public var vitality: Int
    public var power: Int
    public var resilience: Int
    public var speed: Int

    public init(vitality: Int = 0, power: Int = 0, resilience: Int = 0, speed: Int = 0) {
        self.vitality = CreatureTalents.clamped(vitality)
        self.power = CreatureTalents.clamped(power)
        self.resilience = CreatureTalents.clamped(resilience)
        self.speed = CreatureTalents.clamped(speed)
    }

    private static func clamped(_ raw: Int) -> Int { min(max(raw, 0), 5) }
}

/// Die fuenf Persoenlichkeitsachsen.
///
/// Sie sind fuer den Spieler nie als Zahl sichtbar - er sieht das abgeleitete
/// Temperament und vor allem das Verhalten der Kreatur.
public enum PersonalityAxis: String, Sendable, Codable, CaseIterable, Hashable {
    case courage
    case curiosity
    case playfulness
    case calm
    case stubbornness
}

public struct Personality: Sendable, Hashable, Codable {
    // Fuenf benannte Felder statt eines Woerterbuchs: Der Spielstand bleibt dadurch
    // lesbar, und eine fehlende Achse kann gar nicht erst entstehen.
    public private(set) var courage: Double
    public private(set) var curiosity: Double
    public private(set) var playfulness: Double
    public private(set) var calm: Double
    public private(set) var stubbornness: Double

    public init(
        courage: Double = 50,
        curiosity: Double = 50,
        playfulness: Double = 50,
        calm: Double = 50,
        stubbornness: Double = 50
    ) {
        self.courage = Personality.clamped(courage)
        self.curiosity = Personality.clamped(curiosity)
        self.playfulness = Personality.clamped(playfulness)
        self.calm = Personality.clamped(calm)
        self.stubbornness = Personality.clamped(stubbornness)
    }

    public subscript(axis: PersonalityAxis) -> Double {
        get {
            switch axis {
            case .courage: courage
            case .curiosity: curiosity
            case .playfulness: playfulness
            case .calm: calm
            case .stubbornness: stubbornness
            }
        }
        set {
            let value = Personality.clamped(newValue)
            switch axis {
            case .courage: courage = value
            case .curiosity: curiosity = value
            case .playfulness: playfulness = value
            case .calm: calm = value
            case .stubbornness: stubbornness = value
            }
        }
    }

    /// Die staerkste Auspraegung bestimmt das sichtbare Temperament-Etikett.
    /// Der Text selbst kommt aus der Lokalisierung, nicht von hier.
    public var dominantAxis: PersonalityAxis {
        PersonalityAxis.allCases.max { self[$0] < self[$1] } ?? .calm
    }

    /// Mittelwert zweier Eltern - die Grundlage der Vererbung. Die zufaellige
    /// Streuung kommt aus dem BreedingSystem, damit sie seedbar bleibt.
    public static func blend(_ first: Personality, _ second: Personality) -> Personality {
        var result = Personality()
        for axis in PersonalityAxis.allCases {
            result[axis] = (first[axis] + second[axis]) / 2
        }
        return result
    }

    private static func clamped(_ raw: Double) -> Double {
        // NaN landet bei einer Persoenlichkeit sinnvollerweise in der Mitte.
        guard !raw.isNaN else { return 50 }
        return min(max(raw, 0), 100)
    }
}
