# Save System — Projekt „NUBI"

> **Status:** Phase 8 — v0.1
> **Grundlage:** [Architektur, ADR-002](02-technische-architektur.md) · [Datenmodelle](04-datenmodelle.md)

Ab dieser Phase überlebt eine Partie den App-Neustart. Damit fallen auch die beiden
Provisorien aus Phase 6.

---

## 1. Drei Zusagen

### Atomar
Geschrieben wird in eine temporäre Datei, die danach an ihren Platz gehoben wird. Ein
Absturz mitten im Schreiben hinterlässt **entweder den alten oder den neuen** Stand — nie
einen halben.

> **Nachtrag aus der CI.** Zuerst stand hier ein handgeschriebener Weg über
> `replaceItemAt`, mit der Begründung, die Zusage sei zu wichtig für ein Flag. Der erste
> Testlauf hat das widerlegt: `replaceItemAt` verhält sich unter Linux anders und schlug
> beim **zweiten** Speichern fehl. `Data.write(options: .atomic)` tut dasselbe —
> temporäre Datei, dann umbenennen — nur plattformrichtig. Zwei Tests, die genau diesen
> Fall abdecken, hatten die Begründung geprüft und für falsch befunden.

### Selbstheilend
Vor jedem Überschreiben wandert der bisherige Stand in die Sicherungen (fünf Stück,
rollierend). Ist der aktuelle Stand unlesbar, wird die jüngste brauchbare Sicherung
genommen. Der Spieler verliert Minuten, nicht Monate.

### Migrierend
Ältere Formate werden beim Laden hochgezogen, statt abgelehnt zu werden.

---

## 2. Migriert wird das JSON, nicht der Typ

Ein Spielstand aus Version 1 lässt sich gar nicht erst in den heutigen `GameState`
dekodieren — ihm fehlen Felder, die inzwischen Pflicht sind (`album`, `eggs`,
`shimmerPityCounter`). Deshalb läuft die Migration auf den **Rohdaten**:

```
Datei → JSON-Objekt → Migrationsschritte → Dekodieren → GameState
```

Jeder Schritt bringt genau eine Version weiter. Die Kette ist dadurch einzeln testbar,
und ein Spielstand von Version 1 läuft dieselben Schritte durch wie einer von Version 3 —
nur mehr davon.

**Migration erfindet keine Historie.** Wer vor Phase 7 gespielt hat, hat nichts entdeckt;
sein Album bleibt leer. Es nachträglich zu füllen wäre freundlich gemeint und trotzdem
gelogen. Ein Test hält das fest.

Ein Spielstand aus einer **neueren** App-Version wird abgelehnt statt verstümmelt — mit
einer Meldung, die erklärt, was los ist.

---

## 3. Prüfsumme — und was sie nicht ist

Neben dem Zustand steht eine FNV-Prüfsumme über den kanonisch serialisierten Inhalt
(sortierte Schlüssel, sonst wäre sie wertlos: Wörterbücher haben keine feste Reihenfolge).

Sie ist **ausdrücklich kein Manipulationsschutz**. Wer die Datei absichtlich ändert, kann
die Summe neu berechnen. Ihr Zweck ist bescheidener und ehrlicher: einen halb
geschriebenen oder auf dem Datenträger beschädigten Spielstand erkennen, bevor er als
gültig durchgeht — und dann die Sicherung ziehen.

Gegen Zeitmanipulation schützt weiterhin der `TimeCursor`: Zeit läuft nie rückwärts,
Sprünge sind gedeckelt. Auch der bestraft niemanden, er ignoriert nur.

---

## 4. Der Spielstand ist lesbar

Die Datei enthält formatiertes JSON, keinen undurchsichtigen Blob:

```json
{
  "checksum" : "b3f2…",
  "savedAt" : "2026-08-07T06:55:00Z",
  "saveVersion" : 2,
  "state" : { "album" : { … }, "creatures" : [ … ], "player" : { … } }
}
```

Wer einen kaputten Spielstand untersuchen muss, soll ihn öffnen können — auch in zwei
Jahren, auch ohne dieses Projekt zur Hand. Ein Test prüft, dass der Kreaturenname
tatsächlich im Klartext in der Datei steht.

---

## 5. Was in der App dazugekommen ist

| Vorher (Phase 6) | Jetzt |
|---|---|
| Inhalt aus `ContentBundle.sample` | Inhalt aus dem App-Bundle, Fixture nur noch als Rückfall |
| Jeder Start beginnt eine neue Partie | Vorhandener Spielstand wird fortgesetzt |
| Geräte-Kennung fest verdrahtet | Stabile Kennung, die dem Gerät bleibt |

Zwei Entscheidungen dahinter:

**Der Rückfall auf das Fixture bleibt.** Eine App, die beim Fehlen einer Ressource gar
nicht startet, ist im Zweifel schlechter als eine, die mit weniger Inhalt startet.

**Eine neue Partie beginnt nur, wenn wirklich kein Spielstand existiert.** Ein
versehentlich überschriebener Spielstand wäre der eine Verlust, den dieses Spiel nicht
kennen darf.

Gespeichert wird über einen Rückruf, den `AppComposition` setzt — `FeatureHome` soll nicht
wissen, dass es so etwas wie Dateien gibt.

---

## 6. Tests dieser Phase

| Suite | Prüft |
|---|---|
| `SaveStoreTests` | Rundlauf, Lesbarkeit der Datei, stabile Prüfsumme, erkannte Beschädigung, Rückfall auf die Sicherung, begrenzte Anzahl Sicherungen, keine temporären Reste |
| `SaveMigrationTests` | fehlende Felder werden ergänzt, migrierter Stand dekodiert, keine erfundene Historie, aktuelle Version unangetastet, zu neue Version abgelehnt |

Der Test „Ist der aktuelle Stand unlesbar, greift die Sicherung" ist der wichtigste: Er
schreibt bewusst Müll in die Spielstanddatei und erwartet, dass die Partie trotzdem
weitergeht.

---

## 7. Offene Punkte für Phase 9

- **Event-Journal**: Die Ereignisse werden noch nicht mitgeschrieben. Der Umschlag dafür
  (`EventEnvelope` mit Lamport-Zähler und Geräte-Kennung) steht seit Phase 4 bereit.
- **Speichern beim Wechsel in den Hintergrund**: Bisher wird nach jeder Änderung
  geschrieben. Das ist sicher, aber häufiger als nötig.
- **Sicherungen mit Datumsstaffel** (täglich/wöchentlich) statt nur der letzten fünf.

---

*Ende Phase 8 — v0.1*
