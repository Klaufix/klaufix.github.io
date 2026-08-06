import SwiftUI

/// Eine weiche Flaeche fuer zusammengehoerige Inhalte.
public struct SoftCard<Content: View>: View {
    @Environment(\.palette) private var palette

    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(Layout.spacingLarge)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Layout.corner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Layout.corner, style: .continuous)
                    .stroke(palette.outline, lineWidth: 1)
            )
    }
}

public struct PrimaryActionButton: View {
    @Environment(\.palette) private var palette

    private let title: String
    private let systemImage: String?
    private let action: () -> Void

    public init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Layout.spacingSmall) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(Typography.label)
            .padding(.horizontal, Layout.spacingLarge)
            .frame(minHeight: Layout.minimumTapTarget)
            .frame(maxWidth: .infinity)
            .background(palette.accent)
            .foregroundStyle(.white)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Anzeige eines Beduerfnisses.
///
/// Zeigt **keine Zahl**. Unterhalb des Komfort-Korridors wechselt die Farbe auf
/// `attention` - Bernstein, nie Rot: Das Beduerfnis meldet einen Wunsch, kein
/// Versaeumnis.
///
/// Der Zustand steht zusaetzlich als Wort da. Farbe ist nie der einzige Traeger
/// einer Information - weder fuer VoiceOver noch fuer farbfehlsichtige Spieler.
public struct NeedMeter: View {
    @Environment(\.palette) private var palette

    private let title: String
    private let systemImage: String
    private let fraction: Double
    private let comfortThreshold: Double
    private let stateDescription: String

    public init(
        title: String,
        systemImage: String,
        fraction: Double,
        comfortThreshold: Double = 0.3,
        stateDescription: String
    ) {
        self.title = title
        self.systemImage = systemImage
        self.fraction = min(max(fraction, 0), 1)
        self.comfortThreshold = comfortThreshold
        self.stateDescription = stateDescription
    }

    private var isBelowComfort: Bool { fraction < comfortThreshold }

    private var barColor: Color {
        isBelowComfort ? palette.attention : palette.accent
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Layout.spacingTiny) {
            HStack(spacing: Layout.spacingSmall) {
                Image(systemName: systemImage)
                    .foregroundStyle(barColor)
                Text(title)
                    .font(Typography.caption)
                    .foregroundStyle(palette.inkSoft)
                Spacer()
                Text(stateDescription)
                    .font(Typography.caption)
                    .foregroundStyle(palette.inkSoft)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(palette.accentSoft)
                    Capsule()
                        .fill(barColor)
                        .frame(width: max(proxy.size.width * fraction, 4))
                }
            }
            .frame(height: 8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(stateDescription)
    }
}

public struct TagChip: View {
    @Environment(\.palette) private var palette

    private let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(Typography.caption)
            .padding(.horizontal, Layout.spacing)
            .padding(.vertical, Layout.spacingTiny)
            .background(palette.accentSoft)
            .foregroundStyle(palette.ink)
            .clipShape(Capsule())
    }
}
