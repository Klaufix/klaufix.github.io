//  ContentValidator
//
//  Laedt das Content-Verzeichnis und prueft es: Referenzintegritaet,
//  Schema-Versionen, Wertebereiche und die pruefbaren Design-Zusagen aus dem
//  GDD. Laeuft in der CI - ein Tippfehler in einer Content-Datei bricht damit
//  den Build und nicht das Spiel.
//
//  Aufruf: swift run ContentValidator <Pfad zum Content-Verzeichnis>

import Foundation
import GameContent

let arguments = CommandLine.arguments
let path = arguments.count > 1 ? arguments[1] : "Content"
let root = URL(fileURLWithPath: path, isDirectory: true)

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

var isDirectory: ObjCBool = false
guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory),
      isDirectory.boolValue
else {
    fail("Content-Verzeichnis nicht gefunden: \(root.path)")
}

let bundle: ContentBundle
do {
    bundle = try ContentLoader().load(from: [root])
} catch {
    fail("Laden fehlgeschlagen - \(error)")
}

let issues = ContentValidation.validate(bundle)
let errors = issues.filter { $0.severity == .error }
let warnings = issues.filter { $0.severity == .warning }

print(
    """
    Geladen: \(bundle.species.count) Arten, \(bundle.evolutions.count) Entwicklungen, \
    \(bundle.items.count) Items, \(bundle.cosmetics.count) Kleidungsstuecke.
    """
)

for issue in warnings {
    print(issue.description)
}

for issue in errors {
    FileHandle.standardError.write(Data((issue.description + "\n").utf8))
}

if errors.isEmpty {
    print("Content in Ordnung (\(warnings.count) Hinweise).")
    exit(0)
} else {
    fail("\(errors.count) Fehler im Content.")
}
