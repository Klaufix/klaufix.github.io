import CreatureRenderer
import DesignSystem
import FeatureAlbum
import FeatureHome
import Foundation
import GameContent
import GameCore
import GameEngine
import SwiftUI

/// Einstiegspunkt der Oberfläche.
///
/// AppComposition ist die einzige Stelle, an der Feature-Module, Engine,
/// Persistenz und Sync zusammengesteckt werden. Deshalb steht hier die
/// Wurzelansicht — und ausdrücklich keine Spiellogik.
///
/// Noch fehlt: Persistenz (Phase 8). Jeder Start beginnt daher eine neue
/// Partie, und der Inhalt kommt aus dem Fixture statt aus dem ausgelieferten
/// Content-Verzeichnis.
@MainActor
public struct RootView: View {
    @Environment(\.colorScheme) private var colorScheme

    private let model: HomeModel

    public init() {
        let content = ContentBundle.sample
        let now = Date()
        let state = NewGame.start(
            content: content,
            speciesID: "sprout_youngling",
            seed: 20_260_806,
            deviceID: "dev-device",
            now: now
        )
        model = HomeModel(engine: GameEngine(state: state, content: content))
    }

    public var body: some View {
        TabView {
            HomeView(model: model)
                .tabItem { Label("Zuhause", systemImage: "house.fill") }

            AlbumTab(model: model)
                .tabItem { Label("Album", systemImage: "book.fill") }
        }
        .systemPalette(colorScheme)
    }
}

/// Übersetzt den Spielzustand in die Anzeigedaten des Album-Moduls.
///
/// Diese Übersetzung gehört hierher: `FeatureAlbum` soll die Engine nicht
/// kennen, und `FeatureHome` nicht das Album.
@MainActor
private struct AlbumTab: View {
    let model: HomeModel

    var body: some View {
        AlbumView(
            items: model.albumItems.map { snapshot in
                AlbumItem(
                    id: snapshot.speciesID,
                    title: title(for: snapshot),
                    descriptor: snapshot.descriptor,
                    isDiscovered: snapshot.isDiscovered,
                    variants: snapshot.variants,
                    detail: snapshot.isDiscovered
                        ? "entdeckt"
                        : "gesehen in: \(snapshot.habitat)",
                    hints: snapshot.isDiscovered ? [] : []
                )
            },
            discovered: model.discoveredCount,
            nextMilestone: model.nextMilestone
        )
    }

    /// Bis es String-Kataloge gibt, wird der Schlüssel lesbar gemacht statt
    /// roh angezeigt.
    private func title(for snapshot: AlbumSnapshot) -> String {
        snapshot.speciesID
            .split(separator: "_")
            .map { $0.capitalized }
            .joined(separator: " ")
    }
}

#Preview {
    RootView()
}
