import CreatureRenderer
import DesignSystem
import SwiftUI

/// Ein Album-Eintrag als reine Anzeigedaten.
///
/// `FeatureAlbum` kennt weder Engine noch Spielzustand: Es bekommt, was es
/// zeichnen soll. Zwei Feature-Module kennen einander nicht, und keines hält
/// eine eigene Kopie des Zustands — zusammengesteckt wird an genau einer Stelle.
public struct AlbumItem: Sendable, Hashable, Identifiable {
    public let id: String
    public let title: String
    public let descriptor: AppearanceDescriptor?
    public let isDiscovered: Bool
    public let variants: [String]
    /// Fundort oder, bei entdeckten Arten, der Zeitpunkt der ersten Begegnung.
    public let detail: String
    /// Was zu einer Entwicklung noch fehlt — als Einladung, nicht als Sperre.
    public let hints: [String]

    public init(
        id: String,
        title: String,
        descriptor: AppearanceDescriptor?,
        isDiscovered: Bool,
        variants: [String] = [],
        detail: String,
        hints: [String] = []
    ) {
        self.id = id
        self.title = title
        self.descriptor = descriptor
        self.isDiscovered = isDiscovered
        self.variants = variants
        self.detail = detail
        self.hints = hints
    }
}

@MainActor
public struct AlbumView: View {
    @Environment(\.palette) private var palette

    private let items: [AlbumItem]
    private let discovered: Int
    private let nextMilestone: Int?

    public init(items: [AlbumItem], discovered: Int, nextMilestone: Int?) {
        self.items = items
        self.discovered = discovered
        self.nextMilestone = nextMilestone
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Layout.spacingSection) {
                header

                ForEach(items) { item in
                    AlbumRow(item: item)
                }
            }
            .padding(Layout.spacingSection)
        }
        .background(palette.canvas)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Layout.spacingTiny) {
            Text("Album")
                .font(Typography.display)
                .foregroundStyle(palette.ink)

            if let nextMilestone {
                Text(
                    "\(discovered) entdeckt — der nächste Meilenstein "
                        + "liegt bei \(nextMilestone)"
                )
                .font(Typography.body)
                .foregroundStyle(palette.inkSoft)
            } else {
                Text("\(discovered) entdeckt")
                    .font(Typography.body)
                    .foregroundStyle(palette.inkSoft)
            }
        }
    }
}

private struct AlbumRow: View {
    @Environment(\.palette) private var palette

    let item: AlbumItem

    var body: some View {
        SoftCard {
            HStack(alignment: .top, spacing: Layout.spacingLarge) {
                silhouette

                VStack(alignment: .leading, spacing: Layout.spacingSmall) {
                    Text(item.title)
                        .font(Typography.heading)
                        .foregroundStyle(palette.ink)

                    Text(item.detail)
                        .font(Typography.caption)
                        .foregroundStyle(palette.inkSoft)

                    if !item.variants.isEmpty {
                        HStack(spacing: Layout.spacingSmall) {
                            ForEach(item.variants, id: \.self) { TagChip($0) }
                        }
                    }

                    ForEach(item.hints, id: \.self) { hint in
                        Label(hint, systemImage: "sparkles")
                            .font(Typography.caption)
                            .foregroundStyle(palette.attention)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var silhouette: some View {
        if let descriptor = item.descriptor, item.isDiscovered {
            CreatureView(
                descriptor: descriptor,
                mood: .content,
                size: 70,
                accessibilityDescription: item.title
            )
        } else {
            // Kein leeres graues Feld: Eine Silhouette sagt „es gibt hier etwas".
            Circle()
                .fill(palette.accentSoft)
                .frame(width: 70, height: 70)
                .overlay(
                    Image(systemName: "questionmark")
                        .foregroundStyle(palette.inkSoft)
                )
        }
    }
}
