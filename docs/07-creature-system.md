# Creature System — Projekt „NUBI"

> **Status:** Phase 7 — v0.1
> **Grundlage:** [Datenmodelle](04-datenmodelle.md) · [Gameplay](06-grundlegendes-gameplay.md)

Diese Phase schließt den Kreis: Das Bedingungssystem aus Phase 4 löst jetzt tatsächlich
etwas aus, Kreaturen wachsen, entwickeln sich, bekommen Nachwuchs — und das Album beginnt
sich zu füllen.

---

## 1. Erfahrung ohne Tor

Die Stufenkurve ist bewusst flach, und Stufen schalten **nichts** frei. Eine Stufe ist
ein Zeichen gemeinsam verbrachter Zeit, kein Tor, hinter dem Inhalte warten.

Erfahrung kommt aus zwei Quellen:

| Quelle | Menge | Warum |
|---|---|---|
| Pflegehandlung | 3 | Der tägliche Check-in soll spürbar etwas bewirken |
| Stunde, in der es der Kreatur gut ging | 1 | Belohnt Pflege, ohne Vernachlässigung zu bestrafen |

Die zweite Zeile ist der interessante Teil. Zeit allein zählt nicht — nur Stunden, in
denen Sättigung, Stimmung und Gesundheit über dem Korridor lagen. Wer sich nicht kümmert,
**verliert nichts**, er gewinnt nur weniger. Das ist der Unterschied zwischen Anreiz und
Strafe, und er ist als Test festgehalten.

---

## 2. Entwicklung — das Bedingungssystem wird scharf

`EvolutionCheck` prüft die Wege einer Art gegen den `FactProvider` der Engine. Der erste
Weg, dessen Bedingungen erfüllt sind, gewinnt — die Reihenfolge im Content ist damit ein
Gestaltungsmittel: Ein seltener Sonderweg kann vor dem Standardweg stehen.

**Eine Entwicklung wechselt nur die Art-ID.** Name, Persönlichkeit, Anlagen, Freundschaft,
Geburtsdatum und Stammbaum bleiben beim Individuum. Der Spieler behält seine Kreatur —
sie sieht nur anders aus. Ein Test hält genau das fest.

Entwicklung passiert **von selbst** und wird gefeiert, statt bestätigt zu werden. Ein
Dialog „Möchtest du wirklich?" würde eine Entscheidung mit Reue daraus machen; eine
Entwicklung ist aber immer ein Gewinn.

### Hinweise statt Sperren

`EvolutionCheck.hints` liefert zu jedem Weg die **offenen** Einzelbedingungen. Daraus
macht das Album „dazu fehlt noch Nebel" statt „gesperrt" — eine Einladung statt einer
Wand. Der Mechanismus dafür (`unmetChecks`) stand seit Phase 4 bereit und bekommt hier
seinen ersten Abnehmer.

---

## 3. Zucht

```
BreedingParent × 2  ──►  PendingEgg  ──(Reifezeit)──►  neue Kreatur
```

| Erbgut | Regel |
|---|---|
| Art | von einem Elternteil |
| Persönlichkeit | Mittelwert der Eltern ± 10 je Achse |
| Anlagen | je Wert der bessere Elternwert — **eine** wird neu gewürfelt |
| Variante | Schimmerchance, mit Mitleidszähler |

Der Neuwurf bei den Anlagen ist kein Detail: Ohne ihn endete Zucht nach wenigen
Generationen bei lauter Fünfen und wäre danach vorbei.

Der **Mitleidszähler** steht beim Spieler, nicht bei der Kreatur — er soll den Frust
*des Spielers* begrenzen. Nach der im Balancing hinterlegten Zahl erfolgloser Bruten ist
die nächste garantiert besonders. Zufall darf enttäuschen, aber nicht zermürben.

**Die Kennung des Schlüpflings wird aus der Ei-Kennung abgeleitet**, nicht gewürfelt.
Dadurch erzeugt zweimaliges Anwenden desselben Schlüpf-Ereignisses dieselbe Kreatur statt
zweier — die Idempotenz, an der später der Cloud-Abgleich hängt.

---

## 4. Album

Das Album speichert **Entdeckungen, nie Verluste**. Es gibt bewusst keine Methode zum
Entfernen: Ein Eintrag verschwindet nie wieder, auch wenn die Kreatur längst
weiterentwickelt ist.

Zwei Details, die aus der Sync-Vorbereitung folgen:

- Beim Zusammenführen zweier Journale gewinnt **das frühere** Erstsichtungs-Datum,
  unabhängig von der Reihenfolge, in der die Ereignisse eintreffen.
- Meilensteine liegen früh und dicht: 1, 3, 5, 10, 20, 35, 50. Die erste Belohnung soll
  kommen, bevor jemand sich fragt, wofür er eigentlich sammelt.

Die Startkreatur steht vom ersten Moment an im Album. Ein leeres Album beim ersten Start
wäre eine verpasste Gelegenheit — der erste Eintrag ist das Versprechen, dass es mehr zu
finden gibt.

Unentdeckte Arten zeigen eine Silhouette mit Fundort statt eines grauen Felds.

---

## 5. Eine Architekturregel, die sich bewährt hat

Beim Schreiben der Zucht stand zuerst `import CreatureSystem` in `BreedingSystem` — und
ließ sich nicht übersetzen. Genau dafür ist der Paketgraph da.

Die Lösung war nicht, die Regel aufzuweichen, sondern zwei saubere Schnitte:

1. **`CreatureTalents` ist in den Kern gewandert.** Die Zucht vererbt die Anlagen, der
   Kampf wird sie lesen — ein Wertetyp, den mehrere Systeme brauchen, gehört nach unten.
2. **`BreedingParent` als schmale Eingabe.** Die Zucht braucht Abstammung, Wesen und
   Anlagen — nicht den ganzen Kreaturen-Datensatz. Die erzwungene Grenze hat die bessere
   Schnittstelle hervorgebracht.

Dasselbe in der Oberfläche: `FeatureAlbum` bekommt fertige Anzeigedaten und kennt weder
Engine noch Spielzustand. Die Übersetzung steht in `AppComposition` — der einzigen Stelle,
die beides kennen darf.

---

## 6. Tests dieser Phase

| Suite | Prüft |
|---|---|
| `GrowthTests` | Erfahrung aus Pflege, Stufenaufstieg, Höchststufe, „schlechte Stunden kosten nichts" |
| `EvolutionTests` | Auslösen, Identität über die Entwicklung hinweg, kein verfrühtes Auslösen, Hinweise, Album-Eintrag |
| `BreedingTests` | Alterprüfung, kein Selbstzüchten, Determinismus |
| `InheritanceTests` | Persönlichkeit nahe am Elternmittel, Anlagen-Vererbung mit Neuwurf |
| `PityTests` | Garantie nach Schwelle, Zähler, Reifezeit, abgeleitete Schlüpf-Kennung |
| `AlbumTests` | Entdeckung, Varianten, frühestes Datum gewinnt, nichts geht verloren |
| `EngineBreedingTests` | Ei legen, Reifen, Schlüpfen, Eltern, Idempotenz |

---

## 7. Offene Punkte

- **Zustände entstehen** weiterhin nicht von selbst (Schnupfen bei nassem Wetter).
- **Inventar**: Füttern verbraucht noch kein Item.
- **Kreuzungsarten** bei der Zucht sind vorgesehen, aber noch nicht als Datentabelle da.
- **String-Kataloge** fehlen; die Oberfläche zeigt bis dahin abgeleitete Namen.
- **Album-Hinweise** sind in der Ansicht vorbereitet, aber noch nicht befüllt — dafür
  braucht es die Lokalisierung der Hinweistexte.

---

*Ende Phase 7 — v0.1*
