# Grundlegendes Gameplay — Projekt „NUBI"

> **Status:** Phase 6 — v0.1
> **Grundlage:** [Datenmodelle](04-datenmodelle.md) · [UI-Konzept](05-ui-konzept.md)

Ab dieser Phase ist es ein Spiel: Die Zeit läuft, die Kreatur reagiert, und man
kann sie füttern, streicheln und schlafen legen.

---

## 1. Die Verfallskurve — das Herzstück

Die schwierigste Anforderung des Auftrags war ein Zielkonflikt: *Echtzeit, aber niemals
Bestrafung.* Echtzeitdruck ist bei Tamagotchi genau der Motor — und genau der Grund,
warum die meisten Exemplare in einer Schublade endeten.

Die Auflösung ist eine einzige Formel. Ein Bedürfnis verfällt nicht linear, sondern mit
einer Rate, die sich alle acht Stunden halbiert:

```
Rate zur Stunde u:   r · 2^(−u/H)

Verfall von t₀ bis t₁:   (r·H / ln2) · (2^(−t₀/H) − 2^(−t₁/H))
```

Drei Eigenschaften machen sie wertvoll:

| Eigenschaft | Was sie bedeutet |
|---|---|
| **Beschränkt** | Über beliebig lange Abwesenheit fällt nie mehr als `r·H/ln2` an. Bei 4 Punkten je Stunde und 8 Stunden Halbwertszeit sind das rund **46 Punkte — egal ob drei Tage oder drei Monate**. |
| **Additiv** | Der Verfall über [0,5] plus der über [5,10] ist exakt der über [0,10]. Die Engine darf die Zeit deshalb in Stundenabschnitte zerlegen, ohne Rundungsdrift. |
| **Zustandslos** | Es braucht keine gespeicherte Verfallshistorie, nur den Abstand zum Beginn der Abwesenheit. |

Der Komfort-Boden aus dem Balancing ist die **zweite** Sicherung — für den Fall, dass
ein Wert schon vorher niedrig stand. Ein Test hält beides fest: *zwei Wochen kosten
weniger als einen Punkt mehr als zwei Tage.*

---

## 2. Zeitauflösung

Es läuft kein Timer. Beim Öffnen der App rechnet die Engine einmalig nach:

```
resolveTime(now:)
  → ClimateSystem zerlegt [zuletzt aufgelöst … jetzt] in Stundenabschnitte
     mit Jahreszeit, Tageszeit und Wetter
  → CreatureSimulation schreibt die Kreatur durch jeden Abschnitt fort
  → Rückkehr-Bonus, wenn die Abwesenheit lang genug war
  → Zeitzeiger auf jetzt
```

Warum stündlich statt am Stück: „14 Tage weg" darf nicht als ein kontextloser Block
verrechnet werden — sonst schläft eine Kreatur zwei Wochen durch und Winterpflanzen
wachsen im Sommer weiter. 30 Tage sind 720 Schritte; das kostet nichts.

Die Obergrenze liegt bei 31 Tagen. Wer die Uhr vorstellt, gewinnt dadurch wenig; wer sie
zurückstellt, verliert nichts (`TimeCursor` läuft nie rückwärts).

---

## 3. Wetter und Jahreszeiten

Das Wetter wird **zustandslos** bestimmt: aus Startwert, Zeitfenster (6 Stunden) und
Jahreszeit. Es gibt keine gespeicherte Wetterhistorie — und trotzdem liefert jede
Abfrage für denselben Zeitpunkt dasselbe Ergebnis, auch rückwirkend. Genau das braucht
die Zeitauflösung, wenn sie zwei Wochen nachträglich durchrechnet.

Die Wahrscheinlichkeiten stehen in `Content/climate/climate.json`. *Es schneit nie im
Sommer* ist deshalb keine Regel im Code, sondern eine fehlende Zahl in einer Tabelle —
und ein Test.

Die Jahreszeit kommt aus dem Monat, mit Umschaltung für die Südhalbkugel.

---

## 4. Pflege als Command → Event → State

Jede Handlung läuft über das Muster aus Phase 2:

```
CareCommand.feed(id, "sun_berry")
   → CareSystem.handle(…)  prüft, ob es das Item gibt und ob die Art es mag
   → [CareEvent.fed(effects:tags:liked:)]
   → CareSystem.apply(…)   verändert den Zustand
```

**Ein Event trägt alles mit, was zum Anwenden nötig ist** — Wirkung *und* Tags, statt
sie beim Anwenden im Content nachzuschlagen. Der Grund ist nicht Bequemlichkeit: Wenn
ein Balancing-Update die Sonnenbeere später schwächer macht, darf das die vergangene
Woche nicht rückwirkend verändern. Daran hängt später der Cloud-Abgleich, der Events
erneut abspielt.

Zwei kleine Design-Entscheidungen mit Wirkung:

- **Streicheln ist nie „zu viel".** Es gibt keinen Zustand, in dem Zuwendung schadet
  oder abgelehnt wird.
- **Doppelt schlafen legen erzeugt kein Event.** Was keine neue Tatsache ist, kommt
  auch nicht ins Journal.

---

## 5. Erster spielbarer Build

`RootView` steckt Engine, Inhalt und Startbildschirm zusammen. Der Bildschirm folgt dem
UI-Konzept: Bühne mit der Kreatur, darunter Bedürfnisse und höchstens **ein**
freundlicher Vorschlag — nie eine Liste offener Aufgaben.

Tippen auf die Kreatur streichelt sie: keine Bestätigung, kein Dialog.

Nach längerer Abwesenheit öffnet sich die Rückkehr-Szene: *„Sie hat dich vermisst."*
Kein Statusbericht, keine Mängelliste.

### Zwei bewusste Provisorien

| Provisorium | Warum | Wann es fällt |
|---|---|---|
| Inhalt kommt aus `ContentBundle.sample` statt aus dem Content-Verzeichnis | Das Verzeichnis als App-Ressource auszuliefern gehört zur Persistenz-Phase; ohne Fixture wäre die App bis dahin nicht startbar — und ein nicht startbarer Build ist schwer zu beurteilen | Phase 8 |
| Jeder Start beginnt eine neue Partie | Es gibt noch keine Persistenz | Phase 8 |

---

## 6. Warum die Engine kein `@Observable` ist

`GameEngine` ist ein plattformunabhängiger Wertetyp ohne SwiftUI. Beobachtbar wird sie
erst in `HomeModel`, in der Darstellungsschicht.

Das ist keine Stilfrage: `Observation` gibt es nur auf Apple-Plattformen. Wäre die
Engine beobachtbar, ließe sie sich nicht mehr auf dem Linux-Runner testen — und damit
wäre der schnelle, aussagekräftige Teil der CI weg. Die Plattformgrenze **erzwingt** die
saubere Trennung, statt sie nur zu empfehlen.

---

## 7. Tests dieser Phase

| Suite | Prüft |
|---|---|
| `DecayCurveTests` | Additivität, Beschränktheit, Halbierung, „zwei Wochen ≈ zwei Tage" |
| `OfflineSimulationTests` | 30 Tage Abwesenheit, Boden, Wiedersehen, zurückgestellte Uhr, Determinismus |
| `CareTests` | Füttern, Lieblingsessen, Streicheln ohne Obergrenze, Schlaf-Umschaltung, Event-Kodierung |
| `ClimateTests` | Jahreszeit je Monat und Hemisphäre, stabiles Wetter, kein Schnee im Sommer, lückenlose Abschnitte |

`OfflineSimulationTests` ist die wichtigste Suite des Projekts. Sie enthält bewusst auch
einen Test, der prüft, dass die Sättigung überhaupt **sinkt** — sonst wäre „nichts fällt
unter den Boden" auch dann erfüllt, wenn die Simulation gar nichts täte.

---

## 8. Offene Punkte für Phase 7

- **Zustände entstehen** noch nicht von selbst (Schnupfen bei nassem Wetter). Bisher
  laufen sie nur ab.
- **Erfahrung und Level** verändern sich noch nicht.
- **Evolution** ist als Daten und Bedingungssystem da, wird aber noch nicht ausgelöst.
- **Inventar**: Füttern verbraucht noch kein Item.
- **Tagesrhythmus**: Die Kreatur schläft nach Art-Zeitfenster, unabhängig davon, ob der
  Spieler sie schlafen gelegt hat.

---

*Ende Phase 6 — v0.1*
