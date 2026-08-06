import Foundation

/// Zeitquelle. Als Protokoll, damit Tests die Uhr stellen koennen - eine
/// Simulation, die man nicht vorspulen kann, laesst sich nicht pruefen.
public protocol GameClock: Sendable {
    var now: Date { get }
}

public struct SystemClock: GameClock {
    public init() {}
    public var now: Date { Date() }
}

/// Feste Uhr fuer Tests.
public struct FixedClock: GameClock {
    public let now: Date
    public init(_ now: Date) { self.now = now }
}

/// Merkt sich, bis wann die Simulation aufgeloest wurde, und beantwortet die
/// Frage „wie viel Zeit ist seither vergangen?" - mit zwei Regeln:
///
/// 1. **Zeit laeuft nie rueckwaerts.** Wer die Geraeteuhr zurueckstellt, erhaelt
///    null Fortschritt, nie negativen. Der Zeiger bleibt einfach stehen.
/// 2. **Vorwaertsspruenge sind gedeckelt.** Mehr als 30 Tage werden nicht
///    verrechnet: Das begrenzt den Rechenaufwand und macht das Vorstellen der
///    Uhr uninteressant.
///
/// Beides ist bewusst keine Bestrafung: Manipulation wird ignoriert, nicht
/// geahndet (Design-Saeule 3).
public struct TimeCursor: Sendable, Hashable, Codable {
    /// 30 Tage.
    public static let maximumJump: TimeInterval = 60 * 60 * 24 * 30

    public private(set) var lastResolvedAt: Date

    public init(startingAt date: Date) {
        lastResolvedAt = date
    }

    /// Rueckt den Zeiger vor und liefert die zu verrechnende Dauer in Sekunden.
    @discardableResult
    public mutating func advance(to now: Date) -> TimeInterval {
        let elapsed = now.timeIntervalSince(lastResolvedAt)

        guard elapsed > 0 else {
            // Uhr zurueckgestellt oder kein Fortschritt: Zeiger bleibt stehen.
            return 0
        }

        let accounted = min(elapsed, TimeCursor.maximumJump)
        lastResolvedAt = now
        return accounted
    }

    /// Wie lange der Spieler weg war - unabhaengig davon, wie viel davon
    /// verrechnet wird. Grundlage fuer die Rueckkehr-Szene: je laenger,
    /// desto herzlicher der Empfang.
    public func absence(until now: Date) -> TimeInterval {
        max(0, now.timeIntervalSince(lastResolvedAt))
    }
}

/// Ein Abschnitt gleichbleibender Rahmenbedingungen.
///
/// „14 Tage weg" darf nicht als ein kontextloser Block verrechnet werden, sonst
/// wachsen Winterpflanzen im Sommer weiter. Die Engine zerlegt die verstrichene
/// Zeit deshalb an Tages-, Jahreszeit- und Wettergrenzen in Segmente und
/// verrechnet jedes einzeln.
public struct TimeSegment: Sendable, Hashable, Codable {
    public let start: Date
    public let end: Date
    public let season: Season
    public let timeOfDay: TimeOfDay
    public let weather: WeatherID

    public init(start: Date, end: Date, season: Season, timeOfDay: TimeOfDay, weather: WeatherID) {
        self.start = start
        self.end = end
        self.season = season
        self.timeOfDay = timeOfDay
        self.weather = weather
    }

    public var duration: TimeInterval { max(0, end.timeIntervalSince(start)) }
    public var hours: Double { duration / 3600 }
}
