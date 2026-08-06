//  ContentValidator
//
//  Prueft das Content-Verzeichnis, bevor Inhalte im Spiel landen: Schema,
//  Referenzintegritaet (zeigt jede ID auf etwas, das es gibt?) und
//  Balancing-Plausibilitaet. Laeuft in der CI - ein Tippfehler in einer
//  Content-Datei bricht damit den Build, nicht das Spiel.
//
//  Die eigentliche Pruefung entsteht in Phase 4 zusammen mit dem Schema.
//  Bis dahin stellt dieses Werkzeug nur sicher, dass die Verzeichnisstruktur
//  vorhanden und die Pipeline verdrahtet ist.

import Foundation

let arguments = CommandLine.arguments
let contentPath = arguments.count > 1 ? arguments[1] : "Content"

let expectedDirectories = [
    "species",
    "evolutions",
    "items",
    "cosmetics",
    "quests",
    "dungeons",
    "story",
    "climate",
    "balancing",
]

var problems: [String] = []

var isDirectory: ObjCBool = false
guard FileManager.default.fileExists(atPath: contentPath, isDirectory: &isDirectory),
      isDirectory.boolValue
else {
    FileHandle.standardError.write(
        Data("Content-Verzeichnis nicht gefunden: \(contentPath)\n".utf8)
    )
    exit(1)
}

for directory in expectedDirectories {
    let path = "\(contentPath)/\(directory)"
    if !FileManager.default.fileExists(atPath: path) {
        problems.append("fehlendes Verzeichnis: \(directory)")
    }
}

if problems.isEmpty {
    print("Content-Struktur in Ordnung (\(expectedDirectories.count) Verzeichnisse).")
    print("Schema-Pruefung folgt in Phase 4.")
    exit(0)
} else {
    for problem in problems {
        FileHandle.standardError.write(Data("\(problem)\n".utf8))
    }
    exit(1)
}
