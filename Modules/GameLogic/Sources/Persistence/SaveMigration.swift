import Foundation
import GameCore
import GameState

/// Migration alter Spielstände.
///
/// Migriert wird **das JSON, nicht der Typ**. Der Grund: Ein alter Spielstand
/// lässt sich gar nicht erst in den heutigen `GameState` dekodieren — ihm fehlen
/// Felder, die inzwischen Pflicht sind. Erst nachdem die Rohdaten auf den
/// aktuellen Stand gebracht wurden, entsteht daraus ein Zustand.
///
/// Jeder Schritt bringt genau eine Version weiter. Die Kette ist dadurch
/// einzeln testbar, und ein Spielstand von Version 1 läuft dieselben Schritte
/// durch wie einer von Version 3 — nur mehr davon.
public enum SaveMigration {

    /// Ein Migrationsschritt: von `from` auf `from + 1`.
    struct Step {
        let from: Int
        let apply: ([String: Any]) -> [String: Any]
    }

    /// Berechnet statt gespeichert.
    ///
    /// Ein `static let` waere globaler Zustand, und ein Schritt haelt eine
    /// Funktion auf `[String: Any]` - das ist nicht `Sendable` und laesst sich
    /// unter Swift 6 auch nicht dazu erklaeren. Die Liste bei Bedarf zu bauen
    /// kostet nichts und macht die Frage gegenstandslos.
    static var steps: [Step] {
        [
            Step(from: 1, apply: migrateOneToTwo)
        ]
    }

    /// Bringt ein Spielstand-JSON auf die aktuelle Version.
    public static func migrate(
        _ object: [String: Any],
        from version: Int
    ) throws -> [String: Any] {
        guard version <= GameState.currentVersion else {
            throw SaveError.versionTooNew(
                found: version,
                supported: GameState.currentVersion
            )
        }

        var current = object
        var currentVersion = version

        while currentVersion < GameState.currentVersion {
            guard let step = steps.first(where: { $0.from == currentVersion }) else {
                throw SaveError.malformed(
                    "Kein Migrationsschritt von Version \(currentVersion)."
                )
            }
            current = step.apply(current)
            currentVersion += 1
            current["saveVersion"] = currentVersion
        }

        return current
    }

    // MARK: - Schritte

    /// Version 1 → 2: Album, Eier und der Mitleidszähler sind dazugekommen.
    ///
    /// Ein Spielstand aus Version 1 hatte all das nicht. Er bekommt leere
    /// Sammlungen — **nicht** etwa eine nachträglich erfundene Historie: Was
    /// nicht passiert ist, wird nicht erfunden.
    static func migrateOneToTwo(_ object: [String: Any]) -> [String: Any] {
        var result = object

        if result["album"] == nil {
            result["album"] = ["entries": [String: Any]()]
        }
        if result["eggs"] == nil {
            result["eggs"] = [Any]()
        }
        if var player = result["player"] as? [String: Any] {
            if player["shimmerPityCounter"] == nil {
                player["shimmerPityCounter"] = 0
            }
            result["player"] = player
        }

        return result
    }
}
