import Foundation
import GameContent
import GameCore
import Testing

@testable import CreatureSystem

@Suite("Kreaturen-Datenmodell")
struct CreatureModelTests {

    private let birth = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeRecord() -> CreatureRecord {
        CreatureRecord(
            individual: CreatureIndividual(
                id: "creature_1",
                speciesID: "sprout_youngling",
                personality: Personality(courage: 72, calm: 30),
                talents: CreatureTalents(vitality: 3, power: 5, resilience: 2, speed: 4),
                nickname: "Möhrchen",
                bornAt: birth
            ),
            state: CreatureState(cursor: TimeCursor(startingAt: birth))
        )
    }

    @Test("Anlagen bleiben im gültigen Bereich")
    func talentsAreClamped() {
        let talents = CreatureTalents(vitality: 99, power: -5, resilience: 3, speed: 0)

        #expect(talents.vitality == 5)
        #expect(talents.power == 0)
        #expect(talents.resilience == 3)
    }

    @Test("Eine Entwicklung wechselt die Art, nicht das Individuum")
    func evolutionKeepsIdentity() {
        var record = makeRecord()
        let originalID = record.id
        let originalBirth = record.individual.bornAt

        record.individual.speciesID = "sprout_adult_bloom"

        // Der Spieler behält seine Kreatur — er bekommt keine neue. Genau
        // deshalb sind Art und Individuum getrennte Ebenen.
        #expect(record.id == originalID)
        #expect(record.individual.bornAt == originalBirth)
        #expect(record.individual.nickname == "Möhrchen")
    }

    @Test("Bedürfnisse sind über ihre Art ansprechbar")
    func needsAreAddressableByKind() {
        var needs = Needs()

        needs[.satiation] = NeedValue(42)

        #expect(needs.satiation.value == 42)
        #expect(needs[.satiation].value == 42)
    }

    @Test("Zustände laufen ab")
    func conditionsExpire() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let condition = ActiveCondition(
            condition: .sniffles,
            startedAt: start,
            expiresAt: start.addingTimeInterval(3600)
        )

        #expect(condition.isActive(at: start.addingTimeInterval(1800)))
        #expect(!condition.isActive(at: start.addingTimeInterval(7200)))
    }

    @Test("Kein Zustand ohne Ablaufdatum")
    func everyConditionEnds() {
        var state = CreatureState(cursor: TimeCursor(startingAt: birth))
        state.conditions = [
            ActiveCondition(
                condition: .gloom,
                startedAt: birth,
                expiresAt: birth.addingTimeInterval(3600)
            )
        ]

        // Ein Dauerleiden wäre eine Strafe — der Typ lässt es gar nicht zu,
        // dieser Test hält die Absicht fest.
        #expect(state.activeConditions(at: birth.addingTimeInterval(7200)).isEmpty)
    }

    @Test("Der Spielstand überlebt eine Kodier-Runde")
    func recordSurvivesRoundTrip() throws {
        let original = makeRecord()

        let decoded = try JSONDecoder().decode(
            CreatureRecord.self,
            from: JSONEncoder().encode(original)
        )

        #expect(decoded == original)
    }

    @Test("Kleidung wird je Slot gehalten")
    func cosmeticsPerSlot() {
        var state = CreatureState(cursor: TimeCursor(startingAt: birth))

        state.cosmetics[CosmeticSlot.head.rawValue] = "straw_hat"

        #expect(state.cosmetic(in: .head) == "straw_hat")
        #expect(state.cosmetic(in: .back) == nil)
    }
}
