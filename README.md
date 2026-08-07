# Projekt „NUBI" — Virtual-Pet-RPG für iOS

Ein Cozy-Virtual-Pet-RPG für iOS (SwiftUI): Tamagotchi-Pflege, Pokémon-artiges Sammeln
und Entwickeln, kurze RPG-Ausflüge — ohne Bestrafung, ohne Grind.

> *Arbeitstitel. Der Name taucht bewusst nirgends im Code auf.*

> **Stand:** Phasen 1–8 abgeschlossen — die App ist spielbar: Die Zeit läuft in Echtzeit
> weiter, die Kreatur reagiert, man kann sie füttern, streicheln und schlafen legen.
> Details im [Projektstand](docs/00-projektstand.md).

## Dokumentation

| Dokument | Phase | Status |
|---|---|---|
| [Projektstand](docs/00-projektstand.md) | – | laufend |
| [Game Design Dokument](docs/01-game-design-document.md) | Phase 1 | ✅ v0.1 |
| [Technische Architektur](docs/02-technische-architektur.md) | Phase 2 | ✅ v0.1 |
| [Projektstruktur](docs/03-projektstruktur.md) | Phase 3 | ✅ v0.1 |
| [Datenmodelle](docs/04-datenmodelle.md) | Phase 4 | ✅ v0.1 |
| [UI-Konzept](docs/05-ui-konzept.md) | Phase 5 | ✅ v0.1 |
| [Grundlegendes Gameplay](docs/06-grundlegendes-gameplay.md) | Phase 6 | ✅ v0.1 |
| [Creature System](docs/07-creature-system.md) | Phase 7 | ✅ v0.1 |
| [Save System](docs/08-save-system.md) | Phase 8 | ✅ v0.1 |
| Cloud Sync | Phase 9 | ⏳ als Nächstes |

## Meilensteinplan

| # | Phase | Ergebnis |
|---|---|---|
| 1 | Game Design | GDD, Design-Säulen, Systemübersicht |
| 2 | Technische Architektur | Modulschnitt, Datenfluss, Persistenz-/Sync-Strategie, ADRs |
| 3 | Projektstruktur | Swift Package Module, Build-Setup, Content-Pipeline |
| 4 | Datenmodelle | Species/Individual/State, Content-Schema, Migrationen |
| 5 | UI-Konzept | Screenflow, Designsystem, Barrierefreiheit |
| 6 | Grundlegendes Gameplay | Zeitsimulation, Pflegeschleife, erster spielbarer Build |
| 7 | Creature System | Persönlichkeit, Evolution, Zucht, Album |
| 8 | Save System | lokale Persistenz, Migration, Manipulationsschutz |
| 9 | Cloud Sync | geräteübergreifende Synchronisation, Backup |
| 10 | Polishing | Balancing, Performance, Feinschliff |

Nach jeder Phase: prüfen · testen · dokumentieren · Verbesserungsvorschläge.

## Festgelegte Rahmenentscheidungen

| Thema | Entscheidung |
|---|---|
| Plattform | iOS 18+, SwiftUI, Swift 6 |
| Persistenz | Snapshot + Event-Journal (lokal, atomar, versioniert) |
| Cloud | Schnittstelle vorbereitet, Backend-Entscheidung in Phase 9 |
| Wetter | simuliertes Spielwetter (deterministisch, ohne Standortzugriff) |
| Grafik | programmatische Vektor-Darstellung, Assets später austauschbar |

## Aufbau

```
App/          dünnes iOS-App-Ziel (Xcode-Projekt wird aus project.yml generiert)
Modules/
  GameLogic/    Swift Package · plattformunabhängig, UI-frei, unter Linux testbar
  Presentation/ Swift Package · SwiftUI
Content/      Spielinhalte als JSON
docs/         Phasendokumente
```

### Bauen

```sh
cd Modules/GameLogic && swift build && swift test     # Spiellogik, überall
cd Modules/Presentation && swift build                # UI, nur Apple-Plattformen
brew install xcodegen && cd App && xcodegen generate  # Xcode-Projekt erzeugen
```

```sh
cd Modules/GameLogic && swift run ContentValidator ../../Content   # Inhalte prüfen
swift format --recursive --in-place Modules App                   # Formatierung
```

## Leitprinzipien

1. **Modularität** — jedes System (Creature, Inventory, Battle, Story, Dungeon, Wetter,
   Jahreszeiten, Kleidung, Zucht, Album, Multiplayer) ist ein eigenständiges Modul mit
   klarer Schnittstelle und ohne Wissen über die anderen.
2. **Alles ist Daten** — neue Inhalte entstehen durch Content-Dateien, nicht durch Code.
3. **Keine Bestrafung** — kein Tod, kein permanenter Verlust, kein FOMO.
4. **Erweiterbar über Jahre** — neue Regionen, Gilden, Koop, Housing, Berufe sind im
   Architekturentwurf bereits vorgesehen.
