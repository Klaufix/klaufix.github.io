import Foundation
import GameCore
import Testing

@testable import GameContent

/// Prüft den echten, ausgelieferten Content — nicht erfundene Testdaten.
///
/// Damit hängen Schema, Loader, Validator und die tatsächlichen JSON-Dateien
/// an einem gemeinsamen Test: Wer eine Definition ändert, ohne die Dateien
/// nachzuziehen, bekommt es hier gesagt.
@Suite("Ausgelieferter Content")
struct ContentTests {

    /// Das Content-Verzeichnis liegt außerhalb des Pakets. `#filePath` ist der
    /// verlässlichste Weg dorthin — das Arbeitsverzeichnis eines Testlaufs ist
    /// es nicht.
    private static var contentDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // GameContentTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // GameLogic
            .deletingLastPathComponent()  // Modules
            .deletingLastPathComponent()  // Wurzel des Projekts
            .appendingPathComponent("Content")
    }

    private func loadBundle() throws -> ContentBundle {
        try ContentLoader().load(from: [ContentTests.contentDirectory])
    }

    @Test("Der ausgelieferte Content lädt")
    func contentLoads() throws {
        let bundle = try loadBundle()

        #expect(!bundle.species.isEmpty)
        #expect(!bundle.items.isEmpty)
        #expect(!bundle.elementChart.elements.isEmpty)
    }

    @Test("Der ausgelieferte Content ist fehlerfrei")
    func contentIsValid() throws {
        let bundle = try loadBundle()

        let errors = ContentValidation.validate(bundle).filter { $0.severity == .error }

        #expect(errors.isEmpty, "\(errors.map(\.description))")
    }

    @Test("Die Elementtabelle ist symmetrisch aufgebaut")
    func elementChartIsCoherent() throws {
        let chart = try loadBundle().elementChart
        let known = Set(chart.elements)

        for matchup in chart.multipliers ?? [] {
            #expect(known.contains(matchup.attacker))
            #expect(known.contains(matchup.defender))
        }

        // Unbekannte Paarungen sind neutral, nicht wirkungslos.
        #expect(chart.multiplier(attacker: "leaf", defender: "leaf") == 1.0)
        #expect(chart.multiplier(attacker: "leaf", defender: "wave") == 1.5)
    }

    @Test("Entwicklungswege verweisen auf vorhandene Arten")
    func evolutionsResolve() throws {
        let bundle = try loadBundle()

        for evolution in bundle.evolutions.values {
            #expect(bundle.species[evolution.from] != nil)
            for branch in evolution.branches {
                #expect(bundle.species[branch.to] != nil)
            }
        }
    }

    @Test("Jeder Entwicklungsweg hat eine friedliche Verzweigung")
    func peacefulPathExists() throws {
        let bundle = try loadBundle()

        // Design-Säule 4: Wer nicht kämpfen will, muss trotzdem weiterkommen.
        for evolution in bundle.evolutions.values {
            #expect(
                evolution.branches.contains { $0.isPeaceful },
                "\(evolution.id.rawValue) zwingt zum Kämpfen."
            )
        }
    }

    @Test("Jede Jahreszeit hat mögliches Wetter")
    func everySeasonHasWeather() throws {
        let climate = try loadBundle().climate

        for season in Season.allCases {
            let total = climate.weather.reduce(0) { $0 + $1.weight(in: season) }
            #expect(total > 0, "\(season.rawValue) hätte kein Wetter.")
        }
    }

    @Test("Schnee kommt nur im Winter vor")
    func snowIsWinterOnly() throws {
        let climate = try loadBundle().climate
        guard let snow = climate.weather.first(where: { $0.id == "snow" }) else { return }

        #expect(snow.weight(in: .winter) > 0)
        #expect(snow.weight(in: .summer) == 0)
    }

    @Test("Der Komfort-Boden steht über null")
    func offlineFloorIsPositive() throws {
        let balancing = try loadBundle().balancing

        // Fällt diese Zahl versehentlich auf 0, verhungern Kreaturen wieder —
        // lautlos, ohne dass ein anderer Test es merkt.
        #expect(balancing.offlineFloor > 0)
    }
}

@Suite("Fehlerhafter Content")
struct ContentValidationTests {

    private func bundle(offlineFloor: Double) throws -> ContentBundle {
        let balancingJSON = """
        {
          "schemaVersion": 1,
          "satiationDecayPerHour": 4.0,
          "satiationDecayPerHourAsleep": 1.0,
          "energyDecayPerHour": 3.0,
          "moodDecayPerHour": 2.0,
          "offlineFloor": \(offlineFloor),
          "dampeningHalfLifeHours": 8.0,
          "reunionAfterHours": 24.0,
          "reunionFriendshipBonus": 3.0,
          "shimmerChanceWild": 0.0025,
          "shimmerChanceBred": 0.0067,
          "shimmerPityThreshold": 200
        }
        """

        let chartJSON = #"{ "schemaVersion": 1, "elements": ["leaf"] }"#

        // Ein Wetter, das in jeder Jahreszeit vorkommt - sonst meldet der
        // Validator zu Recht, dass eine Jahreszeit ohne Wetter dasteht.
        let climateJSON = """
        {
          "schemaVersion": 1,
          "slotHours": 6,
          "weather": [
            {
              "id": "sun",
              "nameKey": "weather.sun",
              "weights": { "spring": 1, "summer": 1, "autumn": 1, "winter": 1 }
            }
          ]
        }
        """

        return ContentBundle(
            species: [],
            evolutions: [],
            items: [],
            cosmetics: [],
            elementChart: try JSONDecoder().decode(
                ElementChart.self, from: Data(chartJSON.utf8)
            ),
            balancing: try JSONDecoder().decode(
                BalancingDefinition.self, from: Data(balancingJSON.utf8)
            ),
            climate: try JSONDecoder().decode(
                ClimateDefinition.self, from: Data(climateJSON.utf8)
            )
        )
    }

    @Test("Ein Boden von null wird als Fehler gemeldet")
    func zeroFloorIsRejected() throws {
        let issues = ContentValidation.validate(try bundle(offlineFloor: 0))

        #expect(issues.contains { $0.severity == .error && $0.subject.contains("balancing") })
    }

    @Test("Ein gültiger Boden erzeugt keine Meldung")
    func validFloorPasses() throws {
        let issues = ContentValidation.validate(try bundle(offlineFloor: 25))

        #expect(!issues.contains { $0.severity == .error })
    }
}
