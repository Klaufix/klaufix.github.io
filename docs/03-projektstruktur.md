# Projektstruktur — Projekt „NUBI"

> **Status:** Phase 3 — v0.1
> **Grundlage:** [Technische Architektur](02-technische-architektur.md)

Diese Phase liefert das Gerüst: den vollständigen Modulgraphen, die Content-Pipeline,
das App-Ziel und die CI. Ab hier ist jede Modulgrenze aus Phase 2 **compilergeprüft** —
ein Verstoß gegen die Architektur ist kein Review-Kommentar mehr, sondern ein Buildfehler.

---

## 1. Verzeichnisbaum

```
/
├── App/                          dünnes iOS-App-Ziel
│   ├── project.yml               XcodeGen-Spezifikation (Projekt wird generiert)
│   └── Sources/GameApp.swift     @main — startet nur die Szene
│
├── Modules/
│   ├── GameLogic/                Swift Package · plattformunabhängig, UI-frei
│   │   ├── Package.swift
│   │   ├── Sources/              19 Targets (Kern, 12 Systeme, Engine, Infra, Werkzeug)
│   │   └── Tests/
│   │
│   └── Presentation/             Swift Package · SwiftUI, Apple-Plattformen
│       ├── Package.swift
│       └── Sources/              12 Targets (DesignSystem, Renderer, 9 Features, Composition)
│
├── Content/                      Spielinhalte als JSON (siehe Content/README.md)
├── docs/                         Phasendokumente
└── .github/workflows/ci.yml      Linux-Logiktests · macOS-Build · App-Build
```

---

## 2. Warum zwei Pakete statt eines

In Phase 2 stand als offener Punkt „ein Paket mit vielen Targets vs. mehrere Pakete".
Entschieden: **zwei Pakete**, getrennt entlang der Plattformgrenze.

SwiftUI existiert unter Linux nicht. Läge alles in einem Paket, würde `swift build` auf
einem Linux-Runner an den UI-Targets scheitern — und damit ginge genau der Vorteil
verloren, für den die Systeme UI-frei geschnitten wurden. Die Trennung macht die Regel
physisch:

| Paket | Baut auf | Enthält |
|---|---|---|
| `GameLogic` | Linux **und** macOS/iOS | die gesamte Spiellogik |
| `Presentation` | nur Apple-Plattformen | alles, was etwas anzeigt |

Ein Nebeneffekt, der wichtiger ist als er klingt: Wer versucht, Spiellogik in ein
Feature-Modul zu schreiben, merkt es spätestens, wenn die Logiktests sie nicht erreichen.

---

## 3. Modulgraph

```
                       ┌───────────────────────────────┐
   Presentation        │  App (GameApp)                │
                       └───────────────┬───────────────┘
                                       ▼
                       ┌───────────────────────────────┐
                       │  AppComposition               │  ← einzige Verdrahtungsstelle
                       └───────────────┬───────────────┘
                        ┌──────────────┴──────────────┐
                        ▼                             ▼
              ┌───────────────────┐         ┌───────────────────┐
              │ Feature× 9        │────────►│ CreatureRenderer  │
              │ Home, Album, …    │         │ DesignSystem      │
              └─────────┬─────────┘         └───────────────────┘
════════════════════════╪══════════════════════════════════════════ Plattformgrenze
                        ▼
   GameLogic  ┌───────────────────┐
              │    GameEngine     │──────────────┐
              └─────────┬─────────┘              │
                        ▼                        ▼
              ┌───────────────────┐    ┌──────────────────────┐
              │     GameState     │    │ Persistence, SyncCore│
              └─────────┬─────────┘    └──────────────────────┘
                        ▼
      ┌──────────────────────────────────────────────┐
      │  12 Systeme — gegenseitig blind              │
      │  Creature · Inventory · Wardrobe · Climate   │
      │  Expedition · Battle · Breeding · Quest      │
      │  Story · Album · Progression · Economy       │
      └────────────────────┬─────────────────────────┘
                           ▼
              ┌────────────────────────────┐
              │ GameRules → GameContent →  │
              │              GameCore      │
              └────────────────────────────┘
```

**Die Regel im Paketmanifest:** Systeme bekommen als Abhängigkeit ausschließlich
`["GameCore", "GameContent", "GameRules"]`. `import BattleSystem` in `QuestSystem` ist
damit schlicht nicht übersetzbar. Wirkung zwischen Systemen entsteht nur über Events.

Jedes Modul enthält heute eine `Module.swift` mit seinem Vertrag: Verantwortung,
erlaubte Importe, Zielphase. Das ist Absicht — die Grenze soll dort dokumentiert sein,
wo sie gilt.

---

## 4. Kein eingechecktes Xcode-Projekt

`App.xcodeproj` wird aus `App/project.yml` erzeugt und ist in `.gitignore`:

```sh
brew install xcodegen
cd App && xcodegen generate && open App.xcodeproj
```

Eine `.pbxproj` ist die einzige Datei, die in einem solchen Projekt nicht lesbar wäre,
sich nicht sinnvoll zusammenführen ließe und bei der niemand einen Review machen kann.
Eine 30-zeilige YAML-Datei leistet dasselbe.

---

## 5. CI

| Job | Läuft auf | Prüft |
|---|---|---|
| `logic` | Linux, Container `swift:6.1` | `swift build`, `swift test`, Content-Validator |
| `presentation` | macOS 15 | `swift build` der SwiftUI-Module |
| `app` | macOS 15 | XcodeGen + `xcodebuild` für iOS |

Der schnelle, aussagekräftige Teil läuft auf Linux und braucht weder Xcode noch
Signierung. Die teuren macOS-Jobs prüfen nur, was tatsächlich Apple-Plattformen braucht.

> **Hinweis zur Verifikation:** In der Entwicklungsumgebung dieser Arbeit ist keine
> Swift-Toolchain verfügbar (`download.swift.org` ist per Egress-Policy gesperrt).
> Der Code dieser Phase ist deshalb **noch nicht kompiliert worden**; der erste CI-Lauf
> ist die erste echte Prüfung, und Nacharbeit an Manifesten oder Workflow ist zu erwarten.

---

## 6. Was in dieser Phase schon echter Code ist

Fast alles ist bewusst leer — mit einer Ausnahme, die die Pipeline von Ende zu Ende
belegt: `GameCore.Identifier`.

Content referenziert sich über Zeichenketten. Ohne Typisierung landet eine Art-ID
irgendwann dort, wo eine Item-ID erwartet wird, und das fällt erst im laufenden Spiel
auf. `Identifier<Tag>` hängt jedem Bezeichner über einen Phantom-Typ eine Bedeutung an —
zur Laufzeit kostenlos, beim Kompilieren verbindlich:

```swift
let art: SpeciesID = "sprout"
let item: ItemID = art        // Compilerfehler — genau so soll es sein
```

Kodiert wird nur die Zeichenkette selbst, damit Content-Dateien lesbar und diffbar
bleiben. Vier Tests decken Kodierung, Rundlauf, Gleichheit und Verwendung als
Schlüssel ab.

---

## 7. Nächste Phase

**Phase 4 — Datenmodelle:** `Species` / `Individual` / `State`, das Content-Schema mit
`schemaVersion`, der `ConditionExpression`-Evaluator in `GameRules`, die Event- und
Command-Protokolle in `GameCore` sowie der vollständige Content-Validator.

---

*Ende Phase 3 — v0.1*
