import Foundation
import GameCore
import GameState

/// Speichert und lädt Spielstände.
///
/// Aufbau nach ADR-002: ein vollständiger Schnappschuss als Wertebaum, atomar
/// geschrieben, mit rollierenden Sicherungen. Keine Datenbank — der Spielstand
/// wird als Ganzes deterministisch fortgeschrieben, und eine ORM-Schicht brächte
/// hier Impedanz ohne Gegenwert.
///
/// Drei Zusagen:
///
/// 1. **Atomar.** Geschrieben wird in eine temporäre Datei, die anschließend an
///    ihren Platz gehoben wird. Ein Absturz mitten im Schreiben hinterlässt
///    entweder den alten oder den neuen Stand — nie einen halben.
/// 2. **Selbstheilend.** Ist der aktuelle Stand unlesbar, wird die jüngste
///    brauchbare Sicherung genommen. Der Spieler verliert Minuten, nicht Monate.
/// 3. **Migrierend.** Ältere Formate werden beim Laden hochgezogen, statt
///    abgelehnt zu werden.
public struct SaveStore: Sendable {
    public static let snapshotName = "current.save.json"
    public static let backupDirectoryName = "backups"
    /// So viele Sicherungen werden aufgehoben.
    public static let backupCount = 5

    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public var snapshotURL: URL {
        directory.appendingPathComponent(SaveStore.snapshotName)
    }

    public var backupDirectory: URL {
        directory.appendingPathComponent(SaveStore.backupDirectoryName)
    }

    // MARK: - Schreiben

    public func save(_ state: GameState, at date: Date = Date()) throws {
        let payload = try canonicalPayload(of: state)
        let envelope: [String: Any] = [
            "saveVersion": state.saveVersion,
            "savedAt": ISO8601DateFormatter().string(from: date),
            "checksum": Checksum.of(payload),
            "state": try jsonObject(from: payload),
        ]

        let data = try JSONSerialization.data(
            withJSONObject: envelope,
            options: [.sortedKeys, .prettyPrinted]
        )

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        rotateBackup()
        try writeAtomically(data, to: snapshotURL)
    }

    /// Schreibt atomar.
    ///
    /// Hier stand zuerst ein handgeschriebener Weg über eine temporäre Datei und
    /// `replaceItemAt` — mit der Begründung, die Zusage „nie ein halber
    /// Spielstand" sei zu wichtig, um sie einem Flag zu überlassen. Die CI hat
    /// diese Begründung widerlegt: `replaceItemAt` verhält sich unter Linux
    /// anders und schlug beim **zweiten** Speichern fehl, weil es die
    /// Zieldatei nicht ersetzen mochte.
    ///
    /// `Data.write(options: .atomic)` macht genau dasselbe — temporäre Datei
    /// schreiben, dann umbenennen — nur plattformrichtig. Die Zusage steht
    /// dadurch besser da als vorher, nicht schlechter.
    private func writeAtomically(_ data: Data, to url: URL) throws {
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw SaveError.unreadable(String(describing: error))
        }
    }

    /// Hebt den bisherigen Stand als Sicherung auf, bevor er überschrieben wird.
    private func rotateBackup() {
        let manager = FileManager.default
        guard manager.fileExists(atPath: snapshotURL.path) else { return }

        try? manager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)

        let stamp = Int(Date().timeIntervalSince1970)
        let target = backupDirectory.appendingPathComponent("save-\(stamp).json")
        try? manager.copyItem(at: snapshotURL, to: target)

        // Älteste Sicherungen entfernen. Bewusst nach Namen sortiert — der
        // Zeitstempel steckt darin, und Dateisystem-Daten sind es nicht wert,
        // ihnen zu vertrauen.
        let existing = (try? manager.contentsOfDirectory(
            at: backupDirectory,
            includingPropertiesForKeys: nil
        )) ?? []
        let sorted = existing
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }

        for stale in sorted.dropFirst(SaveStore.backupCount) {
            try? manager.removeItem(at: stale)
        }
    }

    // MARK: - Laden

    /// Lädt den Spielstand, notfalls aus einer Sicherung.
    public func load() throws -> GameState {
        var firstFailure: Error?

        do {
            return try loadFile(at: snapshotURL)
        } catch SaveError.noSaveFound {
            throw SaveError.noSaveFound
        } catch {
            firstFailure = error
        }

        for backup in availableBackups() {
            if let state = try? loadFile(at: backup) {
                return state
            }
        }

        throw firstFailure ?? SaveError.noSaveFound
    }

    /// Sicherungen, jüngste zuerst.
    public func availableBackups() -> [URL] {
        let existing = (try? FileManager.default.contentsOfDirectory(
            at: backupDirectory,
            includingPropertiesForKeys: nil
        )) ?? []

        return existing
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    func loadFile(at url: URL) throws -> GameState {
        guard let data = FileManager.default.contents(atPath: url.path) else {
            throw SaveError.noSaveFound
        }

        guard let envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let stateObject = envelope["state"] as? [String: Any],
            let version = envelope["saveVersion"] as? Int
        else {
            throw SaveError.malformed("Umschlag nicht lesbar.")
        }

        if let expected = envelope["checksum"] as? String {
            let actual = Checksum.of(try canonicalData(of: stateObject))
            guard actual == expected else { throw SaveError.checksumMismatch }
        }

        let migrated = try SaveMigration.migrate(stateObject, from: version)
        let payload = try canonicalData(of: migrated)

        do {
            return try JSONDecoder().decode(GameState.self, from: payload)
        } catch {
            throw SaveError.malformed(String(describing: error))
        }
    }

    // MARK: - Kanonische Form

    /// Immer dieselben Bytes für denselben Zustand.
    ///
    /// Ohne sortierte Schlüssel wäre die Prüfsumme wertlos: Wörterbücher haben
    /// keine feste Reihenfolge, und derselbe Spielstand ergäbe beim nächsten
    /// Speichern eine andere Summe.
    func canonicalPayload(of state: GameState) throws -> Data {
        let encoded = try JSONEncoder().encode(state)
        let object = try JSONSerialization.jsonObject(with: encoded)
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    func canonicalData(of object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    private func jsonObject(from data: Data) throws -> Any {
        try JSONSerialization.jsonObject(with: data)
    }
}
