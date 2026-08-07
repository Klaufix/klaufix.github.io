import CreatureSystem
import Foundation
import GameCore
import GameState
import Testing

@testable import Persistence

private let moment = Date(timeIntervalSince1970: 1_750_000_000)

private func temporaryDirectory() -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("save-tests-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func makeState(level: Int = 1) -> GameState {
    var record = CreatureRecord(
        individual: CreatureIndividual(
            id: "creature_1",
            speciesID: "sprout_youngling",
            personality: Personality(courage: 61),
            talents: CreatureTalents(vitality: 3, power: 1, resilience: 4, speed: 2),
            nickname: "Möhrchen",
            bornAt: moment
        ),
        state: CreatureState(cursor: TimeCursor(startingAt: moment))
    )
    record.state.level = level

    return GameState(
        player: PlayerState(
            deviceID: "test-device",
            activeCreatureID: "creature_1",
            random: RandomSource(seed: 42),
            cursor: TimeCursor(startingAt: moment),
            firstPlayedAt: moment
        ),
        creatures: [record]
    )
}

@Suite("Spielstand speichern und laden")
struct SaveStoreTests {

    @Test("Ein gespeicherter Spielstand kommt unverändert zurück")
    func roundTrip() throws {
        let store = SaveStore(directory: temporaryDirectory())
        let state = makeState()

        try store.save(state, at: moment)
        let loaded = try store.load()

        #expect(loaded == state)
    }

    @Test("Ohne Datei meldet der Speicher das klar")
    func emptyDirectory() {
        let store = SaveStore(directory: temporaryDirectory())

        #expect(throws: SaveError.self) { try store.load() }
    }

    @Test("Der Spielstand liegt als lesbares JSON auf der Platte")
    func fileIsReadable() throws {
        let store = SaveStore(directory: temporaryDirectory())

        try store.save(makeState(), at: moment)
        let text = try String(contentsOf: store.snapshotURL, encoding: .utf8)

        // Wer einen kaputten Spielstand untersuchen muss, soll ihn öffnen können.
        #expect(text.contains("\"saveVersion\""))
        #expect(text.contains("Möhrchen"))
    }

    @Test("Zweimal Speichern desselben Zustands ergibt dieselbe Prüfsumme")
    func checksumIsStable() throws {
        let store = SaveStore(directory: temporaryDirectory())
        let state = makeState()

        let first = try store.canonicalPayload(of: state)
        let second = try store.canonicalPayload(of: state)

        // Ohne sortierte Schlüssel wäre die Prüfsumme wertlos.
        #expect(Checksum.of(first) == Checksum.of(second))
    }

    @Test("Eine veränderte Datei wird als beschädigt erkannt")
    func detectsCorruption() throws {
        let store = SaveStore(directory: temporaryDirectory())
        try store.save(makeState(), at: moment)

        var text = try String(contentsOf: store.snapshotURL, encoding: .utf8)
        text = text.replacingOccurrences(of: "Möhrchen", with: "Rübchen")
        try text.write(to: store.snapshotURL, atomically: true, encoding: .utf8)

        #expect(throws: SaveError.self) { try store.loadFile(at: store.snapshotURL) }
    }

    @Test("Ist der aktuelle Stand unlesbar, greift die Sicherung")
    func fallsBackToBackup() throws {
        let store = SaveStore(directory: temporaryDirectory())

        try store.save(makeState(level: 3), at: moment)
        // Zweites Speichern legt den ersten Stand als Sicherung ab.
        try store.save(makeState(level: 7), at: moment.addingTimeInterval(60))

        try "kaputt".write(to: store.snapshotURL, atomically: true, encoding: .utf8)
        let loaded = try store.load()

        // Der Spieler verliert Minuten, nicht Monate.
        #expect(loaded.creatures[0].state.level == 3)
    }

    @Test("Es werden nicht beliebig viele Sicherungen aufgehoben")
    func backupsAreBounded() throws {
        let store = SaveStore(directory: temporaryDirectory())

        for index in 0..<(SaveStore.backupCount + 4) {
            try store.save(makeState(level: index + 1), at: moment)
        }

        #expect(store.availableBackups().count <= SaveStore.backupCount)
    }

    @Test("Nach dem Schreiben bleibt keine temporäre Datei liegen")
    func noTemporaryLeftovers() throws {
        let store = SaveStore(directory: temporaryDirectory())

        try store.save(makeState(), at: moment)

        let files = try FileManager.default.contentsOfDirectory(
            atPath: store.directory.path
        )
        #expect(!files.contains { $0.hasSuffix(".tmp") })
    }
}

@Suite("Migration alter Spielstände")
struct SaveMigrationTests {

    /// Ein Spielstand, wie ihn Version 1 geschrieben hätte: ohne Album, ohne
    /// Eier, ohne Mitleidszähler.
    private func versionOneObject() -> [String: Any] {
        [
            "saveVersion": 1,
            "player": [
                "deviceID": "alt-geraet",
                "random": ["seed": 42, "counters": [String: Any]()],
                "cursor": ["lastResolvedAt": 1_750_000_000.0],
                "lamport": 0,
                "unlocks": [Any](),
                "firstPlayedAt": 1_750_000_000.0,
            ] as [String: Any],
            "creatures": [Any](),
        ]
    }

    @Test("Version 1 bekommt die fehlenden Felder")
    func addsMissingFields() throws {
        let migrated = try SaveMigration.migrate(versionOneObject(), from: 1)

        #expect(migrated["album"] != nil)
        #expect(migrated["eggs"] != nil)
        #expect(migrated["saveVersion"] as? Int == GameState.currentVersion)
        let player = migrated["player"] as? [String: Any]
        #expect(player?["shimmerPityCounter"] as? Int == 0)
    }

    @Test("Ein migrierter Spielstand lässt sich dekodieren")
    func migratedStateDecodes() throws {
        let migrated = try SaveMigration.migrate(versionOneObject(), from: 1)
        let data = try JSONSerialization.data(withJSONObject: migrated, options: [.sortedKeys])

        let state = try JSONDecoder().decode(GameState.self, from: data)

        #expect(state.saveVersion == GameState.currentVersion)
        #expect(state.album.discoveredCount == 0)
        #expect(state.eggs.isEmpty)
    }

    @Test("Migration erfindet keine Historie")
    func migrationInventsNothing() throws {
        let migrated = try SaveMigration.migrate(versionOneObject(), from: 1)
        let album = migrated["album"] as? [String: Any]
        let entries = album?["entries"] as? [String: Any]

        // Wer vor Phase 7 gespielt hat, hat nichts entdeckt — das Album zu
        // füllen wäre freundlich gemeint und trotzdem gelogen.
        #expect(entries?.isEmpty == true)
    }

    @Test("Ein aktueller Spielstand bleibt unverändert")
    func currentVersionIsUntouched() throws {
        let object: [String: Any] = ["saveVersion": GameState.currentVersion]

        let migrated = try SaveMigration.migrate(object, from: GameState.currentVersion)

        #expect(migrated["album"] == nil)
    }

    @Test("Ein zu neuer Spielstand wird abgelehnt statt verstümmelt")
    func rejectsFutureVersions() {
        // Lieber eine klare Meldung als ein Spielstand, dem stillschweigend
        // Felder fehlen, weil eine neuere App sie geschrieben hat.
        #expect(throws: SaveError.self) {
            try SaveMigration.migrate([:], from: GameState.currentVersion + 1)
        }
    }
}
