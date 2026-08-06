import CreatureRenderer
import DesignSystem
import GameContent
import GameCore
import SwiftUI

/// Einstiegspunkt der Oberfläche.
///
/// AppComposition ist die einzige Stelle, an der Feature-Module, Engine,
/// Persistenz und Sync zusammengesteckt werden. Deshalb steht hier die
/// Wurzelansicht — und ausdrücklich keine Spiellogik.
///
/// Aktueller Inhalt ist ein **Schaubild** des Designsystems aus Phase 5: die
/// Kreatur in allen Stimmungen, die Bausteine, beide Paletten. Die eigentliche
/// Navigation zwischen den Feature-Modulen entsteht in Phase 6.
public struct RootView: View {
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        ShowcaseView()
            .systemPalette(colorScheme)
    }
}

private struct ShowcaseView: View {
    @Environment(\.palette) private var palette

    private let descriptor = AppearanceDescriptor(
        silhouette: "round_sprout",
        parts: ["leaf_crest"],
        palette: "sprout_green",
        scale: 1.0,
        cosmetics: []
    )

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Layout.spacingSection) {
                header
                moods
                needs
                actions
            }
            .padding(Layout.spacingSection)
        }
        .background(palette.canvas)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Layout.spacingSmall) {
            Text("Designsystem")
                .font(Typography.display)
                .foregroundStyle(palette.ink)
            Text("Phase 5 — Kreatur, Bausteine, Farben")
                .font(Typography.body)
                .foregroundStyle(palette.inkSoft)
        }
    }

    private var moods: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: Layout.spacing) {
                Text("Stimmungen")
                    .font(Typography.heading)
                    .foregroundStyle(palette.ink)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Layout.spacing) {
                        ForEach(CreatureMood.allCases, id: \.self) { mood in
                            VStack(spacing: Layout.spacingTiny) {
                                CreatureView(
                                    descriptor: descriptor,
                                    mood: mood,
                                    size: 110,
                                    accessibilityDescription: "Beispielkreatur, \(mood.rawValue)"
                                )
                                Text(mood.rawValue)
                                    .font(Typography.caption)
                                    .foregroundStyle(palette.inkSoft)
                            }
                        }
                    }
                }
            }
        }
    }

    private var needs: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: Layout.spacing) {
                Text("Bedürfnisse")
                    .font(Typography.heading)
                    .foregroundStyle(palette.ink)

                NeedMeter(
                    title: "Sättigung",
                    systemImage: "leaf.fill",
                    fraction: 0.72,
                    stateDescription: "zufrieden"
                )
                NeedMeter(
                    title: "Energie",
                    systemImage: "bolt.fill",
                    fraction: 0.22,
                    stateDescription: "möchte ruhen"
                )

                HStack(spacing: Layout.spacingSmall) {
                    TagChip("sommerlich")
                    TagChip("warm")
                }
            }
        }
    }

    private var actions: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: Layout.spacing) {
                Text("Aktionen")
                    .font(Typography.heading)
                    .foregroundStyle(palette.ink)

                PrimaryActionButton("Füttern", systemImage: "fork.knife") {}
                PrimaryActionButton("Streicheln", systemImage: "hand.raised.fill") {}
            }
        }
    }
}

#Preview {
    RootView()
}
