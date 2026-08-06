import GameContent
import GameCore

/// Was der Renderer zum Zeichnen braucht - und sonst nichts.
///
/// Bewusst **frei von SwiftUI**: Die Auflösung aus dem Content ist damit ohne
/// Oberfläche testbar, und ein späterer Renderer auf gezeichneten Assets
/// bekommt genau dieselbe Eingabe (ADR-005).
public struct AppearanceDescriptor: Sendable, Hashable {
    public let silhouette: String
    public let parts: [AppearancePartID]
    public let palette: PaletteID
    /// Größenfaktor der Wachstumsstufe.
    public let scale: Double
    /// Kleidung in Zeichenreihenfolge, von hinten nach vorn.
    public let cosmetics: [CosmeticID]

    public init(
        silhouette: String,
        parts: [AppearancePartID],
        palette: PaletteID,
        scale: Double,
        cosmetics: [CosmeticID]
    ) {
        self.silhouette = silhouette
        self.parts = parts
        self.palette = palette
        self.scale = scale
        self.cosmetics = cosmetics
    }
}

public enum AppearanceResolver {

    /// Zeichenreihenfolge der Kleidungs-Slots, von hinten nach vorn.
    /// Der Hut gehört über den Körper, die Brille über den Hut.
    public static let cosmeticRenderOrder: [CosmeticSlot] = [
        .ground, .back, .body, .hand, .head, .eyes,
    ]

    public static func scale(for stage: GrowthStage) -> Double {
        switch stage {
        case .egg: 0.60
        case .hatchling: 0.70
        case .youngling: 0.85
        case .adult: 1.00
        case .zenith: 1.10
        }
    }

    public static func descriptor(
        for appearance: AppearanceDefinition,
        variant: CreatureVariant,
        stage: GrowthStage,
        cosmetics: [String: CosmeticID]
    ) -> AppearanceDescriptor {
        AppearanceDescriptor(
            silhouette: appearance.silhouette,
            parts: appearance.parts ?? [],
            palette: appearance.palette(for: variant),
            scale: scale(for: stage),
            cosmetics: cosmeticRenderOrder.compactMap { cosmetics[$0.rawValue] }
        )
    }
}

/// Die Stimmung, die das Gesicht zeigt.
///
/// Regel 2 des UI-Konzepts in Code: Der Zustand wird gespielt, nicht angezeigt.
/// Der Balken daneben ist die Bestätigung, nicht die Information.
public enum CreatureMood: String, Sendable, CaseIterable {
    case content
    case happy
    case sleepy
    case hungry
    case unwell

    /// Werte jeweils 0…100.
    ///
    /// Die Reihenfolge der Prüfungen ist die Rangfolge: Ein krankes Wesen
    /// schaut krank, auch wenn es gerade satt ist.
    public static func from(
        satiation: Double,
        energy: Double,
        mood: Double,
        health: Double,
        isAsleep: Bool
    ) -> CreatureMood {
        if health < 50 { return .unwell }
        if isAsleep || energy < 20 { return .sleepy }
        if satiation < 35 { return .hungry }
        if mood >= 80 { return .happy }
        return .content
    }
}

/// Stabile Farbableitung für unbekannte Paletten.
///
/// Eine Palette, die es (noch) nicht gibt, soll keine graue Box ergeben, sondern
/// eine plausible Farbe. Entscheidend ist die Betonung auf **stabil**: Swifts
/// `hashValue` wird pro Programmstart neu gesalzen — die Kreatur hätte bei jedem
/// Start eine andere Farbe. Deshalb eine eigene FNV-1a-Streuung.
public enum StableTint {

    /// Farbton im Bereich 0…<1.
    public static func hue(for palette: PaletteID) -> Double {
        let hash = fnv1a(palette.rawValue)
        return Double(hash % 3600) / 3600.0
    }

    static func fnv1a(_ text: String) -> UInt64 {
        var result: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in text.utf8 {
            result ^= UInt64(byte)
            result = result &* 0x0000_0100_0000_01B3
        }
        return result
    }
}
