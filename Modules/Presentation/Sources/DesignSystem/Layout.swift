import CoreGraphics

/// Raster und Masse.
public enum Layout {
    // Vierer-Raster. Wer einen Wert dazwischen braucht, braucht meistens
    // stattdessen eine andere Anordnung.
    public static let spacingTiny: CGFloat = 4
    public static let spacingSmall: CGFloat = 8
    public static let spacing: CGFloat = 12
    public static let spacingLarge: CGFloat = 16
    public static let spacingSection: CGFloat = 24
    public static let spacingScreen: CGFloat = 32

    public static let cornerSmall: CGFloat = 10
    public static let corner: CGFloat = 18
    public static let cornerLarge: CGFloat = 28

    /// Kleinste zulaessige Beruehrungsflaeche.
    public static let minimumTapTarget: CGFloat = 44

    /// Anteil der Bildschirmhoehe, der der Kreatur gehoert. Sie ist die
    /// Hauptsache, nicht ein Bild neben Werten (UI-Konzept, Regel 1).
    public static let stageHeightFraction: CGFloat = 0.55
}
