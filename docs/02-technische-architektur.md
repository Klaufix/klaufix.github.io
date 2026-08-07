# Technische Architektur — Projekt „NUBI"

> **Status:** Phase 2 — Entwurf v0.1
> **Grundlage:** [Game Design Dokument](01-game-design-document.md)

---

## 1. Festgelegte Rahmenentscheidungen

| Thema | Entscheidung | Auswirkung |
|---|---|---|
| Plattform | iOS 18+, SwiftUI, Swift 6 (strict concurrency) | `@Observable`, moderne SwiftUI-Animationen, keine Alt-Last |
| Cloud | **zunächst rein lokal**, Sync-Schnittstelle von Anfang an abstrahiert | Backend-Entscheidung fällt erst in Phase 9 — Architektur bleibt offen für CloudKit *und* Firebase |
| Wetter | **simuliertes Spielwetter**, kein WeatherKit | Voll deterministisch, testbar, keine Berechtigungen, planbarer Content |
| Grafik | **programmatische Vektor-Darstellung** aus modularen Teilen | Kreaturen-Aussehen ist Daten; echte Illustrationen später per Adapter austauschbar |
| iPad | später, aber Layout von Anfang an adaptiv | keine fixen Größen, `NavigationSplitView`-fähige Screenflows |

### 1.1 Randbedingung der Entwicklungsumgebung

In der aktuellen Arbeitsumgebung ist **keine Swift-Toolchain verfügbar**
(`download.swift.org` ist per Egress-Policy gesperrt). Konsequenz:

- Swift-Code kann hier geschrieben, aber **nicht lokal kompiliert oder ausgeführt** werden.
- Die Verifikation läuft ab Phase 3 über **GitHub Actions auf einem macOS-Runner**
  (`swift build` + `swift test` für die Domänenmodule, `xcodebuild` für die App).
- Deshalb ist es doppelt wichtig, dass die Spiellogik **plattformunabhängig und
  UI-frei** ist: diese Module lassen sich auch ohne Apple-Hardware bauen und testen.

---

## 2. Architekturziele

1. **Compiler-erzwungene Modularität** — Modulgrenzen sind nicht Konvention, sondern
   SwiftPM-Targets. Ein System kann ein anderes gar nicht importieren.
2. **Determinismus** — gleicher Ausgangszustand + gleiche Eingaben = exakt gleiches
   Ergebnis. Voraussetzung für Tests, Sync-Merge und späteren Server-Abgleich.
3. **Content statt Code** — neue Kreaturen, Evolutionen, Items, Quests, Dungeons und
   Events sind Datendateien.
4. **Multiplayer-fähige Grundform, ohne Multiplayer zu bauen** — jede Zustandsänderung
   ist ein serialisierbares Ereignis. Damit ist eine spätere Server-Autorität möglich,
   ohne die Spiellogik neu zu schreiben.
5. **Testbarkeit der Design-Säulen** — „keine Bestrafung" ist keine Absicht, sondern eine
   Invariante, die von Tests überwacht wird.

---

## 3. Schichtenmodell

```
┌──────────────────────────────────────────────────────────────────┐
│  APP-SCHICHT            iOS-spezifisch, SwiftUI                  │
│  App · Feature-Module (Home, Album, Expedition, Battle, …)       │
│  DesignSystem · CreatureRenderer                                 │
└───────────────────────────┬──────────────────────────────────────┘
                            │  Commands ↓        State ↑
┌───────────────────────────┴──────────────────────────────────────┐
│  ENGINE-SCHICHT         plattformunabhängig                      │
│  GameEngine — nimmt Commands, verteilt an Systeme,               │
│               erzeugt Events, wendet sie auf GameState an        │
└───────────────────────────┬──────────────────────────────────────┘
                            │
┌───────────────────────────┴──────────────────────────────────────┐
│  SYSTEM-SCHICHT         plattformunabhängig, gegenseitig blind   │
│  CreatureSystem · InventorySystem · WardrobeSystem ·             │
│  BattleSystem · ExpeditionSystem · BreedingSystem ·              │
│  QuestSystem · StorySystem · ClimateSystem · AlbumSystem ·       │
│  ProgressionSystem · (später) MultiplayerSystem                  │
└───────────────────────────┬──────────────────────────────────────┘
                            │
┌───────────────────────────┴──────────────────────────────────────┐
│  KERN-SCHICHT           plattformunabhängig, ohne Spiellogik     │
│  GameCore (IDs, Zeit, RNG, Events, Commands)                     │
│  GameContent (Schema, Laden, Validierung)                        │
│  GameRules (Bedingungs-Evaluator, Formeln)                       │
└───────────────────────────┬──────────────────────────────────────┘
                            │
┌───────────────────────────┴──────────────────────────────────────┐
│  INFRASTRUKTUR                                                   │
│  Persistence (Snapshot + Journal) · SyncCore (abstrakt) ·        │
│  Notifications · Audio                                           │
└──────────────────────────────────────────────────────────────────┘
```

**Abhängigkeitsregel (vom Compiler erzwungen):**
Kern ← Systeme ← Engine ← Features ← App.
Ein System darf **niemals** ein anderes System importieren. Systemübergreifende Wirkung
entsteht ausschließlich über Events.

---

## 4. Das Kernmuster: Command → Event → State

Der zentrale Mechanismus, aus dem sich Modularität, Testbarkeit, Sync-Fähigkeit und
Multiplayer-Vorbereitung gleichzeitig ergeben.

```
Benutzeraktion / Zeitablauf
        │
        ▼
   GameCommand                 „Ich möchte Kreatur X mit Item Y füttern"
        │                       (Absicht, kann scheitern)
        ▼
   CommandHandler              liest Zustand nur lesend, prüft Regeln,
   (im zuständigen System)      würfelt aus benanntem RNG-Strom
        │
        ▼
   [GameEvent]                 „Kreatur X hat Y gegessen (+30 Sättigung)",
        │                       „Item Y verbraucht", „Quest-Fortschritt +1"
        │                       (Fakten, Codable, unveränderlich)
        ▼
   Reducer aller Systeme       jedes System wendet die Events an, die es betreffen —
        │                       CreatureSystem, InventorySystem, QuestSystem und
        ▼                       AlbumSystem reagieren unabhängig auf dasselbe Event
   GameState (neu)
        │
        ├──► UI (@Observable Snapshot)
        ├──► Event-Journal (Persistenz + späterer Sync)
        └──► Analytics / Achievements (nur Beobachter)
```

**Warum das genau die Anforderungen erfüllt:**

| Anforderung | Wie das Muster sie erfüllt |
|---|---|
| Module unabhängig | Systeme kennen einander nicht, nur gemeinsame Event-Typen |
| Neue Inhalte ohne Code | Handler lesen Regeln aus Content, nicht aus `if`-Kaskaden |
| Multiplayer später | Events sind serialisierbar → Server kann sie validieren/verteilen |
| Cloud Sync | Journal ist eine Ereignisliste → merge-fähig statt „letzter gewinnt" |
| Kein Datenverlust | Snapshot + Journal erlaubt Wiederherstellung durch Replay |
| Testbarkeit | Ein Test ist: Zustand + Command → erwartete Event-Liste |

**Kosten:** mehr Zeremonie als direkte Mutation, und Events müssen versioniert werden.
Beides ist der Preis für ein System, das über Jahre wachsen soll.

---

## 5. Modulkatalog (SwiftPM-Targets)

### Kern
| Modul | Verantwortung | Kennt |
|---|---|---|
| `GameCore` | Typisierte IDs, `GameClock`, `SeededRandom`, `GameEvent`/`GameCommand`-Protokolle, Basiswertetypen, **Form** der Bedingungsausdrücke | – |
| `GameContent` | Content-Schema, Laden, Referenz-Validierung, Schema-Version | GameCore |
| `GameRules` | **Auswertung** der Bedingungen (`FactProvider`, `ConditionEvaluator`), Formeln, Balancing-Kurven | GameCore, GameContent |

### Systeme (je ein Target, gegenseitig blind)
| Modul | Verantwortung |
|---|---|
| `CreatureSystem` | Bedürfnisse, Zeitfortschritt pro Kreatur, Persönlichkeit, Level/EP, Freundschaft, Evolution, Zustände |
| `InventorySystem` | Items, Stapel, Materialien, Kochen/Handwerk |
| `WardrobeSystem` | Kleidungs-Slots, Tags, Freischaltungen |
| `ClimateSystem` | Wetter-Simulation, Jahreszeiten, Tageszeit, Mondphase |
| `ExpeditionSystem` | Dungeon-Knotengraph, Ereignistabellen, Beutetabellen |
| `BattleSystem` | Rundenlogik, Schwung, Haltungen, Elementmatrix, Gegner-KI |
| `BreedingSystem` | Paarung, Ei-Reifung, Vererbung, Pity-Zähler |
| `QuestSystem` | Quest-Definitionen, Fortschritt, Wochen-Puffer, Belohnungen |
| `StorySystem` | Kapitel, Dialoge, Freischaltungen, Skip-Pfad |
| `AlbumSystem` | Entdeckungen, Varianten, Fundorte, Meilensteine |
| `ProgressionSystem` | Achievements, Titel, Saisonpfad, Freischalt-Registry |
| `EconomySystem` | Währungen, Shop, IAP-Berechtigungen (kosmetisch) |

### Engine & Zustand
| Modul | Verantwortung |
|---|---|
| `GameState` | Aggregierter Zustandsbaum aus allen System-Teilzuständen, `Codable` |
| `GameEngine` | Command-Dispatch, Event-Anwendung, Zeitauflösung, Snapshot-Erzeugung |

### Infrastruktur
| Modul | Verantwortung |
|---|---|
| `Persistence` | Atomares Snapshot-Schreiben, Event-Journal, Migrationen |
| `SyncCore` | `SyncBackend`-Protokoll, Merge-Strategie, Geräte-IDs — **ohne** konkretes Backend |
| `NotificationCenterKit` | lokale Benachrichtigungen (sanft, opt-in, nie mahnend) |
| `AudioSystem` | Musik/SFX, saisonabhängige Themes |

### Darstellung
| Modul | Verantwortung |
|---|---|
| `DesignSystem` | Farben, Typografie, Abstände, Komponenten, Light/Dark, Dynamic Type |
| `CreatureRenderer` | Vektor-Darstellung aus `AppearanceDescriptor`, Animationen, Kleidungs-Layer |
| `Feature*` | Ein SwiftUI-Modul je Bildschirmbereich, spricht nur mit `GameEngine` |

---

## 6. Zeitmodell

### 6.1 Zeitstempelbasierte Auflösung
Es läuft **kein Timer**. Beim App-Start (und bei Rückkehr aus dem Hintergrund) berechnet
die Engine die verstrichene Zeit einmalig.

```
resolve(from: lastResolvedAt, to: now)
  → in Segmente zerlegen an: Tagesgrenze · Jahreszeitwechsel · Wetterwechsel · Schlafphasen
  → je Segment: TimeElapsed-Event mit Kontext (Wetter, Jahreszeit, Tageszeit)
  → Systeme reagieren unabhängig (Hunger, Pflanzen, Eier, Quests, Genesung)
```

Segmentierung ist nötig, damit „14 Tage weg" nicht als ein einziger, kontextloser Block
verrechnet wird, sondern Jahreszeit- und Wetterwirkungen korrekt greifen.

### 6.2 Gedämpfte Kurve & Boden
Der Verfall folgt der im GDD definierten asymptotischen Kurve mit hartem Boden bei 25 %.
Die Kurve liegt als **Content-Parameter** vor, nicht als Konstante im Code.

### 6.3 Schutz gegen Zeitmanipulation
- Persistierter `lastResolvedAt` + monotoner Zähler; **Zeit läuft nie rückwärts** —
  eine zurückgestellte Uhr führt zu 0 Fortschritt, nie zu negativem.
- Vorwärtssprünge werden auf 30 Tage pro Auflösung gedeckelt (Rechenaufwand begrenzt,
  Missbrauch unattraktiv).
- Kein Strafmechanismus: Manipulation wird ignoriert, nicht sanktioniert.
- Bei späterem Cloud-Sync liefert der Server eine Referenzzeit.

### 6.4 Zufall
`SeededRandom` mit **benannten Strömen**: `.breeding`, `.expedition`, `.spawn`, `.loot`.
Seed und Zählerstand liegen im Save. Folgen:
- Tests sind reproduzierbar.
- Save-Scumming (App killen und neu würfeln) funktioniert nicht — dasselbe Ergebnis
  kommt wieder. Das ist Fairness, keine Bestrafung.

---

## 7. Content-Pipeline

```
Content/*.json  ──►  Validator (Build-Schritt + CI)  ──►  ContentBundle (im App-Bundle)
   Autorensicht        Schema · Referenzintegrität         typisierte, indizierte
                       · Balancing-Plausibilität           Nur-Lese-Datenbank
```

- **Format:** JSON — nativ `Codable`, keine Fremdabhängigkeit, gut diffbar.
- **Typisierte IDs:** `SpeciesID`, `ItemID`, `QuestID` … als eigene Typen. Der Validator
  prüft, dass jede referenzierte ID existiert. Ein Tippfehler bricht die CI, nicht das Spiel.
- **Schema-Version** je Datei; der Loader kann alte Versionen migrieren.
- **Erweiterung im Betrieb:** Der Bundle-Loader kann mehrere Quellen zusammenführen
  (App-Bundle + heruntergeladenes Paket). Damit sind spätere Content-Updates ohne
  App-Release möglich, ohne dass jetzt Infrastruktur gebaut werden muss.

**Regel:** Wenn ein neuer Inhalt eine Codeänderung erfordert, ist entweder das Schema
oder der Regel-Evaluator unvollständig — nicht der Inhalt außergewöhnlich.

---

## 8. Der Regel-Evaluator (`GameRules`)

> **Nachtrag aus Phase 4:** Der *Datentyp* `ConditionExpression` liegt in `GameCore`,
> nicht hier — `GameContent` speichert Bedingungen in Evolutionen, und `GameRules` hängt
> von `GameContent` ab; andernfalls entstünde ein Zyklus. Die *Auswertung* bleibt wie
> beschrieben in `GameRules`. Daten nach unten, Verhalten oben.

Ein einziger, generischer Bedingungs-Auswerter bedient **alle** Systeme:
Evolution, Quest-Ziele, Spawn-Tabellen, Event-Verfügbarkeit, Shop-Sichtbarkeit,
Dialog-Verzweigungen, Achievements.

```
ConditionExpression
 ├ .all([…])            alle erfüllt
 ├ .any([…])            mindestens eine
 ├ .not(…)
 └ .check(Fact, Comparator, Value)

Fact  = level | friendship | personality(axis) | season | weather | timeOfDay
      | itemUsed | foodEaten(tag) | dungeonCleared | battlesWon | daysOwned
      | questCompleted | equippedTag | moonPhase | albumCount | …
```

Ein neuer `Fact` ist die einzige Codeänderung, die ein neuer Inhaltstyp je braucht —
und danach steht er allen Systemen gleichzeitig zur Verfügung. Facts werden aus einem
schmalen `FactProvider` gelesen, den die Engine bereitstellt; die Systeme selbst bleiben
dadurch weiterhin voneinander unabhängig.

---

## 9. Persistenz

### Entscheidung: Snapshot + Event-Journal statt Datenbank als Quelle der Wahrheit

```
Documents/
 ├ save/current.snapshot      vollständiger GameState, Codable, atomar geschrieben
 ├ save/journal.log           angehängte Events seit letztem Snapshot
 └ save/backups/…             rollierende Snapshots (3 Generationen + täglich)
```

- Schreiben beim App-Hintergrund, bei größeren Ereignissen und alle 60 Sek.
- **Atomar** (temporäre Datei + `replaceItem`) → kein halber Spielstand bei App-Kill.
- **Selbstheilung:** Ist der Snapshot beschädigt, wird der letzte gute Snapshot geladen
  und das Journal darüber abgespielt. Der Spieler verliert im schlimmsten Fall Sekunden.
- **Migration:** `saveVersion` + Kette von Migrationsschritten, jeder mit eigenem Test.

**Warum nicht SwiftData als Quelle der Wahrheit?** Der Spielzustand ist ein zusammen­
hängender Wertebaum, der als Ganzes deterministisch fortgeschrieben wird — kein
Objektgraph mit unabhängigen Lebenszyklen. Eine ORM-Schicht brächte hier
Impedanz (Referenzsemantik, implizites Lazy-Loading, schwer kontrollierbare
Migrationen, Nicht-Testbarkeit außerhalb von Apple-Plattformen) ohne Gegenwert.
SwiftData bleibt eine sinnvolle Option für *abgeleitete*, abfrageintensive Daten
(z. B. Album-Suche über hunderte Einträge) und kann dort später ergänzt werden —
als Index, nicht als Wahrheit.

---

## 10. Sync-Vorbereitung (Backend offen bis Phase 9)

```swift
// Konzept, nicht final
protocol SyncBackend {
    func push(events: [PersistedEvent]) async throws
    func pull(since: SyncCursor) async throws -> [PersistedEvent]
    func uploadSnapshot(_ data: Data) async throws
    func latestSnapshot() async throws -> Data?
}
```

Jetzt implementiert: `LocalOnlySyncBackend` (No-Op). Später austauschbar gegen
`CloudKitSyncBackend` oder `FirestoreSyncBackend` — **ohne** Änderung an Spiellogik.

**Merge-Strategie (bereits jetzt festgelegt, weil sie das Event-Design bestimmt):**
- Jedes Event trägt `eventID` (UUID), `deviceID`, `lamportCounter`, `wallClock`.
- Zusammenführung = Sortierung nach (`lamportCounter`, `deviceID`) und Replay.
- Events müssen **idempotent** sein (zweimaliges Anwenden ändert nichts) — das ist eine
  verbindliche Design-Regel für jeden neuen Event-Typ.
- Nicht zusammenführbare Fälle (dieselbe Kreatur auf zwei Geräten weiterentwickelt)
  werden **additiv** aufgelöst: im Zweifel behält der Spieler beides. Nie löschen.

---

## 11. Freischaltungen & Feature-Flags

Zwei getrennte Konzepte, die oft verwechselt werden:

| | Zweck | Quelle |
|---|---|---|
| **Unlocks** | Story-Fortschritt schaltet Systeme frei (Kap. 2 → Ausflüge) | Spielzustand, Content-definiert |
| **Feature-Flags** | Entwicklung: unfertige Systeme abschalten | Build-Konfiguration |

Beide laufen über eine gemeinsame Abfrage `isAvailable(.expeditions)`, damit die UI nur
eine Prüfung kennt. Der Story-Skip setzt schlicht alle Unlocks.

---

## 12. Darstellung der Kreaturen

Aussehen ist Daten, nicht Zeichnung:

```
AppearanceDescriptor
 ├ silhouette: SilhouetteID        (Körperform der Art)
 ├ layers: [PartID]                (Ohren, Augen, Mund, Muster, Schweif …)
 ├ palette: PaletteID              (Variante: Standard / Schimmer / Saison)
 ├ scale, proportions              (Wachstumsstufe)
 └ cosmetics: [Slot: CosmeticID]   (Kleidung)
```

`CreatureRenderer` interpretiert das über ein `AppearanceProvider`-Protokoll.
MVP-Implementierung: **programmatische Vektorformen** (SwiftUI `Canvas`/`Shape`) —
sofort spielbar, animierbar, sauber skalierend, mit Farbpaletten-Varianten praktisch
gratis. Spätere Implementierung: `AssetAppearanceProvider`, der dieselben Deskriptoren
auf gezeichnete Vektor-Assets abbildet. **Der Austausch betrifft ein Modul.**

Animationen: Zustandsgetrieben (`idle`, `happy`, `sleepy`, `eating`, `sick`) mit
Persönlichkeitsvariation über Timing-Parameter — keine Animation ist hartcodiert an
eine Art gebunden.

---

## 13. Teststrategie

| Ebene | Inhalt | Wo lauffähig |
|---|---|---|
| **Invarianten-Tests** | Design-Säulen als Code: Freundschaft sinkt nie · kein Wert unter dem Boden · kein Command führt zu Item-/Kreaturenverlust · jede Art hat einen kampffreien Evolutionspfad | Linux + macOS |
| **Simulations-Tests** | „30 Tage offline" → erwarteter Zustand; Zeitsegmentierung über Saisonwechsel | Linux + macOS |
| **Command/Event-Tests** | Zustand + Command → exakte Event-Liste | Linux + macOS |
| **Content-Validierung** | Referenzintegrität, Balancing-Grenzen, Vollständigkeit | Linux + macOS |
| **Migrations-Tests** | Alt-Save → Neu-Save je Version | Linux + macOS |
| **Snapshot-/UI-Tests** | Screens, Renderer | nur macOS |

Die ersten fünf Ebenen decken die eigentliche Spiellogik ab und laufen **ohne Apple-
Plattform** — genau deshalb ist die UI-Freiheit der Systeme keine Stilfrage.

**CI (ab Phase 3):** GitHub Actions
- Job `core`: Ubuntu, `swift build && swift test` für alle plattformunabhängigen Module
- Job `app`: macOS, `xcodebuild` für App + UI-Tests
- Job `content`: Content-Validator

---

## 14. Architekturentscheidungen (ADR)

### ADR-001 — Command/Event-Architektur statt direkter Mutation
**Kontext:** Zwölf Systeme sollen sich gegenseitig nicht kennen, später aber
serverautoritativ und geräteübergreifend synchronisiert werden.
**Entscheidung:** Alle Zustandsänderungen laufen über serialisierbare Events.
**Konsequenzen:** + Entkopplung, Sync, Replay, Tests, Analytics.
− Mehr Zeremonie, Event-Versionierung nötig.
**Alternativen:** Direkte Mutation (schneller, aber Multiplayer später nicht nachrüstbar);
vollständiges Event-Sourcing ohne Snapshot (zu langsam beim Laden).

### ADR-002 — Snapshot + Journal statt SwiftData als Quelle der Wahrheit
Siehe §9. **Konsequenz:** volle Kontrolle über Migration und Determinismus; wir
verzichten auf SwiftData-Komfort und auf automatische CloudKit-Spiegelung.

### ADR-003 — Simuliertes Wetter
**Entscheidung:** eigenes Wettermodell mit Zyklen, saisonalen Wahrscheinlichkeiten und
seedbasiertem Verlauf. **Konsequenz:** keine Standortberechtigung, deterministische
Tests, planbare Events; verzichtet auf den Realwetter-Bezug. Ein späterer
`RealWeatherSource`-Adapter bleibt möglich, weil `ClimateSystem` seine Eingabe über ein
Protokoll bezieht.

### ADR-004 — Content als validiertes JSON-Bundle
**Konsequenz:** Inhalte ohne Codeänderung, CI-geprüfte Integrität; JSON ist beim
Autorenkomfort schwächer als YAML — akzeptiert zugunsten von Null Abhängigkeiten.

### ADR-005 — Aussehen als Deskriptor, Rendering austauschbar
**Konsequenz:** MVP ohne externe Assets spielbar; späterer Asset-Wechsel betrifft ein
Modul. Kosten: programmatische Kreaturen sehen zunächst schlichter aus als Illustrationen.

### ADR-006 — Seedbasierter Zufall mit benannten Strömen
**Konsequenz:** reproduzierbare Tests, kein Save-Scumming; erfordert Disziplin —
nirgends `Int.random(in:)`, ein Lint-Check erzwingt das.

### ADR-008 — CloudKit als Sync-Backend
**Kontext:** In Phase 1 bewusst offen gelassen, in Phase 9 zu entscheiden.
**Entscheidung:** CloudKit.
**Ausschlaggebend:** Datenschutz bei Altersfreigabe 4+. Ein Spiel für Kinder, das
Spielstände auf eigenen Servern hält, braucht Erklärung, Löschkonzept und jemanden, der
dafür geradesteht. CloudKit legt die Daten ins iCloud-Konto des Nutzers — er besitzt sie.
**Konsequenzen:** + kein Serverbetrieb, keine laufenden Kosten, Backup inklusive.
− Bindung an Apple-Plattformen; für späteren Multiplayer mit Server-Autorität wird ein
eigener Dienst dazukommen müssen. Das ist absehbar und kein Widerspruch: Geräte-Abgleich
und Spielserver sind zwei Aufgaben.
**Alternative:** Firebase — stärker für Multiplayer, teurer im Datenschutz-Aufwand.

### ADR-007 — Modulgrenzen als SwiftPM-Targets
**Konsequenz:** Verstöße sind Compilerfehler statt Code-Review-Anmerkungen.
Kosten: mehr Targets, etwas längere Inkrementell-Builds.

---

## 15. Vorbereitung auf spätere Features

| Zukünftiges Feature | Was heute dafür getan wird |
|---|---|
| Multiplayer (Tausch, Kampf, Besuche) | Events serialisierbar, idempotent, Geräte-IDs, `SyncCore` |
| Server-Autorität / Anti-Cheat | Commands sind validierbar, Zustandsübergänge deterministisch |
| Neue Regionen/Kontinente | `RegionID` von Anfang an in Spawn-, Dungeon- und Album-Daten |
| Gilden / Koop-Dungeons | Expeditions-Zustand ist ein Wertetyp, mehrfach instanziierbar |
| Housing & Deko | `PlacementGrid` als eigenes System vorgesehen, GameState-Slot reserviert |
| Berufe / Haustiere für Kreaturen | Kreaturen-Zustand ist um `Traits`/`Companions` erweiterbar (offene Map) |
| Content-Updates ohne App-Release | Content-Loader unterstützt mehrere Quellen |
| iPad | adaptive Layouts, keine festen Breiten |

---

## 16. Offene Punkte für Phase 3

1. **Repository-Layout:** ein Swift Package mit vielen Targets + dünnes Xcode-Projekt
   (Empfehlung) vs. mehrere Packages.
2. **Xcode-Projektdatei:** wird von mir als Konfiguration erzeugt; ohne macOS hier
   nicht überprüfbar → erste CI-Läufe werden voraussichtlich Nacharbeit brauchen.
3. **Namensraum-Präfixe:** aktuell keine (Modulnamen genügen); `WeatherKit`-Kollision
   wird durch `ClimateSystem` vermieden.
4. **Swift-Testing vs. XCTest:** Empfehlung `swift-testing` (Swift 6, klarere Syntax).

---

*Ende Phase 2 — Entwurf v0.1*
