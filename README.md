# Projekt „NUBI" — Virtual-Pet-RPG für iOS

Ein Cozy-Virtual-Pet-RPG für iOS (SwiftUI): Tamagotchi-Pflege, Pokémon-artiges Sammeln
und Entwickeln, kurze RPG-Ausflüge — ohne Bestrafung, ohne Grind.

> *Arbeitstitel. Der Name taucht bewusst nirgends im Code auf.*

## Dokumentation

| Dokument | Phase | Status |
|---|---|---|
| [Game Design Dokument](docs/01-game-design-document.md) | Phase 1 | ✅ Entwurf v0.1 |
| [Technische Architektur](docs/02-technische-architektur.md) | Phase 2 | ✅ Entwurf v0.1 |
| Projektstruktur | Phase 3 | ⏳ als Nächstes |
| Datenmodelle | Phase 4 | – |
| UI-Konzept | Phase 5 | – |

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

## Leitprinzipien

1. **Modularität** — jedes System (Creature, Inventory, Battle, Story, Dungeon, Wetter,
   Jahreszeiten, Kleidung, Zucht, Album, Multiplayer) ist ein eigenständiges Modul mit
   klarer Schnittstelle und ohne Wissen über die anderen.
2. **Alles ist Daten** — neue Inhalte entstehen durch Content-Dateien, nicht durch Code.
3. **Keine Bestrafung** — kein Tod, kein permanenter Verlust, kein FOMO.
4. **Erweiterbar über Jahre** — neue Regionen, Gilden, Koop, Housing, Berufe sind im
   Architekturentwurf bereits vorgesehen.
