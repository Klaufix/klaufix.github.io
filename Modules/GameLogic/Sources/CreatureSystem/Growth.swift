import Foundation
import GameContent
import GameCore

public enum GrowthEvent: GameEvent, Sendable {
    case gainedExperience(creature: CreatureID, amount: Int, newLevel: Int)

    public static var eventType: String { "growth" }
}

/// Erfahrung und Stufen.
///
/// Die Kurve ist bewusst flach: Ein Level ist kein Tor, hinter dem Inhalte
/// warten, sondern ein Zeichen gemeinsam verbrachter Zeit. Wer nur pflegt und
/// nie kämpft, kommt trotzdem voran — nur langsamer als jemand, der beides tut
/// (Design-Säule 4).
public enum Growth {
    public static let maximumLevel = 50

    /// Erfahrung, die von Stufe `level` zur nächsten nötig ist.
    public static func experienceToAdvance(from level: Int) -> Int {
        guard level >= 1, level < maximumLevel else { return .max }
        return Int((pow(Double(level), 1.55) * 24).rounded())
    }

    /// Erfahrung durch Pflege. Klein, aber verlässlich — der tägliche
    /// Check-in soll spürbar etwas bewirken.
    public static let experiencePerCareAction = 3

    /// Erfahrung je Stunde, in der es der Kreatur gut ging.
    ///
    /// Zeit allein genügt nicht: Nur Stunden oberhalb des Korridors zählen.
    /// Das belohnt Pflege, ohne Vernachlässigung zu bestrafen — wer nichts tut,
    /// verliert nichts, gewinnt nur weniger.
    public static let experiencePerHealthyHour = 1

    /// Trägt Erfahrung ein und liefert die neue Stufe zurück.
    @discardableResult
    public static func award(_ amount: Int, to state: inout CreatureState) -> Int {
        guard amount > 0, state.level < maximumLevel else { return state.level }

        state.experience += amount

        while state.level < maximumLevel {
            let needed = experienceToAdvance(from: state.level)
            guard needed != .max, state.experience >= needed else { break }
            state.experience -= needed
            state.level += 1
        }

        if state.level >= maximumLevel {
            state.experience = 0
        }

        return state.level
    }

    /// Wie viele Stunden eines Zeitraums als „ging es gut" zählen.
    public static func healthyHours(_ hours: Double, state: CreatureState) -> Int {
        let comfortable =
            state.needs.satiation.value >= 40
            && state.needs.mood.value >= 40
            && state.needs.health.value >= 60
        return comfortable ? Int(hours.rounded(.down)) : 0
    }

    /// Fortschritt zur nächsten Stufe, 0…1 — für die Anzeige.
    public static func progress(of state: CreatureState) -> Double {
        let needed = experienceToAdvance(from: state.level)
        guard needed != .max, needed > 0 else { return 1 }
        return min(max(Double(state.experience) / Double(needed), 0), 1)
    }
}
