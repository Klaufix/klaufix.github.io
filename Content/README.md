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

Das vollständige Schema entsteht in **Phase 4** gemeinsam mit den Datenmodellen.
Bis dahin prüft der Validator nur die Verzeichnisstruktur.
