/// Woran eine Bedingung eine Frage stellen kann.
///
/// Dies ist die einzige Stelle, an der ein neuer Inhaltstyp ueberhaupt noch
/// Code braucht: Wer eine Evolution an die Mondphase knuepfen will, ergaenzt
/// hier einen Fall - und die Bedingung steht danach *allen* Systemen zur
/// Verfuegung: Evolution, Quests, Spawns, Events, Achievements, Dialoge.
public enum FactKey: String, Sendable, Codable, CaseIterable {
    case level
    case friendship
    case personality          // Parameter: PersonalityAxis
    case growthStage
    case element
    case variant
    case season
    case weather
    case timeOfDay
    case moonPhase
    case daysOwned
    case battlesWon
    case dungeonCleared       // Parameter: DungeonID
    case questCompleted       // Parameter: QuestID
    case itemUsed             // Parameter: ItemID
    case foodEatenCount       // Parameter: Nahrungs-Tag
    case equippedTag          // Parameter: Kleidungs-Tag
    case albumDiscoveredCount
    case careActionCount
}

/// Eine Frage an den Spielzustand, optional mit Gegenstand.
/// `Fact(.personality, parameter: "courage")` bedeutet „wie mutig ist sie?".
public struct Fact: Sendable, Hashable, Codable {
    public let key: FactKey
    public let parameter: String?

    public init(_ key: FactKey, parameter: String? = nil) {
        self.key = key
        self.parameter = parameter
    }
}

public enum Comparator: String, Sendable, Codable, CaseIterable {
    case equal = "=="
    case notEqual = "!="
    case greaterThan = ">"
    case greaterOrEqual = ">="
    case lessThan = "<"
    case lessOrEqual = "<="
    case contains
}

public enum FactValue: Sendable, Hashable, Codable {
    case number(Double)
    case text(String)
    case flag(Bool)

    public var number: Double? {
        if case .number(let value) = self { return value }
        return nil
    }

    public var text: String? {
        if case .text(let value) = self { return value }
        return nil
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        // Reihenfolge ist wichtig: JSON `true` ist auch als Zahl dekodierbar.
        if let flag = try? container.decode(Bool.self) {
            self = .flag(flag)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else {
            self = .text(try container.decode(String.self))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .number(let value): try container.encode(value)
        case .text(let value): try container.encode(value)
        case .flag(let value): try container.encode(value)
        }
    }
}

/// Ein Bedingungsausdruck.
///
/// Derselbe Baum beschreibt eine Evolutionsvoraussetzung, ein Questziel, die
/// Verfuegbarkeit eines Events und die Sichtbarkeit eines Shop-Eintrags. Er wird
/// aus Content geladen und in `GameRules` ausgewertet - hier steht nur die Form,
/// nicht die Auswertung, damit auch Content-Definitionen ihn verwenden koennen.
///
/// JSON-Gestalt:
/// ```json
/// { "all": [
///     { "fact": "level", "op": ">=", "value": 16 },
///     { "fact": "personality", "parameter": "courage", "op": ">=", "value": 70 },
///     { "any": [ { "fact": "season", "op": "==", "value": "spring" },
///                { "fact": "weather", "op": "==", "value": "fog" } ] }
/// ] }
/// ```
public indirect enum ConditionExpression: Sendable, Hashable, Codable {
    /// Immer erfuellt. Der Standard fuer Inhalte ohne Voraussetzung.
    case always
    case all([ConditionExpression])
    case any([ConditionExpression])
    case not(ConditionExpression)
    case check(Fact, Comparator, FactValue)

    /// Bequemer Kurzweg fuer die haeufigste Form:
    /// `.fact(.level, .greaterOrEqual, .number(16))`
    public static func fact(
        _ key: FactKey,
        parameter: String? = nil,
        _ comparator: Comparator,
        _ value: FactValue
    ) -> ConditionExpression {
        .check(Fact(key, parameter: parameter), comparator, value)
    }

    private enum CodingKeys: String, CodingKey {
        case always, all, any, not, fact, parameter, op, value
    }

    private struct Raw: Decodable {
        let always: Bool?
        let all: [ConditionExpression]?
        let any: [ConditionExpression]?
        let not: ConditionExpression?
        let fact: FactKey?
        let parameter: String?
        let op: Comparator?
        let value: FactValue?
    }

    public init(from decoder: any Decoder) throws {
        let raw = try Raw(from: decoder)

        if let list = raw.all {
            self = .all(list)
        } else if let list = raw.any {
            self = .any(list)
        } else if let inner = raw.not {
            self = .not(inner)
        } else if let fact = raw.fact {
            guard let op = raw.op, let value = raw.value else {
                throw DecodingError.dataCorrupted(
                    .init(
                        codingPath: decoder.codingPath,
                        debugDescription:
                            "Bedingung mit fact '\(fact.rawValue)' braucht 'op' und 'value'."
                    )
                )
            }
            self = .check(Fact(fact, parameter: raw.parameter), op, value)
        } else if raw.always == true {
            self = .always
        } else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription:
                        "Unbekannte Bedingung. Erlaubt: always, all, any, not, fact."
                )
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .always:
            try container.encode(true, forKey: .always)
        case .all(let list):
            try container.encode(list, forKey: .all)
        case .any(let list):
            try container.encode(list, forKey: .any)
        case .not(let inner):
            try container.encode(inner, forKey: .not)
        case .check(let fact, let comparator, let value):
            try container.encode(fact.key, forKey: .fact)
            try container.encodeIfPresent(fact.parameter, forKey: .parameter)
            try container.encode(comparator, forKey: .op)
            try container.encode(value, forKey: .value)
        }
    }
}
