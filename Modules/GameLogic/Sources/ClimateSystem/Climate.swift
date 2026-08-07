import Foundation
import GameContent
import GameCore

/// Jahreszeiten, Wetter und die Zerlegung der Zeit in Abschnitte.
///
/// Das Wetter wird **zustandslos** bestimmt: aus Startwert, Zeitfenster und
/// Jahreszeit. Es gibt keine gespeicherte Wetterhistorie, und trotzdem liefert
/// jede Abfrage für denselben Zeitpunkt dasselbe Ergebnis — auch rückwirkend.
/// Genau das braucht die Zeitauflösung, wenn sie zwei Wochen Abwesenheit
/// nachträglich durchrechnet.
public struct Climate: Sendable {
    private let definition: ClimateDefinition
    private let seed: UInt64
    private let calendar: Calendar

    public init(definition: ClimateDefinition, seed: UInt64, calendar: Calendar = .current) {
        self.definition = definition
        self.seed = seed
        self.calendar = calendar
    }

    // MARK: - Jahreszeit

    public func season(at date: Date, hemisphere: Hemisphere = .northern) -> Season {
        let month = calendar.component(.month, from: date)
        let northern: Season

        switch month {
        case 3, 4, 5: northern = .spring
        case 6, 7, 8: northern = .summer
        case 9, 10, 11: northern = .autumn
        default: northern = .winter
        }

        return hemisphere == .northern ? northern : northern.opposite
    }

    // MARK: - Wetter

    /// Das Zeitfenster, in dem ein Zeitpunkt liegt. Innerhalb eines Fensters
    /// bleibt das Wetter gleich.
    func slot(at date: Date) -> Int64 {
        let seconds = Double(max(definition.slotHours, 1)) * 3600
        return Int64((date.timeIntervalSince1970 / seconds).rounded(.down))
    }

    public func weather(at date: Date, hemisphere: Hemisphere = .northern) -> WeatherID {
        weather(slot: slot(at: date), season: season(at: date, hemisphere: hemisphere))
    }

    func weather(slot: Int64, season: Season) -> WeatherID {
        // Nur Wetterlagen, die in dieser Jahreszeit vorkommen. Schnee im Juli
        // verhindert damit die Datentabelle, nicht eine Sonderregel im Code.
        let candidates = definition.weather
            .filter { $0.weight(in: season) > 0 }
            .sorted { $0.id.rawValue < $1.id.rawValue }

        guard !candidates.isEmpty else { return "sun" }

        let total = candidates.reduce(0) { $0 + $1.weight(in: season) }
        guard total > 0 else { return candidates[0].id }

        var pick = Int(mix(seed, UInt64(bitPattern: slot)) % UInt64(total))
        for candidate in candidates {
            pick -= candidate.weight(in: season)
            if pick < 0 { return candidate.id }
        }
        return candidates[candidates.count - 1].id
    }

    // MARK: - Zeitabschnitte

    /// Zerlegt einen Zeitraum in Stundenabschnitte mit ihren Rahmenbedingungen.
    ///
    /// „14 Tage weg" darf nicht als ein kontextloser Block verrechnet werden,
    /// sonst wachsen Winterpflanzen im Sommer weiter und eine Kreatur schläft
    /// zwei Wochen am Stück. Ein Abschnitt je Stunde ist grob genug, um billig
    /// zu bleiben (30 Tage = 720 Schritte), und fein genug für Tagesrhythmus
    /// und Wetterwechsel.
    public func segments(
        from start: Date,
        to end: Date,
        hemisphere: Hemisphere = .northern,
        maximumSegments: Int = 24 * 31
    ) -> [TimeSegment] {
        guard end > start else { return [] }

        var segments: [TimeSegment] = []
        var cursor = start

        while cursor < end, segments.count < maximumSegments {
            let next = min(cursor.addingTimeInterval(3600), end)
            let season = season(at: cursor, hemisphere: hemisphere)

            segments.append(
                TimeSegment(
                    start: cursor,
                    end: next,
                    season: season,
                    timeOfDay: TimeOfDay.from(hour: calendar.component(.hour, from: cursor)),
                    weather: weather(slot: slot(at: cursor), season: season)
                )
            )
            cursor = next
        }

        return segments
    }

    // MARK: - Intern

    /// Streuung von Startwert und Zeitfenster. Eigene Mischung statt `hashValue`,
    /// weil der pro Programmstart neu gesalzen wird — das Wetter der letzten
    /// Woche muss sich beim nächsten Start noch genauso ergeben.
    private func mix(_ seed: UInt64, _ value: UInt64) -> UInt64 {
        var z = seed ^ (value &* 0x9E37_79B9_7F4A_7C15)
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
