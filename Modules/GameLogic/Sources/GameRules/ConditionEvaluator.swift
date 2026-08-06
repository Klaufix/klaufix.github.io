import GameCore

/// Liefert Antworten auf Fragen des Bedingungssystems.
///
/// Die Engine stellt einen Provider bereit, der die Fragen aus dem Gesamtzustand
/// beantwortet. Genau dadurch bleiben die Systeme voneinander unabhaengig: Das
/// QuestSystem fragt nicht das BattleSystem nach gewonnenen Kaempfen, es fragt
/// eine Tatsache ab.
public protocol FactProvider: Sendable {
    func value(for fact: Fact) -> FactValue?
}

public enum ConditionEvaluator {

    public static func isSatisfied(
        _ expression: ConditionExpression,
        by provider: some FactProvider
    ) -> Bool {
        switch expression {
        case .always:
            true
        case .all(let list):
            list.allSatisfy { isSatisfied($0, by: provider) }
        case .any(let list):
            list.contains { isSatisfied($0, by: provider) }
        case .not(let inner):
            !isSatisfied(inner, by: provider)
        case .check(let fact, let comparator, let expected):
            compare(provider.value(for: fact), comparator, expected)
        }
    }

    /// Alle Einzelbedingungen, die derzeit nicht erfuellt sind.
    ///
    /// Das Album zeigt daraus Hinweise statt Sperren: „Diese Entwicklung braucht
    /// noch Nebel" ist eine Einladung, „gesperrt" ist eine Wand.
    public static func unmetChecks(
        in expression: ConditionExpression,
        by provider: some FactProvider
    ) -> [ConditionExpression] {
        guard !isSatisfied(expression, by: provider) else { return [] }

        switch expression {
        case .always:
            return []
        case .all(let list):
            return list.flatMap { unmetChecks(in: $0, by: provider) }
        case .any(let list):
            // Keine der Alternativen ist erfuellt: alle sind offene Wege.
            return list.flatMap { unmetChecks(in: $0, by: provider) }
        case .not:
            // Eine verneinte Bedingung als Hinweis anzuzeigen verwirrt mehr,
            // als sie hilft ("nicht im Winter" ist kein Ziel).
            return []
        case .check:
            return [expression]
        }
    }

    // MARK: - Vergleich

    private static func compare(
        _ actual: FactValue?,
        _ comparator: Comparator,
        _ expected: FactValue
    ) -> Bool {
        // Eine unbekannte Tatsache gilt als nicht erfuellt - nie als erfuellt.
        // Ein Tippfehler im Content darf keine Evolution verschenken.
        guard let actual else { return false }

        switch (actual, expected) {
        case (.number(let lhs), .number(let rhs)):
            return compareNumbers(lhs, comparator, rhs)

        case (.text(let lhs), .text(let rhs)):
            switch comparator {
            case .equal: return lhs == rhs
            case .notEqual: return lhs != rhs
            case .contains: return lhs.contains(rhs)
            default: return false
            }

        case (.flag(let lhs), .flag(let rhs)):
            switch comparator {
            case .equal: return lhs == rhs
            case .notEqual: return lhs != rhs
            default: return false
            }

        default:
            // Typmischung ist ein Content-Fehler, kein Spielereignis.
            return false
        }
    }

    private static func compareNumbers(
        _ lhs: Double,
        _ comparator: Comparator,
        _ rhs: Double
    ) -> Bool {
        switch comparator {
        case .equal: lhs == rhs
        case .notEqual: lhs != rhs
        case .greaterThan: lhs > rhs
        case .greaterOrEqual: lhs >= rhs
        case .lessThan: lhs < rhs
        case .lessOrEqual: lhs <= rhs
        case .contains: false
        }
    }
}
