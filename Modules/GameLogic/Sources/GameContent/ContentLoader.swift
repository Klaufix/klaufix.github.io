import Foundation
import GameCore

public enum ContentLoadError: Error, CustomStringConvertible {
    case directoryMissing(String)
    case fileMissing(String)
    case decodingFailed(file: String, reason: String)

    public var description: String {
        switch self {
        case .directoryMissing(let path):
            "Content-Verzeichnis fehlt: \(path)"
        case .fileMissing(let path):
            "Pflichtdatei fehlt: \(path)"
        case .decodingFailed(let file, let reason):
            "\(file): \(reason)"
        }
    }
}

/// Laedt Content aus einem Verzeichnisbaum.
///
/// Der Loader kann mehrere Quellen zusammenfuehren - App-Bundle plus spaeter
/// heruntergeladenes Paket. Deshalb nimmt `load` eine Liste von Wurzeln: Die
/// spaetere Quelle ueberschreibt gleichnamige IDs. Damit sind Content-Updates
/// ohne App-Release moeglich, ohne dass dafuer heute Infrastruktur noetig waere.
public struct ContentLoader: Sendable {
    public init() {}

    public func load(from roots: [URL]) throws -> ContentBundle {
        guard let primary = roots.first else {
            throw ContentLoadError.directoryMissing("(keine Quelle angegeben)")
        }

        var species: [SpeciesID: SpeciesDefinition] = [:]
        var evolutions: [EvolutionID: EvolutionDefinition] = [:]
        var items: [ItemID: ItemDefinition] = [:]
        var cosmetics: [CosmeticID: CosmeticDefinition] = [:]

        // Spaetere Quellen ueberschreiben gleichnamige IDs frueherer Quellen.
        for root in roots {
            for definition in try decodeAll(
                SpeciesDefinition.self, in: root, subdirectory: "species"
            ) {
                species[definition.id] = definition
            }
            for definition in try decodeAll(
                EvolutionDefinition.self, in: root, subdirectory: "evolutions"
            ) {
                evolutions[definition.id] = definition
            }
            for definition in try decodeAll(
                ItemDefinition.self, in: root, subdirectory: "items"
            ) {
                items[definition.id] = definition
            }
            for definition in try decodeAll(
                CosmeticDefinition.self, in: root, subdirectory: "cosmetics"
            ) {
                cosmetics[definition.id] = definition
            }
        }

        let chart: ElementChart = try decodeFile(
            at: primary.appendingPathComponent("climate/elements.json")
        )
        let balancing: BalancingDefinition = try decodeFile(
            at: primary.appendingPathComponent("balancing/balancing.json")
        )
        let climate: ClimateDefinition = try decodeFile(
            at: primary.appendingPathComponent("climate/climate.json")
        )

        return ContentBundle(
            species: Array(species.values),
            evolutions: Array(evolutions.values),
            items: Array(items.values),
            cosmetics: Array(cosmetics.values),
            elementChart: chart,
            balancing: balancing,
            climate: climate
        )
    }

    // MARK: - Intern

    private func decodeAll<T: Decodable>(
        _ type: T.Type,
        in root: URL,
        subdirectory: String
    ) throws -> [T] {
        let directory = root.appendingPathComponent(subdirectory)

        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            // Ein fehlendes Unterverzeichnis ist erlaubt: Eine zusaetzliche
            // Content-Quelle darf nur das mitbringen, was sie ergaenzt.
            return []
        }

        return try entries
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { try decodeFile(at: $0) }
    }

    // Der Decoder wird bei Bedarf erzeugt statt gespeichert: JSONDecoder ist eine
    // Klasse, und ein `Sendable`-Wertetyp darf sie nicht als Feld halten.
    private func decodeFile<T: Decodable>(at url: URL) throws -> T {
        guard let data = FileManager.default.contents(atPath: url.path) else {
            throw ContentLoadError.fileMissing(url.path)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw ContentLoadError.decodingFailed(
                file: url.lastPathComponent,
                reason: String(describing: error)
            )
        }
    }
}
