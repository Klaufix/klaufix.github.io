import Foundation
import GameContent
import GameCore
import GameRules

/// Was beim Auflösen der verstrichenen Zeit herauskam.
///
/// Bewusst kein „Schadensbericht": Die Oberfläche soll daraus ein Wiedersehen
/// bauen, keine Mängelliste.
public struct SimulationOutcome: Sendable, Hashable {
    public var absenceHours: Double
    public var isReunion: Bool
    public var friendshipGained: Double
    public var wokeUp: Bool
    public var expiredConditions: [CreatureCondition]

    public init(
        absenceHours: Double = 0,
        isReunion: Bool = false,
        friendshipGained: Double = 0,
        wokeUp: Bool = false,
        expiredConditions: [CreatureCondition] = []
    ) {
        self.absenceHours = absenceHours
        self.isReunion = isReunion
        self.friendshipGained = friendshipGained
        self.wokeUp = wokeUp
        self.expiredConditions = expiredConditions
    }
}

/// Schreibt eine Kreatur durch die verstrichene Zeit fort.
///
/// Deterministisch und ohne Zufall: Derselbe Ausgangszustand und dieselben
/// Abschnitte ergeben immer denselben Endzustand. Das macht „30 Tage offline"
/// zu einem Testfall statt zu einer Vermutung.
public enum CreatureSimulation {

    public static func advance(
        _ record: inout CreatureRecord,
        through segments: [TimeSegment],
        species: SpeciesDefinition,
        balancing: BalancingDefinition,
        now: Date
    ) -> SimulationOutcome {
        let absenceSeconds = record.state.cursor.absence(until: now)
        let absenceHours = absenceSeconds / 3600

        var outcome = SimulationOutcome(absenceHours: absenceHours)
        guard !segments.isEmpty else {
            record.state.cursor.advance(to: now)
            return outcome
        }

        let absenceStart = segments[0].start
        let wasAsleep = record.state.isAsleep

        for segment in segments {
            let from = segment.start.timeIntervalSince(absenceStart) / 3600
            let to = segment.end.timeIntervalSince(absenceStart) / 3600
            let hours = max(to - from, 0)
            guard hours > 0 else { continue }

            let hour = hourOfDay(for: segment)
            let asleep = sleeps(species: species, atHour: hour)
            record.state.isAsleep = asleep

            applySegment(
                fromHour: from,
                toHour: to,
                hours: hours,
                asleep: asleep,
                balancing: balancing,
                state: &record.state
            )
        }

        outcome.wokeUp = wasAsleep && !record.state.isAsleep
        outcome.expiredConditions = expireConditions(in: &record.state, at: now)

        // Rückkehr-Bonus statt Rückkehr-Strafe: je länger weg, desto herzlicher
        // der Empfang — bis zu einem Deckel (Design-Säule 3).
        if absenceHours >= balancing.reunionAfterHours {
            outcome.isReunion = true
            outcome.friendshipGained = record.state.friendship.increase(
                by: balancing.reunionFriendshipBonus
            )
        }

        record.state.cursor.advance(to: now)
        return outcome
    }

    // MARK: - Ein Abschnitt

    private static func applySegment(
        fromHour from: Double,
        toHour to: Double,
        hours: Double,
        asleep: Bool,
        balancing: BalancingDefinition,
        state: inout CreatureState
    ) {
        let floor = balancing.offlineFloor
        let halfLife = balancing.dampeningHalfLifeHours

        let satiationRate =
            asleep ? balancing.satiationDecayPerHourAsleep : balancing.satiationDecayPerHour

        state.needs.satiation.decay(
            by: DecayCurve.amount(
                baseRatePerHour: satiationRate,
                fromHour: from,
                toHour: to,
                halfLifeHours: halfLife
            ),
            notBelow: floor
        )

        state.needs.mood.decay(
            by: DecayCurve.amount(
                baseRatePerHour: balancing.moodDecayPerHour,
                fromHour: from,
                toHour: to,
                halfLifeHours: halfLife
            ),
            notBelow: floor
        )

        if asleep {
            // Schlaf ist Erholung, nicht Stillstand.
            state.needs.energy.adjust(by: 8 * hours)
            state.needs.tiredness.adjust(by: -12 * hours)
        } else {
            state.needs.energy.decay(
                by: DecayCurve.amount(
                    baseRatePerHour: balancing.energyDecayPerHour,
                    fromHour: from,
                    toHour: to,
                    halfLifeHours: halfLife
                ),
                notBelow: floor
            )
            state.needs.tiredness.adjust(by: 3 * hours)
        }

        // Gesundheit ist träge und reagiert erst, wenn ein anderer Wert lange
        // sehr niedrig steht. Auch sie hat einen Boden: Krank ja, verloren nie.
        if state.needs.satiation.value < 20 {
            state.needs.health.decay(by: 0.5 * hours, notBelow: 40)
        } else if state.needs.satiation.value > 60 {
            state.needs.health.adjust(by: 0.8 * hours)
        }
    }

    // MARK: - Hilfen

    static func hourOfDay(for segment: TimeSegment) -> Int {
        switch segment.timeOfDay {
        case .morning: 7
        case .day: 13
        case .evening: 20
        case .night: 2
        }
    }

    /// Ob die Art zu dieser Stunde schläft. Das Schlaffenster steht im Content,
    /// nicht im Code — eine nachtaktive Art ist damit eine Datei.
    static func sleeps(species: SpeciesDefinition, atHour hour: Int) -> Bool {
        let from = species.likes.bedtimeHour
        let until = species.likes.wakeHour

        if from == until { return false }
        if from < until { return hour >= from && hour < until }
        // Fenster über Mitternacht.
        return hour >= from || hour < until
    }

    private static func expireConditions(
        in state: inout CreatureState,
        at date: Date
    ) -> [CreatureCondition] {
        let expired = state.conditions.filter { !$0.isActive(at: date) }.map(\.condition)
        state.conditions = state.conditions.filter { $0.isActive(at: date) }
        return expired
    }
}
