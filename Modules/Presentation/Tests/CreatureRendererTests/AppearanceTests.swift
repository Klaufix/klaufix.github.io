import Foundation
import GameContent
import GameCore
import Testing

@testable import CreatureRenderer

/// Die Auflösung aus dem Content ist frei von SwiftUI — und deshalb testbar.
@Suite("Aussehen aus Content auflösen")
struct AppearanceResolverTests {

    /// Bewusst über JSON statt über einen Initialisierer: So prüft der Test
    /// zugleich, dass das Autorenformat zum Modell passt.
    private func appearance() throws -> AppearanceDefinition {
        let json = """
        {
          "silhouette": "round_sprout",
          "parts": ["leaf_crest", "wide_eyes"],
          "defaultPalette": "sprout_green",
          "variantPalettes": { "shimmer": "sprout_gold" }
        }
        """
        return try JSONDecoder().decode(AppearanceDefinition.self, from: Data(json.utf8))
    }

    @Test("Die Standardvariante nutzt die Standardpalette")
    func standardVariantUsesDefaultPalette() throws {
        let descriptor = AppearanceResolver.descriptor(
            for: try appearance(),
            variant: .standard,
            stage: .adult,
            cosmetics: [:]
        )

        #expect(descriptor.palette == "sprout_green")
        #expect(descriptor.silhouette == "round_sprout")
        #expect(descriptor.parts.count == 2)
    }

    @Test("Eine Variante tauscht nur die Farbtabelle")
    func variantSwapsPaletteOnly() throws {
        let definition = try appearance()

        let standard = AppearanceResolver.descriptor(
            for: definition, variant: .standard, stage: .adult, cosmetics: [:]
        )
        let shimmer = AppearanceResolver.descriptor(
            for: definition, variant: .shimmer, stage: .adult, cosmetics: [:]
        )

        // Genau das macht Varianten billig: eine Farbtabelle statt einer
        // neuen Zeichnung.
        #expect(shimmer.palette == "sprout_gold")
        #expect(shimmer.silhouette == standard.silhouette)
        #expect(shimmer.parts == standard.parts)
    }

    @Test("Eine Variante ohne eigene Palette fällt auf die Standardpalette zurück")
    func missingVariantPaletteFallsBack() throws {
        let descriptor = AppearanceResolver.descriptor(
            for: try appearance(),
            variant: .event,
            stage: .adult,
            cosmetics: [:]
        )

        #expect(descriptor.palette == "sprout_green")
    }

    @Test("Die Wachstumsstufe bestimmt die Größe und wächst monoton")
    func scaleGrowsWithStage() {
        let scales = GrowthStage.allCases.map { AppearanceResolver.scale(for: $0) }

        #expect(scales == scales.sorted())
        #expect(AppearanceResolver.scale(for: .egg) < AppearanceResolver.scale(for: .adult))
    }

    @Test("Kleidung kommt in Zeichenreihenfolge, nicht in Wörterbuch-Reihenfolge")
    func cosmeticsAreOrdered() throws {
        let descriptor = AppearanceResolver.descriptor(
            for: try appearance(),
            variant: .standard,
            stage: .adult,
            cosmetics: [
                CosmeticSlot.eyes.rawValue: "round_glasses",
                CosmeticSlot.head.rawValue: "straw_hat",
                CosmeticSlot.back.rawValue: "tiny_cape",
            ]
        )

        // Der Hut gehört über den Umhang, die Brille über den Hut.
        #expect(descriptor.cosmetics == ["tiny_cape", "straw_hat", "round_glasses"])
    }

    @Test("Ohne Kleidung bleibt die Liste leer")
    func noCosmetics() throws {
        let descriptor = AppearanceResolver.descriptor(
            for: try appearance(), variant: .standard, stage: .youngling, cosmetics: [:]
        )

        #expect(descriptor.cosmetics.isEmpty)
    }
}

@Suite("Stimmung ablesen")
struct CreatureMoodTests {

    @Test("Krank schlägt alles andere")
    func illnessWins() {
        let mood = CreatureMood.from(
            satiation: 100, energy: 100, mood: 100, health: 20, isAsleep: false
        )

        #expect(mood == .unwell)
    }

    @Test("Schlafend schlägt Hunger")
    func sleepBeatsHunger() {
        let mood = CreatureMood.from(
            satiation: 10, energy: 90, mood: 50, health: 100, isAsleep: true
        )

        #expect(mood == .sleepy)
    }

    @Test("Hunger wird sichtbar, bevor der Balken leer ist")
    func hungerShowsEarly() {
        let mood = CreatureMood.from(
            satiation: 30, energy: 80, mood: 50, health: 100, isAsleep: false
        )

        #expect(mood == .hungry)
    }

    @Test("Gute Laune ist sichtbar")
    func happiness() {
        let mood = CreatureMood.from(
            satiation: 80, energy: 80, mood: 90, health: 100, isAsleep: false
        )

        #expect(mood == .happy)
    }

    @Test("Der Normalfall ist zufrieden, nicht neutral-leer")
    func defaultIsContent() {
        let mood = CreatureMood.from(
            satiation: 60, energy: 60, mood: 60, health: 100, isAsleep: false
        )

        #expect(mood == .content)
    }
}

@Suite("Stabile Farbableitung")
struct StableTintTests {

    @Test("Dieselbe Palette ergibt immer denselben Farbton")
    func stableAcrossCalls() {
        #expect(StableTint.hue(for: "unbekannt") == StableTint.hue(for: "unbekannt"))
    }

    @Test("Der Farbton liegt im gültigen Bereich")
    func hueInRange() {
        for name in ["a", "sprout_green", "völlig_neue_palette", ""] {
            let hue = StableTint.hue(for: PaletteID(name))
            #expect(hue >= 0 && hue < 1)
        }
    }

    @Test("Verschiedene Paletten ergeben verschiedene Farbtöne")
    func differentPalettesDiffer() {
        #expect(StableTint.hue(for: "alpha") != StableTint.hue(for: "beta"))
    }

    @Test("Der Streuwert ist fest verdrahtet, nicht pro Programmstart gesalzen")
    func hashIsDeterministic() {
        // Swifts hashValue wechselt bei jedem Start. Wäre er die Grundlage,
        // hätte die Kreatur bei jedem Start eine andere Farbe — deshalb ein
        // fester Erwartungswert statt eines Selbstvergleichs.
        #expect(StableTint.fnv1a("sprout") == 17_952_531_261_379_531_152)
    }
}
