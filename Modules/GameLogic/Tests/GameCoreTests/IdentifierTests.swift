import Foundation
import Testing

@testable import GameCore

@Suite("Typisierte Bezeichner")
struct IdentifierTests {

    @Test("Kodiert als schlichte Zeichenkette, damit Content-Dateien lesbar bleiben")
    func encodesAsPlainString() throws {
        let ids: [SpeciesID] = ["sprout", "ember"]

        let data = try JSONEncoder().encode(ids)

        #expect(String(decoding: data, as: UTF8.self) == #"["sprout","ember"]"#)
    }

    @Test("Ueberlebt eine Kodier-Runde unveraendert")
    func survivesRoundTrip() throws {
        let original: [ItemID] = ["herb_tea", "sun_berry"]

        let decoded = try JSONDecoder().decode(
            [ItemID].self,
            from: JSONEncoder().encode(original)
        )

        #expect(decoded == original)
    }

    @Test("Gleiche Zeichenkette bedeutet gleicher Bezeichner")
    func equatesByRawValue() {
        #expect(SpeciesID("sprout") == "sprout")
        #expect(SpeciesID("sprout") != "ember")
    }

    @Test("Laesst sich als Schluessel in Nachschlagetabellen verwenden")
    func usableAsDictionaryKey() {
        let table: [SpeciesID: Int] = ["sprout": 1, "ember": 2]

        #expect(table["sprout"] == 1)
        #expect(table["unknown"] == nil)
    }
}
