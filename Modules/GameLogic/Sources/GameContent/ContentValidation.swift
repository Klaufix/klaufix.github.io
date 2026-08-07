import GameCore

public struct ContentIssue: Sendable, Hashable, CustomStringConvertible {
    public enum Severity: String, Sendable {
        case error
        case warning
    }

    public let severity: Severity
    public let subject: String
    public let message: String

    public var description: String {
        "[\(severity.rawValue)] \(subject): \(message)"
    }
}

/// Prueft ein geladenes Bundle, bevor es ins Spiel darf.
///
/// Die Pruefung faengt drei Klassen von Fehlern ab:
/// 1. **Referenzintegritaet** - jede ID zeigt auf etwas, das es gibt.
/// 2. **Schema-Erwartungen** - Versionen, Wertebereiche.
/// 3. **Design-Regeln** - Zusagen aus dem GDD, die sich pruefen lassen.
///
/// Der dritte Punkt ist der interessante: Dass jede Art einen kampffreien
/// Entwicklungsweg hat, ist ein Versprechen an Cozy-Spieler. Ein Versprechen,
/// das niemand nachprueft, ist in zwei Jahren gebrochen - hier prueft es die CI.
public enum ContentValidation {

    public static func validate(_ bundle: ContentBundle) -> [ContentIssue] {
        var issues: [ContentIssue] = []

        issues += validateSpecies(bundle)
        issues += validateEvolutions(bundle)
        issues += validateItems(bundle)
        issues += validateBalancing(bundle)
        issues += validateClimate(bundle)

        return issues
    }

    // MARK: - Klima

    private static func validateClimate(_ bundle: ContentBundle) -> [ContentIssue] {
        var issues: [ContentIssue] = []
        let subject = "climate/climate.json"

        if bundle.climate.slotHours < 1 {
            issues.append(
                ContentIssue(
                    severity: .error,
                    subject: subject,
                    message: "slotHours muss mindestens 1 sein."
                )
            )
        }

        // Jede Jahreszeit braucht mindestens eine moegliche Wetterlage, sonst
        // steht die Welt in dieser Jahreszeit ohne Wetter da.
        for season in Season.allCases {
            let total = bundle.climate.weather.reduce(0) { $0 + $1.weight(in: season) }
            if total <= 0 {
                issues.append(
                    ContentIssue(
                        severity: .error,
                        subject: subject,
                        message: "keine Wetterlage fuer \(season.rawValue) - "
                            + "diese Jahreszeit haette kein Wetter."
                    )
                )
            }
        }

        return issues
    }

    // MARK: - Arten

    private static func validateSpecies(_ bundle: ContentBundle) -> [ContentIssue] {
        var issues: [ContentIssue] = []
        let knownElements = Set(bundle.elementChart.elements)

        for definition in bundle.species.values {
            let subject = "species/\(definition.id.rawValue)"

            if definition.schemaVersion != ContentSchema.current {
                issues.append(
                    ContentIssue(
                        severity: .warning,
                        subject: subject,
                        message: "Schema-Version \(definition.schemaVersion), "
                            + "erwartet \(ContentSchema.current)."
                    )
                )
            }

            if !knownElements.contains(definition.element) {
                issues.append(
                    ContentIssue(
                        severity: .error,
                        subject: subject,
                        message: "unbekanntes Element '\(definition.element.rawValue)'."
                    )
                )
            }

            let hour = definition.likes.bedtimeHour
            let wake = definition.likes.wakeHour
            if !(0...23).contains(hour) || !(0...23).contains(wake) {
                issues.append(
                    ContentIssue(
                        severity: .error,
                        subject: subject,
                        message: "Schlafzeiten muessen zwischen 0 und 23 liegen."
                    )
                )
            }
        }

        return issues
    }

    // MARK: - Entwicklungen

    private static func validateEvolutions(_ bundle: ContentBundle) -> [ContentIssue] {
        var issues: [ContentIssue] = []

        for definition in bundle.evolutions.values {
            let subject = "evolutions/\(definition.id.rawValue)"

            if bundle.species[definition.from] == nil {
                issues.append(
                    ContentIssue(
                        severity: .error,
                        subject: subject,
                        message: "Ausgangsart '\(definition.from.rawValue)' existiert nicht."
                    )
                )
            }

            if definition.branches.isEmpty {
                issues.append(
                    ContentIssue(
                        severity: .error,
                        subject: subject,
                        message: "Entwicklungsweg ohne Verzweigungen."
                    )
                )
            }

            for branch in definition.branches where bundle.species[branch.to] == nil {
                issues.append(
                    ContentIssue(
                        severity: .error,
                        subject: subject,
                        message: "Zielart '\(branch.to.rawValue)' existiert nicht."
                    )
                )
            }

            // Design-Saeule 4: Niemand darf zum Kaempfen gezwungen werden.
            if !definition.branches.contains(where: { $0.isPeaceful }) {
                issues.append(
                    ContentIssue(
                        severity: .error,
                        subject: subject,
                        message: "kein friedlicher Entwicklungsweg - jede Art braucht "
                            + "mindestens einen Weg ohne Kaempfe."
                    )
                )
            }
        }

        // Eine Art ohne Entwicklung ist erlaubt (Endstufen), eine Art, auf die
        // niemand verweist und die selbst nirgends hinfuehrt, ist verdaechtig.
        let reachable = Set(bundle.evolutions.values.flatMap { $0.branches.map(\.to) })
        let sources = Set(bundle.evolutions.values.map(\.from))
        for definition in bundle.species.values where !definition.isRetired {
            if definition.growthStage != .egg,
               definition.growthStage != .hatchling,
               !reachable.contains(definition.id),
               !sources.contains(definition.id) {
                issues.append(
                    ContentIssue(
                        severity: .warning,
                        subject: "species/\(definition.id.rawValue)",
                        message: "weder Ziel noch Ausgangspunkt einer Entwicklung - "
                            + "unerreichbar?"
                    )
                )
            }
        }

        return issues
    }

    // MARK: - Items

    private static func validateItems(_ bundle: ContentBundle) -> [ContentIssue] {
        var issues: [ContentIssue] = []

        for definition in bundle.items.values {
            let subject = "items/\(definition.id.rawValue)"

            if definition.maximumStack < 1 {
                issues.append(
                    ContentIssue(
                        severity: .error,
                        subject: subject,
                        message: "Stapelgroesse muss mindestens 1 sein."
                    )
                )
            }

            for effect in definition.allEffects where abs(effect.amount) > 100 {
                issues.append(
                    ContentIssue(
                        severity: .warning,
                        subject: subject,
                        message: "Wirkung auf \(effect.need.rawValue) ist \(effect.amount) - "
                            + "mehr als der gesamte Wertebereich."
                    )
                )
            }
        }

        return issues
    }

    // MARK: - Balancing

    private static func validateBalancing(_ bundle: ContentBundle) -> [ContentIssue] {
        var issues: [ContentIssue] = []
        let balancing = bundle.balancing
        let subject = "balancing/balancing.json"

        // Der Boden ist der Kern des Anti-Bestrafungs-Versprechens. Faellt er
        // versehentlich auf 0, verhungern Kreaturen wieder - lautlos.
        if balancing.offlineFloor <= 0 {
            issues.append(
                ContentIssue(
                    severity: .error,
                    subject: subject,
                    message: "offlineFloor ist \(balancing.offlineFloor). Ohne Boden "
                        + "koennen Beduerfnisse durch blosse Abwesenheit auf 0 fallen - "
                        + "das widerspricht Design-Saeule 3."
                )
            )
        }

        if balancing.dampeningHalfLifeHours <= 0 {
            issues.append(
                ContentIssue(
                    severity: .error,
                    subject: subject,
                    message: "dampeningHalfLifeHours muss groesser als 0 sein."
                )
            )
        }

        if balancing.shimmerPityThreshold < 1 {
            issues.append(
                ContentIssue(
                    severity: .error,
                    subject: subject,
                    message: "shimmerPityThreshold muss mindestens 1 sein."
                )
            )
        }

        return issues
    }
}
