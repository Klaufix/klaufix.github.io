import CreatureRenderer
import DesignSystem
import FeatureAlbum
import FeatureHome
import Foundation
import GameContent
import GameCore
import GameEngine
import Persistence
import SwiftUI

/// Einstiegspunkt der Oberfläche.
///
/// AppComposition ist die einzige Stelle, an der Feature-Module, Engine,
/// Persistenz und Sync zusammengesteckt werden. Deshalb steht hier die
/// Wurzelansicht — und ausdrücklich keine Spiellogik.
///
/// Seit Phase 8 wird der Spielstand geladen und nach jeder Änderung
/// geschrieben, und der Inhalt kommt aus dem App-Bundle. Was noch fehlt, ist
/// der Abgleich zwischen Geräten (Phase 9).
@MainActor
public struct RootView: View {
    @Environment(\.colorScheme) private var colorScheme

    private let model: HomeModel

    public init() {
        let now = Date()

        // Content aus dem App-Bundle, mit Rückfall auf das Fixture: Eine App,
        // die beim Fehlen einer Ressource gar nicht startet, ist schlechter als
        // eine, die mit weniger Inhalt startet.
        let (content, _) = ContentSource.load(
            from: Bundle.main.url(forResource: "Content", withExtension: nil)
        )

        let store = SaveStore(directory: RootView.saveDirectory())

        // Fortsetzen, wenn es etwas fortzusetzen gibt. Nur wenn kein Spielstand
        // existiert, beginnt eine neue Partie — ein versehentlich überschriebener
        // Spielstand wäre der eine Verlust, den dieses Spiel nicht kennen darf.
        let state =
            (try? store.load())
            ?? NewGame.start(
                content: content,
                speciesID: "sprout_youngling",
                seed: UInt64(now.timeIntervalSince1970),
                deviceID: DeviceID(RootView.deviceIdentifier()),
                now: now
            )

        model = HomeModel(engine: GameEngine(state: state, content: content)) { changed in
            try? store.save(changed)
        }
    }

    /// Wohin gespeichert wird.
    static func saveDirectory() -> URL {
        let documents = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first

        return (documents ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("save", isDirectory: true)
    }

    /// Eine Kennung, die diesem Gerät bleibt.
    ///
    /// Sie landet in jedem Event und trägt später die Zusammenführung zweier
    /// Geräte — deshalb darf sie sich nicht bei jedem Start ändern.
    static func deviceIdentifier() -> String {
        let key = "device-identifier"
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }

        let fresh = UUID().uuidString
        UserDefaults.standard.set(fresh, forKey: key)
        return fresh
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
