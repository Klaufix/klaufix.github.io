import AlbumSystem
import CreatureRenderer
import CreatureSystem
import Foundation
import GameContent
import GameCore
import GameEngine
import GameState
import Observation

/// Ein Album-Eintrag als reine Anzeigedaten.
///
/// Bewusst ohne Bindung an ein bestimmtes Feature-Modul: Die Album-Ansicht
/// bekommt daraus ihre Elemente, ohne die Engine zu kennen.
public struct AlbumSnapshot: Sendable, Hashable {
    public let speciesID: String
    public let nameKey: String
    public let descriptor: AppearanceDescriptor
    public let isDiscovered: Bool
    public let variants: [String]
    public let habitat: String
}

/// Der beobachtbare Wrapper um die Engine.
///
/// Die Engine selbst ist plattformunabhängig und weiß nichts von SwiftUI. Erst
/// hier, in der Darstellungsschicht, wird sie beobachtbar. Diese Grenze ist
/// nicht Geschmack, sondern Voraussetzung dafür, dass die Spiellogik unter Linux
/// getestet werden kann.
@MainActor
@Observable
public final class HomeModel {
    private var engine: GameEngine

    public private(set) var summary: ResolveSummary?
    /// Die Rückkehr-Szene wird einmal gezeigt und dann weggelegt — sie ist ein
    /// Wiedersehen, keine Statusmeldung, die stehen bleibt.
    public var showsReunion: Bool = false

    /// Wird nach jeder Zustandsänderung gerufen — daran hängt das Speichern.
    ///
    /// Als Rückruf statt als Abhängigkeit: `FeatureHome` soll nicht wissen,
    /// dass es so etwas wie Dateien gibt. Wer speichert, entscheidet
    /// AppComposition.
    private let onChange: (@MainActor (GameState) -> Void)?

    public init(engine: GameEngine, onChange: (@MainActor (GameState) -> Void)? = nil) {
        self.engine = engine
        self.onChange = onChange
    }

    private func changed() {
        onChange?(engine.state)
    }

    // MARK: - Zustand für die Ansicht

    public var record: CreatureRecord? { engine.state.activeCreature }

    public var species: SpeciesDefinition? {
        guard let record else { return nil }
        return engine.content.species[record.individual.speciesID]
    }

    public var displayName: String {
        record?.individual.nickname ?? "Kleines Wesen"
    }

    public var descriptor: AppearanceDescriptor? {
        guard let record, let species else { return nil }
        return AppearanceResolver.descriptor(
            for: species.appearance,
            variant: record.individual.variant,
            stage: species.growthStage,
            cosmetics: record.state.cosmetics
        )
    }

    public var mood: CreatureMood {
        guard let record else { return .content }
        return CreatureMood.from(
            satiation: record.state.needs.satiation.value,
            energy: record.state.needs.energy.value,
            mood: record.state.needs.mood.value,
            health: record.state.needs.health.value,
            isAsleep: record.state.isAsleep
        )
    }

    /// Der Zustand in Worten. Grundlage für VoiceOver und für die Zeile unter
    /// der Kreatur — Farbe ist nie der einzige Träger einer Information.
    public var moodDescription: String {
        switch mood {
        case .happy: "rundum glücklich"
        case .content: "zufrieden"
        case .sleepy: record?.state.isAsleep == true ? "schläft" : "müde"
        case .hungry: "hat Hunger"
        case .unwell: "fühlt sich nicht gut"
        }
    }

    public var isAsleep: Bool { record?.state.isAsleep ?? false }

    public var level: Int { record?.state.level ?? 1 }

    public var levelProgress: Double {
        guard let record else { return 0 }
        return Growth.progress(of: record.state)
    }

    /// Alle Arten des Spiels, entdeckte zuerst — die Grundlage für das Album.
    ///
    /// Die Aufbereitung steckt hier und nicht im Album-Modul: Zwei Feature-Module
    /// kennen einander nicht, und keines soll eine eigene Kopie des Zustands
    /// halten.
    public var albumItems: [AlbumSnapshot] {
        engine.content.activeSpecies
            .sorted { $0.id.rawValue < $1.id.rawValue }
            .map { species in
                let entry = engine.state.album.entry(for: species.id)
                return AlbumSnapshot(
                    speciesID: species.id.rawValue,
                    nameKey: species.nameKey,
                    descriptor: AppearanceResolver.descriptor(
                        for: species.appearance,
                        variant: .standard,
                        stage: species.growthStage,
                        cosmetics: [:]
                    ),
                    isDiscovered: entry != nil,
                    variants: entry.map { Array($0.variants).sorted() } ?? [],
                    habitat: AlbumSystem.teaser(for: species)
                )
            }
    }

    public var discoveredCount: Int { engine.state.album.discoveredCount }

    public var nextMilestone: Int? {
        AlbumSystem.nextMilestone(after: discoveredCount)
    }

    /// Was der aktiven Kreatur noch zu einer Entwicklung fehlt.
    public var evolutionHintKeys: [String] {
        guard let record else { return [] }
        return engine.evolutionHints(for: record.id, now: Date())
            .filter { !$0.isReachableNow }
            .map(\.hintKey)
    }

    /// Ein einzelner, freundlicher Vorschlag — nie eine Liste offener Aufgaben.
    public var suggestion: String? {
        guard let record else { return nil }
        if record.state.needs.satiation.value < 45 { return "Sie schaut zum Napf." }
        if record.state.needs.tiredness.value > 70 && !record.state.isAsleep {
            return "Sie gähnt. Vielleicht ist es Zeit fürs Bett."
        }
        if record.state.needs.mood.value < 50 { return "Ein bisschen Zuwendung täte gut." }
        return nil
    }

    public var accessibilitySummary: String {
        "\(displayName), \(moodDescription)"
    }

    // MARK: - Handlungen

    public func refresh(now: Date = Date()) {
        let result = engine.resolveTime(now: now)
        summary = result
        if result.isReunion {
            showsReunion = true
        }
        changed()
    }

    public func feed(_ item: ItemID = "sun_berry") {
        guard let record else { return }
        engine.perform(.feed(record.id, item))
        changed()
    }

    public func pet() {
        guard let record else { return }
        engine.perform(.pet(record.id))
        changed()
    }

    public func toggleSleep() {
        guard let record else { return }
        engine.perform(record.state.isAsleep ? .wake(record.id) : .putToSleep(record.id))
        changed()
    }

    // MARK: - Anzeige

    public var needs: [(title: String, symbol: String, fraction: Double, state: String)] {
        guard let record else { return [] }
        return [
            (
                "Sättigung", "leaf.fill", record.state.needs.satiation.fraction,
                word(for: record.state.needs.satiation.fraction)
            ),
            (
                "Energie", "bolt.fill", record.state.needs.energy.fraction,
                word(for: record.state.needs.energy.fraction)
            ),
            (
                "Stimmung", "heart.fill", record.state.needs.mood.fraction,
                word(for: record.state.needs.mood.fraction)
            ),
        ]
    }

    private func word(for fraction: Double) -> String {
        switch fraction {
        case ..<0.3: "möchte etwas"
        case ..<0.6: "geht so"
        case ..<0.85: "zufrieden"
        default: "bestens"
        }
    }

    /// Der Empfang nach längerer Abwesenheit. Je länger weg, desto herzlicher —
    /// und niemals ein Vorwurf.
    public var reunionText: String {
        guard let summary, summary.absenceHours >= 24 else { return "Schön, dass du da bist." }
        let days = Int(summary.absenceHours / 24)
        if days >= 7 { return "\(displayName) hat dich sehr vermisst — und viel zu erzählen." }
        if days >= 1 { return "\(displayName) hat dich vermisst." }
        return "Schön, dass du da bist."
    }
}
