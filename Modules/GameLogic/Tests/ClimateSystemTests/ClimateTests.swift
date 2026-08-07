import Foundation
import GameContent
import GameCore
import Testing

@testable import ClimateSystem

private func utcCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
    return calendar
}

private func makeClimate(seed: UInt64 = 2026) -> Climate {
    Climate(
        definition: ContentBundle.sample.climate,
        seed: seed,
        calendar: utcCalendar()
    )
}

private func date(_ iso: String) -> Date {
    let formatter = DateFormatter()
    formatter.calendar = utcCalendar()
    formatter.timeZone = TimeZone(identifier: "UTC") ?? .gmt
    formatter.dateFormat = "yyyy-MM-dd HH:mm"
    return formatter.date(from: iso) ?? Date(timeIntervalSince1970: 0)
}

@Suite("Jahreszeiten")
struct SeasonTests {

    @Test("Der Monat bestimmt die Jahreszeit")
    func seasonFromMonth() {
        let climate = makeClimate()

        #expect(climate.season(at: date("2026-04-15 12:00")) == .spring)
        #expect(climate.season(at: date("2026-07-15 12:00")) == .summer)
        #expect(climate.season(at: date("2026-10-15 12:00")) == .autumn)
        #expect(climate.season(at: date("2026-01-15 12:00")) == .winter)
    }

    @Test("Auf der Südhalbkugel ist im Dezember Sommer")
    func southernHemisphereIsFlipped() {
        let climate = makeClimate()
        let december = date("2026-12-15 12:00")

        #expect(climate.season(at: december, hemisphere: .northern) == .winter)
        #expect(climate.season(at: december, hemisphere: .southern) == .summer)
    }
}

@Suite("Wetter")
struct WeatherTests {

    @Test("Dasselbe Zeitfenster ergibt immer dasselbe Wetter")
    func weatherIsStable() {
        let climate = makeClimate()
        let moment = date("2026-05-04 09:30")

        #expect(climate.weather(at: moment) == climate.weather(at: moment))
    }

    @Test("Innerhalb eines Zeitfensters bleibt das Wetter gleich")
    func weatherHoldsWithinSlot() {
        let climate = makeClimate()

        // Fensterlänge im Fixture: 6 Stunden.
        let first = climate.weather(at: date("2026-05-04 00:30"))
        let second = climate.weather(at: date("2026-05-04 05:30"))

        #expect(first == second)
    }

    @Test("Ein anderer Startwert ergibt einen anderen Wetterverlauf")
    func seedChangesWeather() {
        let a = makeClimate(seed: 1)
        let b = makeClimate(seed: 2)

        let days = (0..<40).map { offset -> Bool in
            let moment = date("2026-05-01 12:00").addingTimeInterval(Double(offset) * 86_400)
            return a.weather(at: moment) == b.weather(at: moment)
        }

        #expect(days.contains(false))
    }

    @Test("Es schneit nie im Sommer")
    func noSnowInSummer() {
        let climate = makeClimate()

        // Kein Sonderfall im Code: Die Gewichtstabelle im Content enthält für
        // den Sommer schlicht keinen Schnee.
        for offset in 0..<(31 * 4) {
            let moment = date("2026-07-01 00:00").addingTimeInterval(Double(offset) * 6 * 3600)
            #expect(climate.weather(at: moment) != "snow")
        }
    }

    @Test("Im Winter kommt Schnee vor")
    func snowHappensInWinter() {
        let climate = makeClimate()

        let sawSnow = (0..<(31 * 4)).contains { offset in
            let moment = date("2026-01-01 00:00").addingTimeInterval(Double(offset) * 6 * 3600)
            return climate.weather(at: moment) == "snow"
        }

        #expect(sawSnow)
    }
}

@Suite("Zeitabschnitte")
struct SegmentTests {

    @Test("Ein Tag ergibt 24 Stundenabschnitte")
    func oneDayIsTwentyFourSegments() {
        let climate = makeClimate()
        let start = date("2026-05-04 00:00")

        let segments = climate.segments(from: start, to: start.addingTimeInterval(86_400))

        #expect(segments.count == 24)
    }

    @Test("Die Abschnitte decken den Zeitraum lückenlos ab")
    func segmentsAreContiguous() {
        let climate = makeClimate()
        let start = date("2026-05-04 00:00")
        let end = start.addingTimeInterval(3600 * 10)

        let segments = climate.segments(from: start, to: end)

        #expect(segments.first?.start == start)
        #expect(segments.last?.end == end)
        for (earlier, later) in zip(segments, segments.dropFirst()) {
            #expect(earlier.end == later.start)
        }
    }

    @Test("Sehr lange Zeiträume werden gedeckelt statt unbegrenzt zerlegt")
    func segmentsAreCapped() {
        let climate = makeClimate()
        let start = date("2026-05-04 00:00")

        let segments = climate.segments(from: start, to: start.addingTimeInterval(86_400 * 400))

        #expect(segments.count == 24 * 31)
    }

    @Test("Ein rückwärts laufender Zeitraum ergibt keine Abschnitte")
    func backwardsRangeIsEmpty() {
        let climate = makeClimate()
        let start = date("2026-05-04 00:00")

        #expect(climate.segments(from: start, to: start.addingTimeInterval(-3600)).isEmpty)
    }

    @Test("Ein Abschnitt kennt Jahreszeit, Tageszeit und Wetter")
    func segmentsCarryContext() {
        let climate = makeClimate()
        let start = date("2026-01-10 23:00")

        let segments = climate.segments(from: start, to: start.addingTimeInterval(3600))

        #expect(segments.count == 1)
        #expect(segments[0].season == .winter)
        #expect(segments[0].timeOfDay == .night)
        #expect(segments[0].hours == 1)
    }
}
