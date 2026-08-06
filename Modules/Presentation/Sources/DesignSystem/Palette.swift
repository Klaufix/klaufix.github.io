import SwiftUI

/// Semantisch benannte Farben.
///
/// Die Namen beschreiben die Rolle, nicht den Farbton. Das ist keine Kosmetik:
/// Die Jahreszeiten sollen spaeter die Kulisse einfaerben, und wer im Code
/// `Color.green` schreibt, hat den Winter schon verloren.
///
/// Bewusst **kein Alarmrot**. Die staerkste Warnfarbe ist `attention`, ein warmes
/// Bernstein - es bedeutet „moechte etwas", nicht „du hast versagt".
public struct Palette: Equatable {
    public let canvas: Color
    public let surface: Color
    public let surfaceRaised: Color
    public let ink: Color
    public let inkSoft: Color
    public let accent: Color
    public let accentSoft: Color
    public let attention: Color
    public let positive: Color
    public let outline: Color

    public init(
        canvas: Color,
        surface: Color,
        surfaceRaised: Color,
        ink: Color,
        inkSoft: Color,
        accent: Color,
        accentSoft: Color,
        attention: Color,
        positive: Color,
        outline: Color
    ) {
        self.canvas = canvas
        self.surface = surface
        self.surfaceRaised = surfaceRaised
        self.ink = ink
        self.inkSoft = inkSoft
        self.accent = accent
        self.accentSoft = accentSoft
        self.attention = attention
        self.positive = positive
        self.outline = outline
    }

    public static var day: Palette {
        Palette(
            canvas: Color(red: 0.96, green: 0.95, blue: 0.90),
            surface: Color(red: 1.00, green: 0.99, blue: 0.96),
            surfaceRaised: Color(red: 1.00, green: 1.00, blue: 1.00),
            ink: Color(red: 0.22, green: 0.20, blue: 0.18),
            inkSoft: Color(red: 0.45, green: 0.42, blue: 0.38),
            accent: Color(red: 0.36, green: 0.62, blue: 0.47),
            accentSoft: Color(red: 0.80, green: 0.90, blue: 0.82),
            attention: Color(red: 0.87, green: 0.65, blue: 0.28),
            positive: Color(red: 0.42, green: 0.68, blue: 0.52),
            outline: Color(red: 0.85, green: 0.83, blue: 0.77)
        )
    }

    public static var night: Palette {
        Palette(
            canvas: Color(red: 0.13, green: 0.14, blue: 0.18),
            surface: Color(red: 0.18, green: 0.19, blue: 0.24),
            surfaceRaised: Color(red: 0.23, green: 0.24, blue: 0.30),
            ink: Color(red: 0.94, green: 0.93, blue: 0.90),
            inkSoft: Color(red: 0.70, green: 0.69, blue: 0.67),
            accent: Color(red: 0.52, green: 0.78, blue: 0.63),
            accentSoft: Color(red: 0.24, green: 0.34, blue: 0.30),
            attention: Color(red: 0.93, green: 0.75, blue: 0.42),
            positive: Color(red: 0.55, green: 0.80, blue: 0.64),
            outline: Color(red: 0.32, green: 0.33, blue: 0.39)
        )
    }

    public static func forScheme(_ scheme: ColorScheme) -> Palette {
        scheme == .dark ? .night : .day
    }
}

private struct PaletteKey: EnvironmentKey {
    static var defaultValue: Palette { .day }
}

extension EnvironmentValues {
    /// Die aktive Palette. Ueber die Umgebung austauschbar - eine saisonale oder
    /// eine Event-Palette ist damit ein Eingriff an genau einer Stelle.
    public var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

extension View {
    /// Setzt die Palette passend zum Hell/Dunkel-Modus des Systems.
    public func systemPalette(_ scheme: ColorScheme) -> some View {
        environment(\.palette, Palette.forScheme(scheme))
    }
}
