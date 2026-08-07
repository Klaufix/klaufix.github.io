import CreatureRenderer
import DesignSystem
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
        HomeView(model: model)
            .systemPalette(colorScheme)
    }
}

#Preview {
    RootView()
}
