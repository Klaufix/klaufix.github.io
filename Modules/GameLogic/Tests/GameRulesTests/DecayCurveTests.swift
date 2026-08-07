import Foundation
import Testing

@testable import GameRules

@Suite("Gedämpfter Verfall")
struct DecayCurveTests {

    private let rate: Double = 4
    private let halfLife: Double = 8

    @Test("Abschnitte addieren sich exakt zum Ganzen")
    func segmentsAreAdditive() {
        // Diese Eigenschaft trägt die ganze Zeitauflösung: Die Engine zerlegt
        // die Abwesenheit in Stundenabschnitte, und das Ergebnis muss dasselbe
        // sein, als hätte sie in einem Stück gerechnet.
        let whole = DecayCurve.amount(
            baseRatePerHour: rate, fromHour: 0, toHour: 10, halfLifeHours: halfLife
        )
        let first = DecayCurve.amount(
            baseRatePerHour: rate, fromHour: 0, toHour: 5, halfLifeHours: halfLife
        )
        let second = DecayCurve.amount(
            baseRatePerHour: rate, fromHour: 5, toHour: 10, halfLifeHours: halfLife
        )

        #expect(abs(whole - (first + second)) < 0.000_001)
    }

    @Test("Die erste Stunde kostet ungefähr die volle Rate")
    func firstHourIsNearlyLinear() {
        let amount = DecayCurve.amount(
            baseRatePerHour: rate, fromHour: 0, toHour: 1, halfLifeHours: halfLife
        )

        #expect(amount > rate * 0.9)
        #expect(amount < rate)
    }

    @Test("Die Rate halbiert sich nach einer Halbwertszeit")
    func rateHalves() {
        let firstHour = DecayCurve.amount(
            baseRatePerHour: rate, fromHour: 0, toHour: 1, halfLifeHours: halfLife
        )
        let ninthHour = DecayCurve.amount(
            baseRatePerHour: rate, fromHour: 8, toHour: 9, halfLifeHours: halfLife
        )

        #expect(abs(ninthHour - firstHour / 2) < 0.001)
    }

    @Test("Der Verfall ist nach oben beschränkt")
    func decayIsBounded() {
        let maximum = DecayCurve.maximum(baseRatePerHour: rate, halfLifeHours: halfLife)

        let month = DecayCurve.amount(
            baseRatePerHour: rate, fromHour: 0, toHour: 24 * 30, halfLifeHours: halfLife
        )
        let year = DecayCurve.amount(
            baseRatePerHour: rate, fromHour: 0, toHour: 24 * 365, halfLifeHours: halfLife
        )

        #expect(month <= maximum)
        #expect(year <= maximum)
        // Ein Monat und ein Jahr Abwesenheit unterscheiden sich praktisch nicht.
        #expect(abs(year - month) < 0.001)
    }

    @Test("Zwei Wochen kosten kaum mehr als zwei Tage")
    func longAbsenceIsNotWorse() {
        let twoDays = DecayCurve.amount(
            baseRatePerHour: rate, fromHour: 0, toHour: 48, halfLifeHours: halfLife
        )
        let twoWeeks = DecayCurve.amount(
            baseRatePerHour: rate, fromHour: 0, toHour: 24 * 14, halfLifeHours: halfLife
        )

        // Das ist Design-Säule 3 als Zahl: Wer lange weg war, wird nicht
        // proportional bestraft.
        #expect(twoWeeks - twoDays < 1.0)
    }

    @Test("Unsinnige Eingaben ergeben null statt Unfug")
    func guardsAgainstNonsense() {
        #expect(
            DecayCurve.amount(
                baseRatePerHour: rate, fromHour: 10, toHour: 5, halfLifeHours: halfLife
            ) == 0
        )
        #expect(
            DecayCurve.amount(
                baseRatePerHour: 0, fromHour: 0, toHour: 5, halfLifeHours: halfLife
            ) == 0
        )
        #expect(
            DecayCurve.amount(
                baseRatePerHour: rate, fromHour: 0, toHour: 5, halfLifeHours: 0
            ) == 0
        )
    }
}
