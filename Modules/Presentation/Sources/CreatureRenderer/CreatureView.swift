import DesignSystem
import GameCore
import SwiftUI

/// Farben einer Kreatur.
struct CreatureTint {
    let body: Color
    let shade: Color
    let detail: Color

    static func resolve(_ palette: PaletteID) -> CreatureTint {
        switch palette.rawValue {
        case "sprout_green":
            return CreatureTint(
                body: Color(red: 0.62, green: 0.82, blue: 0.55),
                shade: Color(red: 0.48, green: 0.70, blue: 0.43),
                detail: Color(red: 0.24, green: 0.40, blue: 0.22)
            )
        case "sprout_gold", "bloom_gold", "thorn_gold":
            return CreatureTint(
                body: Color(red: 0.95, green: 0.84, blue: 0.45),
                shade: Color(red: 0.85, green: 0.70, blue: 0.30),
                detail: Color(red: 0.45, green: 0.34, blue: 0.10)
            )
        case "bloom_pink":
            return CreatureTint(
                body: Color(red: 0.95, green: 0.74, blue: 0.82),
                shade: Color(red: 0.86, green: 0.60, blue: 0.71),
                detail: Color(red: 0.48, green: 0.25, blue: 0.34)
            )
        case "thorn_moss":
            return CreatureTint(
                body: Color(red: 0.50, green: 0.62, blue: 0.42),
                shade: Color(red: 0.38, green: 0.50, blue: 0.32),
                detail: Color(red: 0.19, green: 0.28, blue: 0.16)
            )
        default:
            // Unbekannte Palette: stabil abgeleitete Farbe statt grauer Box.
            let hue = StableTint.hue(for: palette)
            return CreatureTint(
                body: Color(hue: hue, saturation: 0.42, brightness: 0.86),
                shade: Color(hue: hue, saturation: 0.52, brightness: 0.70),
                detail: Color(hue: hue, saturation: 0.60, brightness: 0.38)
            )
        }
    }
}

/// Zeichnet eine Kreatur aus ihrem Deskriptor.
///
/// Programmatische Vektorformen statt Assets (ADR-005): Varianten und
/// Saisonformen kosten dadurch eine Farbtabelle statt einer neuen Zeichnung.
public struct CreatureView: View {
    private let descriptor: AppearanceDescriptor
    private let mood: CreatureMood
    private let size: CGFloat
    private let accessibilityDescription: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false

    public init(
        descriptor: AppearanceDescriptor,
        mood: CreatureMood,
        size: CGFloat = 180,
        accessibilityDescription: String
    ) {
        self.descriptor = descriptor
        self.mood = mood
        self.size = size
        self.accessibilityDescription = accessibilityDescription
    }

    private var tint: CreatureTint { CreatureTint.resolve(descriptor.palette) }
    private var scaled: CGFloat { size * CGFloat(descriptor.scale) }

    public var body: some View {
        ZStack {
            crest
            bodyShape
            face
        }
        .frame(width: size, height: size)
        .scaleEffect(breathing && !reduceMotion ? 1.03 : 1.0)
        .animation(breathAnimation, value: breathing)
        .onAppear { breathing = true }
        // Ein Element mit einer Beschreibung in Worten - nicht fünf Balken
        // zum Durchtabben.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    private var breathAnimation: Animation? {
        // Reduzierte Bewegung wird respektiert: Die Kreatur bleibt sichtbar
        // und lesbar, sie atmet nur nicht mehr.
        guard !reduceMotion else { return nil }
        return .easeInOut(duration: 2.6).repeatForever(autoreverses: true)
    }

    // MARK: - Körper

    private var bodyShape: some View {
        Ellipse()
            .fill(tint.body)
            .overlay(
                Ellipse()
                    .fill(tint.shade)
                    .frame(width: scaled * 0.62, height: scaled * 0.22)
                    .offset(y: scaled * 0.22)
                    .opacity(0.35)
            )
            .frame(width: scaled * 0.78, height: scaled * 0.70)
            .clipShape(Ellipse())
    }

    // MARK: - Aufsatz

    private var partNames: [String] { descriptor.parts.map(\.rawValue) }

    @ViewBuilder
    private var crest: some View {
        if partNames.contains("bloom_crown") {
            HStack(spacing: -scaled * 0.03) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(tint.shade)
                        .frame(width: scaled * 0.13, height: scaled * 0.13)
                }
            }
            .offset(y: -scaled * 0.38)
        } else if partNames.contains("thorn_crest") {
            Triangle()
                .fill(tint.detail)
                .frame(width: scaled * 0.18, height: scaled * 0.22)
                .offset(y: -scaled * 0.40)
        } else {
            // Standard: ein Blatt.
            Capsule()
                .fill(tint.shade)
                .frame(width: scaled * 0.10, height: scaled * 0.24)
                .rotationEffect(.degrees(-18))
                .offset(y: -scaled * 0.38)
        }
    }

    // MARK: - Gesicht

    private var face: some View {
        VStack(spacing: scaled * 0.05) {
            HStack(spacing: scaled * 0.16) {
                eye
                eye
            }
            mouth
        }
        .offset(y: -scaled * 0.02)
    }

    @ViewBuilder
    private var eye: some View {
        if mood == .sleepy {
            Capsule()
                .fill(tint.detail)
                .frame(width: scaled * 0.10, height: scaled * 0.02)
        } else {
            Circle()
                .fill(tint.detail)
                .frame(width: scaled * 0.075, height: scaled * 0.075)
        }
    }

    @ViewBuilder
    private var mouth: some View {
        switch mood {
        case .happy:
            Arc(upward: true)
                .stroke(tint.detail, lineWidth: max(scaled * 0.018, 1.5))
                .frame(width: scaled * 0.16, height: scaled * 0.08)
        case .content, .sleepy:
            Capsule()
                .fill(tint.detail)
                .frame(width: scaled * 0.09, height: scaled * 0.018)
        case .hungry:
            Ellipse()
                .fill(tint.detail)
                .frame(width: scaled * 0.07, height: scaled * 0.06)
        case .unwell:
            Arc(upward: false)
                .stroke(tint.detail, lineWidth: max(scaled * 0.018, 1.5))
                .frame(width: scaled * 0.14, height: scaled * 0.06)
        }
    }
}

// MARK: - Formen

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct Arc: Shape {
    let upward: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let start = CGPoint(x: rect.minX, y: upward ? rect.minY : rect.maxY)
        let end = CGPoint(x: rect.maxX, y: upward ? rect.minY : rect.maxY)
        let control = CGPoint(
            x: rect.midX,
            y: upward ? rect.maxY + rect.height : rect.minY - rect.height
        )
        path.move(to: start)
        path.addQuadCurve(to: end, control: control)
        return path
    }
}

#Preview {
    HStack(spacing: 8) {
        ForEach(CreatureMood.allCases, id: \.self) { mood in
            CreatureView(
                descriptor: AppearanceDescriptor(
                    silhouette: "round_sprout",
                    parts: ["leaf_crest"],
                    palette: "sprout_green",
                    scale: 1.0,
                    cosmetics: []
                ),
                mood: mood,
                size: 120,
                accessibilityDescription: "Vorschau"
            )
        }
    }
    .padding()
}
