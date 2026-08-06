import SwiftUI

/// Schriftrollen.
///
/// Durchgehend `design: .rounded` - runde Schrift passt zum Cartoon-Stil und
/// liest sich freundlich.
///
/// Alle Rollen bauen auf **relativen Textstilen** auf, nie auf festen
/// Punktgroessen. Dynamic Type funktioniert dadurch ohne eine einzige
/// Sonderbehandlung; feste Groessen waeren die haeufigste Ursache dafuer, dass
/// eine App bei grosser Schrift auseinanderfaellt.
public enum Typography {
    public static var display: Font { .system(.largeTitle, design: .rounded, weight: .bold) }
    public static var title: Font { .system(.title2, design: .rounded, weight: .semibold) }
    public static var heading: Font { .system(.headline, design: .rounded, weight: .semibold) }
    public static var body: Font { .system(.body, design: .rounded) }
    public static var caption: Font { .system(.caption, design: .rounded) }
    public static var label: Font { .system(.subheadline, design: .rounded, weight: .medium) }
}
