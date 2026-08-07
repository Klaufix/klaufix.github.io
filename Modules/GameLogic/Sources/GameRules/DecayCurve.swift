import Foundation

/// Der gedämpfte Verfall.
///
/// Ein Bedürfnis verfällt nicht linear, sondern mit einer Rate, die sich alle
/// `halfLifeHours` halbiert. Das ist die Formel, die „zwei Wochen weg kostet
/// kaum mehr als zwei Tage" konkret macht — und damit Design-Säule 3.
///
/// Die momentane Rate zur Stunde `u` ist `r · 2^(−u/H)`. Aufsummiert über einen
/// Abschnitt ergibt das
///
///     ∫ r·2^(−u/H) du  =  (r·H / ln2) · (2^(−t₀/H) − 2^(−t₁/H))
///
/// Drei Eigenschaften machen diese Form wertvoll:
///
/// 1. **Beschränkt.** Selbst über unendlich lange Abwesenheit fällt nie mehr als
///    `r·H/ln2` an. Bei 4 Punkten pro Stunde und 8 Stunden Halbwertszeit sind
///    das rund 46 Punkte — egal, ob jemand drei Tage oder drei Monate weg war.
/// 2. **Additiv.** Der Verfall über [0,5] plus der über [5,10] ist exakt der
///    über [0,10]. Die Engine kann die Zeit deshalb in Stundenabschnitte
///    zerlegen, ohne dass sich Rundungsfehler aufaddieren.
/// 3. **Zustandslos.** Es braucht keine gespeicherte Verfallshistorie, nur den
///    Abstand zum Beginn der Abwesenheit.
public enum DecayCurve {

    /// Verfall zwischen zwei Zeitpunkten, gemessen in Stunden seit Beginn der
    /// Abwesenheit.
    public static func amount(
        baseRatePerHour rate: Double,
        fromHour start: Double,
        toHour end: Double,
        halfLifeHours halfLife: Double
    ) -> Double {
        guard rate > 0, halfLife > 0, end > start, start >= 0 else { return 0 }

        let scale = rate * halfLife / log(2)
        return scale * (pow(2, -start / halfLife) - pow(2, -end / halfLife))
    }

    /// Obergrenze des Verfalls über beliebig lange Abwesenheit.
    ///
    /// Diese Zahl ist der eigentliche Schutz: Sie begrenzt, was Abwesenheit
    /// überhaupt anrichten kann. Der Komfort-Boden aus dem Balancing ist die
    /// zweite Sicherung — für den Fall, dass ein Wert schon niedrig war.
    public static func maximum(
        baseRatePerHour rate: Double,
        halfLifeHours halfLife: Double
    ) -> Double {
        guard rate > 0, halfLife > 0 else { return 0 }
        return rate * halfLife / log(2)
    }
}
