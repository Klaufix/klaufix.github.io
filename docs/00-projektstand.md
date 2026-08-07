# Projektstand

> Letzte Aktualisierung: nach Phase 7

## Phasen

| # | Phase | Stand |
|---|---|---|
| 1 | [Game Design](01-game-design-document.md) | fertig |
| 2 | [Technische Architektur](02-technische-architektur.md) | fertig |
| 3 | [Projektstruktur](03-projektstruktur.md) | fertig |
| 4 | [Datenmodelle](04-datenmodelle.md) | fertig, CI grün |
| 5 | [UI-Konzept](05-ui-konzept.md) | fertig, CI grün |
| 6 | [Grundlegendes Gameplay](06-grundlegendes-gameplay.md) | fertig, CI grün |
| 7 | [Creature System](07-creature-system.md) | fertig |
| 8 | Save System | offen |
| 9 | Cloud Sync | offen |
| 10 | Polishing | offen |

## Erster Build: grün

Der Code der Phasen 1–4 ist entstanden, ohne je kompiliert worden zu sein — in der
Entwicklungsumgebung war keine Swift-Toolchain verfügbar (`download.swift.org` per
Egress-Policy gesperrt). Genau dafür ist die Spiellogik UI-frei geschnitten: Sie baut
und testet auf einem Linux-Runner, ohne Apple-Hardware.

**Alle Läufe seit Commit `e77299a`: drei von drei Jobs erfolgreich.**

| Job | Umfang |
|---|---|
| `Spiellogik (Linux)` | `swift build`, 78 Tests, Content-Validierung, ADR-006-Regel |
| `Darstellung (macOS)` | `swift build` und Tests der SwiftUI-Module |
| `App (iOS)` | XcodeGen + `xcodebuild` |

Lauf 1 fand genau einen echten Fehler: `clamped()` warf jeden nicht-endlichen Wert aufs
Minimum, sodass ein beschädigter Spielstand mit `Infinity` eine hungernde Kreatur ergeben
hätte. Behoben — Unendlichkeiten werden nach Vorzeichen begrenzt, nur `NaN` fällt zurück.
Beide Paketmanifeste, die `Codable`-Details und die `swift-testing`-Syntax stimmten auf
Anhieb.

### CI-Läufe auslösen

Pushes über einen GitHub-App-Token lösen **absichtlich keine** Workflow-Läufe aus. Läufe
entstehen daher entweder durch einen Push von einem persönlichen Konto oder manuell:

```sh
gh workflow run ci.yml --ref <branch>
```

Ein Hinweis aus der Praxis: Ein Lauf blieb einmal über eine Stunde in der
Warteschlange stehen und ließ sich nicht einmal abbrechen (409 vom API). Da die
Concurrency-Gruppe nur aus Workflow und Branch bestand, blockierte dieser tote Lauf
jeden weiteren Lauf desselben Branches. Die Gruppe enthält deshalb jetzt zusätzlich
den Commit.

Voraussetzung dafür ist, dass `ci.yml` auf dem Default-Branch liegt — das ist seit dem
Merge von PR #1 der Fall.

## Prüfschritte, die greifen

| Prüfung | Wo | Läuft auf |
|---|---|---|
| 78 Tests der Spiellogik | `swift test` | Linux + macOS |
| Content-Validierung inkl. Design-Zusagen | `swift run ContentValidator ../../Content` | Linux + macOS |
| Verbot von nichtdeterministischem Zufall (ADR-006) | CI-Schritt, `grep` | Linux |
| SwiftUI-Module und Renderer-Tests | `swift build`, `swift test` | macOS |
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

> Die Formatprüfung ist noch **nicht** in der CI verdrahtet. Sinnvoll wird der Schritt
> erst nach einem einmaligen `swift format --in-place` über den Bestand — sonst meldet er
> beim ersten Lauf hunderte Abweichungen auf einmal. Der Durchlauf braucht eine Maschine
> mit Swift-Toolchain; danach gehört `swift format lint --strict` als Schritt dazu.
