import Foundation
import GameCore
import Testing

@testable import GameRules

/// Ein Provider, dem man die Antworten vorgibt.
private struct StubFacts: FactProvider {
    var answers: [String: FactValue] = [:]

    func value(for fact: Fact) -> FactValue? {
        answers[key(for: fact)]
    }

    private func key(for fact: Fact) -> String {
        if let parameter = fact.parameter {
            return "\(fact.key.rawValue).\(parameter)"
        }
        return fact.key.rawValue
    }
}

@Suite("Bedingungs-Auswertung")
struct ConditionEvaluatorTests {

    private let facts = StubFacts(answers: [
        "level": .number(18),
        "friendship": .number(64),
        "personality.courage": .number(35),
        "season": .text("spring"),
        "weather": .text("rain"),
        "equippedTag": .text("summer,rustic,warm"),
    ])

    /// Kurzschreibweise, damit die Testfälle lesbar bleiben.
    private func holds(_ expression: ConditionExpression) -> Bool {
        ConditionEvaluator.isSatisfied(expression, by: facts)
    }

    @Test("Eine leere Bedingung ist erfüllt")
    func alwaysIsSatisfied() {
        #expect(holds(.always))
    }

    @Test("Zahlenvergleiche werten numerisch aus")
    func numericComparison() {
        #expect(holds(.fact(.level, .greaterOrEqual, .number(16))))
        #expect(!holds(.fact(.level, .greaterThan, .number(18))))
        #expect(holds(.fact(.level, .equal, .number(18))))
    }

    @Test("Ein Parameter unterscheidet Fragen derselben Art")
    func parameterisedFacts() {
        #expect(holds(.fact(.personality, parameter: "courage", .lessThan, .number(70))))

        // Nach einer Achse, die der Provider nicht kennt, wird nichts geschenkt.
        #expect(!holds(.fact(.personality, parameter: "calm", .greaterThan, .number(0))))
    }

    @Test("Text kennt Gleichheit und Enthaltensein")
    func textComparison() {
        #expect(holds(.fact(.season, .equal, .text("spring"))))
        #expect(holds(.fact(.equippedTag, .contains, .text("warm"))))
        #expect(!holds(.fact(.equippedTag, .contains, .text("festive"))))
    }

    @Test("Eine unbekannte Tatsache gilt nie als erfüllt")
    func unknownFactIsNeverSatisfied() {
        // Ein Tippfehler im Content darf keine Evolution verschenken - auch
        // nicht über die Hintertür einer Ungleichheit.
        #expect(!holds(.fact(.moonPhase, .equal, .text("full"))))
        #expect(!holds(.fact(.moonPhase, .notEqual, .text("full"))))
    }

    @Test("Typmischung ist ein Content-Fehler und nie erfüllt")
    func mismatchedTypesFail() {
        #expect(!holds(.fact(.level, .equal, .text("18"))))
    }

    @Test("all, any und not verknüpfen wie erwartet")
    func composition() {
        let expression = ConditionExpression.all([
            .fact(.level, .greaterOrEqual, .number(16)),
            .fact(.friendship, .greaterOrEqual, .number(60)),
            .any([
                .fact(.season, .equal, .text("winter")),
                .fact(.weather, .equal, .text("rain")),
            ]),
            .not(.fact(.season, .equal, .text("autumn"))),
        ])

        #expect(holds(expression))
    }

    @Test("Unerfüllte Einzelbedingungen werden als Hinweise gemeldet")
    func unmetChecksBecomeHints() {
        let expression = ConditionExpression.all([
            .fact(.level, .greaterOrEqual, .number(16)),      // erfüllt
            .fact(.friendship, .greaterOrEqual, .number(90)), // offen
            .fact(.battlesWon, .greaterOrEqual, .number(15)), // unbekannt, also offen
        ])

        let unmet = ConditionEvaluator.unmetChecks(in: expression, by: facts)

        // Das Album zeigt daraus „dazu fehlt noch …" statt „gesperrt".
        #expect(unmet.count == 2)
    }

    @Test("Eine erfüllte Bedingung hinterlässt keine Hinweise")
    func satisfiedExpressionHasNoHints() {
        #expect(
            ConditionEvaluator.unmetChecks(
                in: .fact(.level, .greaterOrEqual, .number(16)),
                by: facts
            ).isEmpty
        )
    }
}

@Suite("Bedingungen aus Content lesen")
struct ConditionCodingTests {

    @Test("Die JSON-Form aus dem Content-Handbuch wird verstanden")
    func decodesAuthoringFormat() throws {
        let json = """
        { "all": [
            { "fact": "level", "op": ">=", "value": 16 },
            { "fact": "personality", "parameter": "courage", "op": ">=", "value": 70 },
            { "any": [
                { "fact": "season", "op": "==", "value": "spring" },
                { "fact": "weather", "op": "==", "value": "fog" }
            ] }
        ] }
        """

        let expression = try JSONDecoder().decode(
            ConditionExpression.self,
            from: Data(json.utf8)
        )

        guard case .all(let parts) = expression else {
            Issue.record("Erwartet wurde eine all-Verknüpfung.")
            return
        }
        #expect(parts.count == 3)
    }

    @Test("Kodieren und Dekodieren ergibt denselben Ausdruck")
    func roundTrip() throws {
        let original = ConditionExpression.all([
            .fact(.level, .greaterOrEqual, .number(16)),
            .not(.fact(.weather, .equal, .text("snow"))),
            .always,
        ])

        let decoded = try JSONDecoder().decode(
            ConditionExpression.self,
            from: JSONEncoder().encode(original)
        )

        #expect(decoded == original)
    }

    @Test("Eine unvollständige Bedingung wird abgelehnt statt stillschweigend ignoriert")
    func rejectsIncompleteCondition() {
        let json = #"{ "fact": "level" }"#

        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(ConditionExpression.self, from: Data(json.utf8))
        }
    }
}
