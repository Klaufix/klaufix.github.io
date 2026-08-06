# Datenmodelle — Projekt „NUBI"

> **Status:** Phase 4 — v0.1
> **Grundlage:** [Technische Architektur](02-technische-architektur.md) · [Projektstruktur](03-projektstruktur.md)

Diese Phase liefert die Typen, auf denen alles Weitere steht: die drei Ebenen des
Kreaturen-Modells, das Content-Schema, den Bedingungs-Evaluator und den Spielstand.

---

## 1. Die drei Ebenen einer Kreatur

Die Trennung aus dem GDD ist jetzt Code. Sie ist der Grund, warum eine Entwicklung
den Spieler nicht seine Kreatur kostet:

| Ebene | Typ | Lebensdauer | Beispiel |
|---|---|---|---|
| **Art** | `SpeciesDefinition` (Content) | unveränderlich, für alle Exemplare gleich | Basiswerte, Element, Vorlieben |
| **Individuum** | `CreatureIndividual` | bei Entstehung festgelegt | Persönlichkeit, Anlagen, Variante, Name, Abstammung |
| **Zustand** | `CreatureState` | ändert sich ständig | Bedürfnisse, Freundschaft, Level, Kleidung, Zustände |

Bei einer Evolution wechselt lediglich `individual.speciesID`. Persönlichkeit, Name,
Geburtsdatum, Freundschaft und Stammbaum bleiben. Der Spieler behält *seine* Kreatur —
sie sieht nur anders aus. Ein Test hält das fest.

---

## 2. Design-Regeln, die in den Typen stecken

Der interessanteste Teil dieser Phase: Drei Zusagen aus dem GDD sind keine Konvention
mehr, sondern Eigenschaften von Typen.

### `Friendship` kann nicht sinken
Der Typ hat **keine** Methode, die den Wert senkt. `increase(by:)` verwirft negative
Beträge. Die Regel „Freundschaft sinkt nie" muss dadurch von keinem der zwölf Systeme
erinnert werden — ein Rückschritt lässt sich nicht einmal versehentlich hinschreiben.

### `NeedValue` verlässt seinen Bereich nie
Auch nicht beim Dekodieren: Ein beschädigter Spielstand ergibt einen unschönen, aber
gültigen Zustand statt einer Kreatur mit −40 Sättigung. `decay(by:notBelow:)` hält am
Komfort-Boden auf — **und hebt nicht an**, wer bereits darunter liegt.

### `ActiveCondition` hat immer ein Ablaufdatum
Es gibt keinen Zustand ohne `expiresAt`. Ein Dauerleiden wäre eine Strafe, und Strafen
gibt es nicht — nur Aufgaben, die vorbeigehen.

### `TimeCursor` kann nicht rückwärts
Zurückgestellte Uhr → null Fortschritt, nie negativer. Vorwärtssprünge auf 30 Tage
gedeckelt. Die tatsächliche Abwesenheit bleibt über `absence(until:)` ablesbar, weil die
Rückkehr-Szene sie braucht: je länger weg, desto herzlicher der Empfang.

---

## 3. Der Bedingungsausdruck

Ein einziger Datentyp beschreibt Evolutionsvoraussetzungen, Questziele,
Event-Verfügbarkeit, Shop-Sichtbarkeit und Dialogverzweigungen.

```
ConditionExpression
 ├ .always
 ├ .all([…])          alle erfüllt
 ├ .any([…])          mindestens eine
 ├ .not(…)
 └ .check(Fact, Comparator, FactValue)

Fact = FactKey + optionaler Parameter
       .personality mit Parameter "courage" ⇒ „wie mutig ist sie?"
```

**Der einzige Code, den ein neuer Inhaltstyp je braucht,** ist ein weiterer Fall in
`FactKey` — und danach steht die neue Bedingung *allen* Systemen gleichzeitig zur
Verfügung.

Die Auswertung liegt in `GameRules`, die Form in `GameCore`. Diese Aufteilung ist eine
**Korrektur gegenüber Phase 2**: Dort war der komplette Evaluator in `GameRules`
vorgesehen. Da aber `GameContent` die Bedingungen in Evolutionen speichert und
`GameRules` von `GameContent` abhängt, wäre daraus ein Abhängigkeitszyklus geworden.
Datentyp nach unten, Verhalten bleibt oben — die Schichtung bleibt dieselbe.

### Zwei Auswertungsregeln, die bewusst so sind

**Eine unbekannte Tatsache gilt nie als erfüllt** — auch nicht bei `!=`. Ein Tippfehler
im Content darf keine Evolution verschenken.

**`unmetChecks` statt nur `true/false`:** Der Evaluator kann melden, *welche*
Einzelbedingungen offen sind. Daraus macht das Album „dazu fehlt noch Nebel" statt
„gesperrt" — eine Einladung statt einer Wand.

### JSON-Form

```json
{ "all": [
    { "fact": "level", "op": ">=", "value": 16 },
    { "fact": "friendship", "op": ">=", "value": 60 },
    { "any": [
        { "fact": "season", "op": "==", "value": "spring" },
        { "fact": "weather", "op": "==", "value": "rain" }
    ] }
] }
```

---

## 4. Was Content ist und was Code

| Als Content (Daten) | Als Code (Aufzählung) | Warum |
|---|---|---|
| Elemente (`ElementID`) | Wachstumsstufen | Reihenfolge hat Bedeutung, jedes System kennt sie |
| Wetterarten (`WeatherID`) | Jahreszeiten | fester Kalender |
| Elementtabelle | Seltenheitsstufen | geordnet, wenige, strukturell |
| Arten, Items, Kleidung, Entwicklungen | Bedürfnisarten | fest verdrahtet in der Simulation |
| **Sämtliches Balancing** | Varianten-Kategorien | – |

Ein achtes Element ist damit eine Zeile in `elements.json`, kein Eingriff in zwölf
Systeme.

---

## 5. Balancing als Datei

`Content/balancing/balancing.json` ist die einzige Stelle mit Spielgefühl-Zahlen. Alle
Felder sind **verpflichtend** — stillschweigende Standardwerte im Code wären bei
Balancing-Fragen die schlechteste aller Antworten.

Der wichtigste Wert darin ist `offlineFloor: 25`. Er macht „keine Bestrafung" konkret,
und der Validator lehnt eine 0 mit Begründung ab.

> **Schema-Fußnote:** Swift setzt bei synthetisiertem `Codable` *keine* Default-Werte
> ein, wenn ein JSON-Schlüssel fehlt — es wirft. Weglassbare Felder sind deshalb als
> `Optional` deklariert und haben daneben einen Zugriff mit Standardwert
> (`tags` → `allTags`). Ohne das müsste jede Art-Datei jedes Feld auflisten.

---

## 6. Der Content-Validator

Er prüft drei Klassen von Fehlern:

1. **Referenzintegrität** — jede ID zeigt auf etwas, das es gibt
2. **Schema und Wertebereiche** — Versionen, Stapelgrößen, Schlafzeiten
3. **Design-Zusagen** — der interessante Teil

Beispiel für (3): *Jeder Entwicklungsweg braucht mindestens eine Verzweigung ohne
Kämpfe.* Das ist ein Versprechen an Cozy-Spieler. Ein Versprechen, das niemand
nachprüft, ist in zwei Jahren gebrochen — hier prüft es die CI.

```sh
cd Modules/GameLogic && swift run ContentValidator ../../Content
```

---

## 7. Spielstand

`GameState` ist ein zusammenhängender Wertebaum, kein Objektgraph — genau deshalb ist
die Persistenz ein Snapshot und keine Datenbank (ADR-002).

`PlayerState` enthält bereits `lamport` und `deviceID`, obwohl es noch keinen Sync gibt.
Das ist Absicht: Nachträglich eingeführt hätten alte Journale diese Felder nicht — und
genau die sollen beim ersten Sync zusammengeführt werden.

---

## 8. Tests dieser Phase

| Suite | Prüft |
|---|---|
| `InvariantTests` | die vier Typ-Invarianten aus §2 |
| `RandomSourceTests` | Reproduzierbarkeit, Unabhängigkeit der Ströme, Überleben der Kodierung |
| `ConditionEvaluatorTests` | Vergleiche, Verknüpfung, unbekannte Tatsachen, Hinweise |
| `ConditionCodingTests` | die JSON-Form aus dem Autorenhandbuch |
| `ContentTests` | den **echten ausgelieferten Content**, nicht erfundene Testdaten |
| `CreatureModelTests` | Identität über Evolution hinweg, Ablauf von Zuständen |

`ContentTests` ist der wichtigste davon: Er hängt Schema, Loader, Validator und die
tatsächlichen JSON-Dateien an einen gemeinsamen Test. Wer eine Definition ändert, ohne
die Dateien nachzuziehen, erfährt es sofort.

---

## 9. Offene Punkte für Phase 5/6

- **Verfallskurve** ist als Parameter da, aber noch nicht implementiert (Phase 6).
- **`FactProvider` der Engine** fehlt noch — bisher gibt es nur das Protokoll.
- **Migrationskette** in `Persistence` beginnt erst mit `saveVersion 2`.
- **Anlagen-Vererbung** braucht das BreedingSystem (Phase 7).

---

*Ende Phase 4 — v0.1*
