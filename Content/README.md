# Content

Hier liegt der Inhalt des Spiels: Kreaturen, Evolutionen, Items, Kleidung, Quests,
Dungeons, Story und Balancing.

**Grundregel:** Neue Inhalte entstehen hier, nicht im Code. Wenn ein neuer Inhalt eine
Codeänderung erfordert, ist entweder das Schema oder der Regel-Evaluator unvollständig —
nicht der Inhalt außergewöhnlich.

## Verzeichnisse

| Verzeichnis | Inhalt |
|---|---|
| `species/` | Arten: Basiswerte, Element, Seltenheit, Vorlieben, Aussehen |
| `evolutions/` | Entwicklungspfade mit ihren Bedingungen |
| `items/` | Nahrung, Materialien, Medizin, Werkzeuge |
| `cosmetics/` | Kleidung und Accessoires mit ihren Tags |
| `quests/` | Tages-, Wochen-, Story-, Sammel- und Eventquests |
| `dungeons/` | Ausflüge: Knotengraphen, Ereignis- und Beutetabellen |
| `story/` | Kapitel, Dialoge, Freischaltungen |
| `climate/` | Wetterzyklen, saisonale Wahrscheinlichkeiten, Tageszeiten |
| `balancing/` | Kurven und Parameter: Verfallsraten, EP-Tabellen, Chancen |

## Konventionen

- **Format:** JSON, UTF-8, zwei Leerzeichen Einrückung.
- **Dateinamen:** `<id>.json` in Kleinbuchstaben mit Unterstrich, z. B. `sprout_youngling.json`.
- **IDs** sind global eindeutig, stabil und werden **nie wiederverwendet**. Eine ID ist
  ein Versprechen: Spielstände verweisen darauf.
- **Umbenennen statt löschen:** Wird ein Inhalt entfernt, bekommt er `"retired": true`
  statt gelöscht zu werden — sonst brechen bestehende Spielstände.
- **Keine Anzeigetexte** in Content-Dateien, nur Lokalisierungsschlüssel.
- Jede Datei trägt eine `schemaVersion`.

## Prüfung

Der Validator prüft Schema, Referenzintegrität und Balancing-Grenzen. Er läuft in der CI
bei jedem Push:

```sh
cd Modules/GameLogic
swift run ContentValidator ../../Content
```

Geprüft werden Referenzintegrität, Schema-Versionen, Wertebereiche und die Design-Zusagen
aus dem GDD — etwa dass jeder Entwicklungsweg eine Verzweigung ohne Kämpfe hat.

## Schema

Das Schema steht in `Modules/GameLogic/Sources/GameContent/Definitions.swift`.
Weglassbare Felder sind dort als `Optional` deklariert.

**Art** (`species/`): `id`, `schemaVersion`, `nameKey`, `descriptionKey`, `element`,
`rarity`, `growthStage`, `baseStats`, `appearance` sind Pflicht; `preferences`,
`habitats`, `retired` sind optional.

**Entwicklung** (`evolutions/`): `id`, `schemaVersion`, `from`, `branches`.
Jede Verzweigung: `to`, `requires`, `hintKey`, optional `peaceful`.

**Bedingungen** (`requires`) folgen dieser Form:

```json
{ "all": [
    { "fact": "level", "op": ">=", "value": 16 },
    { "fact": "personality", "parameter": "courage", "op": ">=", "value": 70 },
    { "any": [
        { "fact": "season", "op": "==", "value": "spring" },
        { "fact": "weather", "op": "==", "value": "rain" }
    ] }
] }
```

Verknüpfungen: `all`, `any`, `not`, `always`.
Vergleiche: `==`, `!=`, `>`, `>=`, `<`, `<=`, `contains`.
Verfügbare `fact`-Werte stehen in `FactKey` (`GameCore/Conditions.swift`).
