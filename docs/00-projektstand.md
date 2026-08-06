# Projektstand

> Letzte Aktualisierung: nach Phase 4

## Phasen

| # | Phase | Stand |
|---|---|---|
| 1 | [Game Design](01-game-design-document.md) | fertig |
| 2 | [Technische Architektur](02-technische-architektur.md) | fertig |
| 3 | [Projektstruktur](03-projektstruktur.md) | fertig |
| 4 | [Datenmodelle](04-datenmodelle.md) | fertig, **nicht kompiliert** |
| 5 | UI-Konzept | offen |
| 6 | Grundlegendes Gameplay | offen |
| 7 | Creature System | offen |
| 8 | Save System | offen |
| 9 | Cloud Sync | offen |
| 10 | Polishing | offen |

## Offener Punkt: Der Code ist noch nie gebaut worden

Das ist die wichtigste Information über dieses Repository, deshalb steht sie hier und
nicht nur in einem Chatverlauf.

**Zwei Hindernisse, beide außerhalb des Codes:**

1. **Keine Swift-Toolchain in der Entwicklungsumgebung.** `download.swift.org` ist per
   Egress-Policy gesperrt. Deshalb ist die gesamte Spiellogik UI-frei geschnitten — sie
   soll auf einem Linux-CI-Runner bauen und testen.
2. **Die CI springt bei automatisierten Pushes nicht an.** GitHub Actions ist im
   Repository aktiv (der frühere Jekyll-Workflow lief erfolgreich), aber Pushes über
   einen GitHub-App-Token lösen absichtlich keine Workflow-Läufe aus. `workflow_dispatch`
   scheitert zusätzlich, solange `ci.yml` nicht auf dem Default-Branch liegt.

**Wege, den ersten Build auszulösen** (einer genügt):

- `ci.yml` nach `main` bringen — danach ist der Workflow registriert und manuell
  auslösbar, auch für Feature-Branches.
- Einen Commit von einem persönlichen Konto auf den Branch pushen (ein leerer Commit
  reicht: `git commit --allow-empty -m "CI anstoßen"`).
- Lokal bauen:
  ```sh
  cd Modules/GameLogic && swift build && swift test
  ```

**Erwartung an den ersten Lauf:** Er wird vermutlich rot. Vier Phasen Code sind ohne
Compiler entstanden; wahrscheinliche Kandidaten sind die Paketmanifeste, `Codable`-Details
und die `swift-testing`-Syntax. Die Nacharbeit gehört zum Plan, nicht zu den Überraschungen.

## Prüfschritte, die heute schon greifen

| Prüfung | Wo | Läuft auf |
|---|---|---|
| Aufbau- und Regressionstests der Spiellogik | `swift test` | Linux + macOS |
| Content-Validierung inkl. Design-Zusagen | `swift run ContentValidator ../../Content` | Linux + macOS |
| Verbot von nichtdeterministischem Zufall (ADR-006) | CI-Schritt, `grep` | Linux |
| SwiftUI-Module | `swift build` | macOS |
| iOS-App | XcodeGen + `xcodebuild` | macOS |

## Werkzeuge

```sh
# Spiellogik bauen und testen (plattformunabhängig)
cd Modules/GameLogic && swift build && swift test

# Content prüfen
cd Modules/GameLogic && swift run ContentValidator ../../Content

# Formatierung (Konfiguration in .swift-format)
swift format --recursive --in-place Modules App

# Xcode-Projekt erzeugen
brew install xcodegen && cd App && xcodegen generate
```

> Die Formatprüfung ist bewusst **nicht** in der CI verdrahtet: Sie hier blind scharf zu
> schalten, würde nur einen roten Build erzeugen, den niemand nachvollziehen kann. Sobald
> der erste Lauf grün ist, gehört `swift format lint --strict` als Schritt dazu.
