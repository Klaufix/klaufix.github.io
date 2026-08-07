import ClimateSystem
import CreatureSystem
import Foundation
import GameContent
import GameCore
import GameRules
import GameState

/// Was beim Öffnen der App aus der verstrichenen Zeit geworden ist.
public struct ResolveSummary: Sendable, Hashable {
    public var absenceHours: Double
    public var isReunion: Bool
    public var season: Season
    public var weather: WeatherID
    public var timeOfDay: TimeOfDay
    public var outcomes: [CreatureID: SimulationOutcome]

    public init(
        absenceHours: Double,
        isReunion: Bool,
        season: Season,
        weather: WeatherID,
        timeOfDay: TimeOfDay,
        outcomes: [CreatureID: SimulationOutcome]
    ) {
        self.absenceHours = absenceHours
        self.isReunion = isReunion
        self.season = season
        self.weather = weather
        self.timeOfDay = timeOfDay
        self.outcomes = outcomes
    }
}

/// Die Engine: nimmt Commands, erzeugt Events, wendet sie auf den Zustand an.
///
/// Bewusst **kein** `@Observable` und kein SwiftUI: Die Engine muss unter Linux
/// bauen und testbar bleiben. Die Oberfläche legt einen beobachtbaren Wrapper
/// darum — die Plattformgrenze zwingt zur sauberen Trennung, statt sie nur zu
/// empfehlen.
public struct GameEngine: Sendable {
    public private(set) var state: GameState
    public let content: ContentBundle
    public let climate: Climate
    public let hemisphere: Hemisphere
    /// Wird mitgeführt, damit Tests eine feste Zeitzone setzen können. Sonst
    /// hinge das Ergebnis davon ab, wo der Rechner steht.
    public let calendar: Calendar

    public init(
        state: GameState,
        content: ContentBundle,
        hemisphere: Hemisphere = .northern,
        calendar: Calendar = .current
    ) {
        self.state = state
        self.content = content
        self.hemisphere = hemisphere
        self.calendar = calendar
        self.climate = Climate(
            definition: content.climate,
            seed: state.player.random.seed,
            calendar: calendar
        )
    }

    // MARK: - Zeit

    /// Löst die verstrichene Zeit auf.
    ///
    /// Wird beim Start und bei Rückkehr aus dem Hintergrund gerufen. Es läuft
    /// kein Timer — die Zeit wird einmalig nachgerechnet.
    public mutating func resolveTime(now: Date) -> ResolveSummary {
        let absenceSeconds = state.player.cursor.absence(until: now)
        var outcomes: [CreatureID: SimulationOutcome] = [:]
        var reunion = false

        for index in state.creatures.indices {
            let record = state.creatures[index]
            guard let species = content.species[record.individual.speciesID] else { continue }

            let segments = climate.segments(
                from: record.state.cursor.lastResolvedAt,
                to: now,
                hemisphere: hemisphere
            )

            var updated = record
            let outcome = CreatureSimulation.advance(
                &updated,
                through: segments,
                species: species,
                balancing: content.balancing,
                now: now
            )
            state.creatures[index] = updated
            outcomes[record.id] = outcome
            reunion = reunion || outcome.isReunion
        }

        state.player.cursor.advance(to: now)

        return ResolveSummary(
            absenceHours: absenceSeconds / 3600,
            isReunion: reunion,
            season: climate.season(at: now, hemisphere: hemisphere),
            weather: climate.weather(at: now, hemisphere: hemisphere),
            timeOfDay: TimeOfDay.from(hour: calendar.component(.hour, from: now)),
            outcomes: outcomes
        )
    }

    // MARK: - Commands

    /// Nimmt eine Absicht entgegen und gibt die entstandenen Tatsachen zurück.
    ///
    /// Der Rückgabewert ist nicht nur Information: Aus ihm entsteht später das
    /// Journal, das den Cloud-Abgleich trägt. Deshalb erzeugt jede Handlung
    /// Events — auch dort, wo direktes Mutieren kürzer wäre.
    @discardableResult
    public mutating func perform(_ command: CareCommand) -> [CareEvent] {
        guard let index = index(of: creatureID(in: command)) else { return [] }
        let record = state.creatures[index]
        guard let species = content.species[record.individual.speciesID] else { return [] }

        let events = CareSystem.handle(
            command,
            record: record,
            species: species,
            content: content
        )

        for event in events {
            var updated = state.creatures[index]
            CareSystem.apply(event, to: &updated)
            state.creatures[index] = updated
        }

        state.player.lamport &+= UInt64(events.count)
        return events
    }

    // MARK: - Tatsachen

    /// Beantwortet die Fragen des Bedingungssystems aus dem Gesamtzustand.
    ///
    /// Genau hier bleiben die Systeme voneinander unabhängig: Das QuestSystem
    /// fragt nicht das BattleSystem nach gewonnenen Kämpfen — es fragt eine
    /// Tatsache ab.
    public func facts(for creatureID: CreatureID, now: Date) -> EngineFacts? {
        guard let record = state.creature(creatureID),
            let species = content.species[record.individual.speciesID]
        else { return nil }

        return EngineFacts(
            record: record,
            species: species,
            season: climate.season(at: now, hemisphere: hemisphere),
            weather: climate.weather(at: now, hemisphere: hemisphere),
            timeOfDay: TimeOfDay.from(hour: calendar.component(.hour, from: now)),
            albumCount: 0,
            now: now
        )
    }

    // MARK: - Intern

    private func index(of id: CreatureID) -> Int? {
        state.creatures.firstIndex { $0.id == id }
    }

    private func creatureID(in command: CareCommand) -> CreatureID {
        switch command {
        case .feed(let id, _): id
        case .pet(let id): id
        case .putToSleep(let id): id
        case .wake(let id): id
        }
    }
}

/// Liest Tatsachen aus einem Kreaturen-Zustand.
public struct EngineFacts: FactProvider, Sendable {
    let record: CreatureRecord
    let species: SpeciesDefinition
    let season: Season
    let weather: WeatherID
    let timeOfDay: TimeOfDay
    let albumCount: Int
    let now: Date

    public func value(for fact: Fact) -> FactValue? {
        switch fact.key {
        case .level:
            return .number(Double(record.state.level))

        case .friendship:
            return .number(record.state.friendship.value)

        case .personality:
            guard let raw = fact.parameter, let axis = PersonalityAxis(rawValue: raw) else {
                return nil
            }
            return .number(record.individual.personality[axis])

        case .growthStage:
            return .text(species.growthStage.rawValue)

        case .element:
            return .text(species.element.rawValue)

        case .variant:
            return .text(record.individual.variant.rawValue)

        case .season:
            return .text(season.rawValue)

        case .weather:
            return .text(weather.rawValue)

        case .timeOfDay:
            return .text(timeOfDay.rawValue)

        case .daysOwned:
            return .number(now.timeIntervalSince(record.individual.bornAt) / 86_400)

        case .battlesWon:
            return .number(Double(record.state.battlesWon))

        case .careActionCount:
            return .number(Double(record.state.careActions))

        case .foodEatenCount:
            guard let tag = fact.parameter else { return nil }
            return .number(Double(record.state.foodEatenByTag[tag] ?? 0))

        case .equippedTag:
            // Getragene Kleidung als eine Zeichenkette; `contains` prüft darin.
            let worn = record.state.cosmetics.values.map(\.rawValue).sorted()
            return .text(worn.joined(separator: ","))

        case .albumDiscoveredCount:
            return .number(Double(albumCount))

        case .moonPhase, .dungeonCleared, .questCompleted, .itemUsed:
            // Noch keine Quelle. Eine unbekannte Tatsache gilt nie als erfüllt -
            // lieber eine Evolution später als eine geschenkt.
            return nil
        }
    }
}
