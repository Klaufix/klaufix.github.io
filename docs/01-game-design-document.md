# Game Design Dokument — Projekt „NUBI"

> **Status:** Phase 1 (Design) — Entwurf v0.1
> **Arbeitstitel:** NUBI (Platzhalter). Der finale Name ist eine Marketing-Entscheidung.
> Im Code taucht der Titel **nirgends** auf: Domänenobjekte heißen `Creature`, `Species`,
> `Habitat` usw. Ein Rename kostet dadurch später nur Assets und Store-Metadaten.

---

## 1. Kurzfassung (Elevator Pitch)

> *Ein kleines Wesen zieht bei dir ein. Es wächst in Echtzeit, entwickelt einen eigenen
> Charakter, erinnert sich an eure gemeinsame Zeit — und wird nie sterben, weil du mal
> drei Tage keine Zeit hattest.*

**NUBI** ist ein Cozy-Virtual-Pet-RPG für iOS. Der Spieler zieht ein Wesen groß, entdeckt
über Monate hinweg rund 50 Arten mit verzweigten Entwicklungen, unternimmt kurze
Ausflüge in Dungeons, züchtet Nachwuchs und erlebt Jahreszeiten und Wetter, die die Welt
spürbar verändern.

**Kernversprechen an den Spieler**
1. Dein Wesen lebt weiter, auch wenn die App zu ist.
2. Du wirst niemals bestraft. Nie.
3. Jede Woche gibt es etwas Neues zu entdecken — nicht etwas Neues zu *grinden*.

---

## 2. Zielgruppe & Positionierung

| | |
|---|---|
| **Primär** | 18–40, Cozy-Game-Publikum (Stardew Valley, Animal Crossing, Neko Atsume), Nostalgie für Tamagotchi/Pokémon |
| **Sekundär** | 10–17, Sammel- und Kreaturenfans |
| **Altersfreigabe** | Ziel **4+ / USK 0** — das erzwingt Designregeln (kein Freitext-Chat, keine Lootboxen, keine Zeit-gegen-Geld-Käufe) |
| **Sessions** | 3–6 Kurz-Checks à 60 Sek. + 1 Session à 10–20 Min. pro Tag |
| **Abgrenzung** | Tamagotchi bestraft. Pokémon GO braucht Bewegung. Neko Atsume hat keine Tiefe. NUBI ist die Schnittmenge: Bindung + Sammeltiefe + Null Druck. |

---

## 3. Design-Säulen

Jede Feature-Entscheidung muss sich an diesen fünf Säulen messen lassen. Was keiner Säule
dient, kommt nicht ins Spiel.

### Säule 1 — Bindung statt Buchhaltung
Der Spieler soll *sein* Wesen erkennen, nicht seine Statuswerte verwalten. Persönlichkeit,
Vorlieben, Erinnerungen und Reaktionen haben Vorrang vor Zahlen. Balken sind sekundär und
dürfen im UI klein sein.

### Säule 2 — Zeit ist ein Geschenk, keine Schuld
Echtzeit erzeugt Vorfreude („die Blume blüht morgen früh"), niemals Schuldgefühle
(„du hast mich verhungern lassen"). Jeder Offline-Zeitraum wird beim Wiedereinstieg
positiv aufgelöst.

### Säule 3 — Keine Bestrafung, niemals
Es gibt keinen Tod, keinen permanenten Verlust, keine verpassbaren Inhalte ohne
Nachholpfad, keine Fail-States. Negative Zustände sind immer *temporär*, *lesbar* und
*mit einer klaren Handlung lösbar*.

### Säule 4 — Entdecken schlägt Wiederholen
Fortschritt kommt aus neuen Kombinationen (Element × Jahreszeit × Wetter × Persönlichkeit),
nicht aus dem 40. Durchlauf desselben Dungeons. Wiederholbare Aktivitäten sind kurz und
werden nie zur Pflicht.

### Säule 5 — Alles ist Daten
Kreaturen, Evolutionen, Items, Quests, Dungeons, Events, Wetter-Effekte und Balancing
liegen als Content-Daten vor, nicht als Code. Ein Content-Update ist eine Datei, kein Release.

---

## 4. Spielschleifen

Drei ineinandergreifende Zeitschleifen tragen das Spiel über Monate.

### 4.1 Micro-Loop — „Der Check-in" (30–90 Sek., mehrfach täglich)
App öffnen → **Rückkehr-Zusammenfassung** („Während du weg warst …") → 1–3 Pflegegesten
(füttern, streicheln, wecken/zudecken) → Ernte/Fundstücke einsammeln → schließen.

*Belohnung:* sofortiges Feedback, Fortschrittshäppchen, emotionaler Moment.
*Regel:* Der Check-in darf **nie** eine Warnung, ein rotes Ausrufezeichen oder einen
Vorwurf enthalten.

### 4.2 Meso-Loop — „Die Session" (10–20 Min., ~1× täglich)
Tagesquests ansehen → Ausflug/Dungeon (5–10 Min.) → Beute verwerten (Kochen, Craften,
Anziehen) → Zucht/Ei-Verwaltung → Album pflegen → Wohnraum/Deko anpassen.

### 4.3 Macro-Loop — „Die Reise" (Wochen bis Monate)
Album vervollständigen → Evolutionspfade freischalten → Story-Kapitel → Saison-Events →
Achievements → seltene Varianten → neue Regionen (Post-Launch).

```
 CHECK-IN  ──►  Pflege ──► Ressourcen ──►  SESSION  ──► Ausflüge ──► Beute
    ▲                                          │                       │
    │                                          ▼                       ▼
    └──────── Bindung / Freundschaft ◄──── Evolution ◄──── Zucht / Sammlung
                                               │
                                               ▼
                                    ALBUM · SAISON · STORY  (Macro)
```

---

## 5. Kreaturen

### 5.1 Anatomie einer Kreatur

Eine Kreatur besteht aus drei Datenebenen — diese Trennung ist entscheidend für
Erweiterbarkeit:

| Ebene | Inhalt | Herkunft |
|---|---|---|
| **Species** (Art) | Basiswerte, Element, Seltenheit, Evolutionsgraph, Vorlieben, Art-Artwork | Content-Datei, unveränderlich |
| **Individual** (Individuum) | Persönlichkeit, Anlagen, Variante, Geschlecht/Form, Name, Abstammung | bei Erzeugung gewürfelt/vererbt |
| **State** (Zustand) | Bedürfnisse, Level, EP, Freundschaft, Kleidung, Zustände, Zeitstempel | verändert sich ständig, wird gespeichert |

### 5.2 Bedürfnisse & Werte

| Wert | Bereich | Verhalten | Sichtbarkeit |
|---|---|---|---|
| **Sättigung** (Hunger) | 0–100 | −4/h wach, −1/h schlafend | Balken |
| **Energie** | 0–100 | Aktionsressource: Ausflug/Kampf kostet; Schlaf und Ruhe füllen | Balken |
| **Müdigkeit** | 0–100 | folgt dem Tagesrhythmus der Kreatur (jede Art hat eigene Schlafenszeit) | Symbol |
| **Stimmung** (Glück) | 0–100 | kurzfristig, reagiert auf Interaktion, Lieblingsessen, Wetter, Kleidung | Gesichtsausdruck |
| **Gesundheit** | 0–100 | träge; sinkt nur, wenn andere Werte **lange** im roten Bereich sind | Symbol |
| **Freundschaft** | 0–100 | **steigt monoton, sinkt nie** — nur die Zuwachsrate variiert | Herz-Anzeige |
| **Erfahrung / Level** | 1–50 | aus Aktivitäten, Kämpfen, Pflege, Quests | Zahl |

**Warum Energie *und* Müdigkeit?** Beides ist gefordert und beides hat eine eigene Rolle:
Energie ist die *Aktionsressource* (Ausflüge kosten Energie), Müdigkeit ist der
*Tagesrhythmus* (die Kreatur will abends schlafen, unabhängig davon wie viel Energie sie
noch hat). Sie überschneiden sich bewusst nur teilweise.

### 5.3 Der Komfort-Korridor (Anti-Bestrafungs-Kern)

Bedürfnisse driften **nicht gegen 0**, sondern gegen einen Ruhewert:

```
100 ┤ ████████████ optimal (Bonus-Erträge, spezielle Animationen)
 60 ┤ ░░░░░░░░░░░░ zufrieden (Normalzustand)
 30 ┤ ▒▒▒▒▒▒▒▒▒▒▒▒ „möchte etwas" (sanfter Hinweis, kein Alarm)
 25 ┤ ──────────── HARTER BODEN — Offline-Verfall stoppt hier
  0 ┤              nur durch aktive Fehlnutzung erreichbar (praktisch nie)
```

**Gedämpfter Offline-Verfall:** Der Verfall verlangsamt sich asymptotisch.
Nach 8 h halbe Rate, nach 24 h Viertel-Rate, Boden bei 25 %. Konkret:
2 Stunden weg ≈ deutlicher Hunger. 2 Wochen weg ≈ *auch nur* deutlicher Hunger,
plus ein sehr glückliches Wiedersehen.

**Rückkehr-Bonus statt Rückkehr-Strafe:** Ab 24 h Abwesenheit bekommt der Spieler eine
„Sehnsuchts-Szene" (Kreatur freut sich, kleines Geschenk, Freundschaftsbonus). Je länger
weg, desto herzlicher der Empfang — bis zu einem Deckel.

### 5.4 Zustände statt Strafen

Negative Zustände sind kurzlebige Aufgaben mit klarer Lösung, nie Blocker:

| Zustand | Auslöser | Wirkung | Lösung |
|---|---|---|---|
| Schnupfen | lange kalte/nasse Wetterlage ohne Schutz | −10 % Ertrag, niedliche Nies-Animation | Wärmetee + 1× Schlaf |
| Bauchweh | zu viel Süßes | keine Süßigkeiten für 4 h | Kräutersuppe oder abwarten |
| Trübsal | sehr lange keine Interaktion | Stimmung gedeckelt bei 50 | 3 Interaktionen |
| Erschöpft | Ausflug abgebrochen | kein Ausflug für 30 Min. | Ruhen (verkürzbar) |

**Nie:** Statverlust, Levelverlust, Item-Verlust, Kreaturenverlust, gesperrte Inhalte.

### 5.5 Persönlichkeit

Fünf verdeckte Achsen (0–100), bei Erzeugung gewürfelt bzw. vererbt:
**Mut · Neugier · Verspieltheit · Gelassenheit · Eigensinn**

Daraus wird ein sichtbares **Temperament-Label** abgeleitet (z. B. „Draufgänger",
„Träumer", „Sturkopf", „Kuschelmonster") — 16 Labels aus Achsen-Kombinationen.

Persönlichkeit beeinflusst:
- Leerlauf-Animationen und Reaktionen (spürbarster Effekt!)
- Vorlieben: Lieblingsessen, Lieblingswetter, Lieblingsaktivität
- Stat-Wachstumsmodifikatoren (±10 %)
- Kampfverhalten (Initiative, bevorzugte Haltung)
- **Evolutionspfade** (ein mutiges Wesen entwickelt sich anders als ein gelassenes)

### 5.6 Elemente

Sieben Elemente, als Datentabelle definiert (Matrix erweiterbar ohne Codeänderung):

```
Kreis:   Blatt ─► Welle ─► Glut ─► Blatt          (×1.5 stark / ×0.75 schwach)
Paar:    Stein ◄──► Wind                          (gegenseitig stark)
Paar:    Schimmer ◄──► Nacht                      (gegenseitig stark)
```
Keine Immunitäten, keine ×0 — Strategie soll belohnt, nicht erzwungen werden.

### 5.7 Seltenheit & Varianten

**Seltenheit** (Art-Eigenschaft): Gewöhnlich · Selten · Episch · Mythisch
**Varianten** (Individuums-Eigenschaft, orthogonal):

| Variante | Chance | Herkunft |
|---|---|---|
| Standard | ~96 % | – |
| Schimmerform | 1 : 400 (Zucht: 1 : 150) | alternative Farbpalette + Partikel |
| Saisonform | nur zu einer Jahreszeit | z. B. Winterfell |
| Eventform | zeitlich begrenzt, kehrt in Reruns wieder | Events |

**Pity-System:** Nach 200 erfolglosen Bruten ist die nächste garantiert eine
Schimmerform. Zufall darf enttäuschen, aber nicht frustrieren.

### 5.8 Evolution — der wichtigste Erweiterungspunkt

Wachstumsstufen: **Ei → Küken → Jungtier → Ausgewachsen → Zenit** (Zenit = optionale
Endgame-Stufe, nur über besondere Bedingungen).

Ab „Jungtier" verzweigen die Pfade. Eine Evolution ist ein **Datensatz** mit einer Liste
von Bedingungen und einer Verknüpfung (`alle` / `mindestens eine` / `gewichtet`):

```yaml
# Beispiel-Content, kein Code
evolution:
  from: sprout_youngling
  branches:
    - to: sprout_adult_bloom
      require: { all: [ {level: 16}, {friendship: ">=60"}, {season: spring} ] }
    - to: sprout_adult_thorn
      require: { all: [ {level: 16}, {personality: {courage: ">=70"}},
                        {battlesWon: ">=15"} ] }
    - to: sprout_adult_lantern
      require: { all: [ {level: 16}, {itemUsed: lantern_seed},
                        {timeOfDay: night}, {weather: fog} ] }
```

Verfügbare Bedingungstypen (Startset, erweiterbar):
`level` · `friendship` · `personality` · `season` · `weather` · `timeOfDay` ·
`itemUsed` · `foodEatenCount(tag)` · `dungeonCleared` · `battlesWon` ·
`equippedCosmeticTag` · `daysOwned` · `questCompleted` · `moonPhase`

**Design-Regel:** Jede Kreatur hat mindestens einen Pfad, der **ohne Kampf** erreichbar ist.
Cozy-Spieler dürfen nie gezwungen werden zu kämpfen.

---

## 6. Kleidung & Kosmetik

Slots: **Kopf · Augen · Körper · Rücken · Hand · Boden (Untergrund/Effekt)**

Rein kosmetisch — **keine Stat-Effekte**, ohne Ausnahme. Die einzige mechanische Wirkung:
Kleidung kann *Tags* tragen (`warm`, `festlich`, `ritterlich`), und Evolutionen sowie
Stimmungs-Vorlieben dürfen auf Tags reagieren. Das ist kein Power-Vorteil, sondern ein
Freischalt-Pfad — und macht Kosmetik spielrelevant, ohne Pay-to-Win zu werden.

Quellen: Dungeon-Beute, Quests, Events, Saisonfortschritt, Handwerk, IAP (nur Kosmetik).
Jede Kreatur „mag" bestimmte Tags (Persönlichkeit) → kleiner Stimmungsbonus, sichtbare Freude.

---

## 7. Zeit, Wetter, Jahreszeiten

### 7.1 Echtzeit-Modell
Die Simulation ist **zeitstempelbasiert, nicht tickbasiert**: Es wird nicht permanent
gerechnet, sondern beim Öffnen der App die verstrichene Zeit einmalig aufgelöst
(deterministisch, mit gedämpfter Kurve). Vorteile: kein Batterieverbrauch, exakt
reproduzierbar, testbar, manipulationssicherer.

Weiterlaufende Prozesse: Hunger/Müdigkeit, Schlaf, Pflanzenwachstum, Ei-Reifung,
Quest-Timer, Kochen/Handwerk, Genesung, Post/Besuche.

### 7.2 Wetter
Fünf Grundlagen: **Sonne · Regen · Schnee · Wind · Nebel** (+ Kombinationen wie Gewitter).
Wetter wirkt auf: Spawnraten, Ausflugs-Ereignisse, Pflanzenwachstum, Stimmung
(persönlichkeitsabhängig), Evolutionsbedingungen, Deko-Beleuchtung.

> **Offene Entscheidung (siehe §16):** echtes lokales Wetter via WeatherKit vs. simuliert.

### 7.3 Jahreszeiten
An das reale Datum gekoppelt, mit Umschaltung für die Südhalbkugel. Jede Jahreszeit
(~13 Wochen) verändert Kulisse, Musik, Pflanzen, Quests, Dungeon-Varianten, Spawns und
Saisonformen. Jede Jahreszeit bringt einen **kosmetischen Saisonpfad** (kein Bezahl-Pass,
kein FOMO — Restfortschritt wandert nach Saisonende in den „Erinnerungs-Katalog").

---

## 8. Ausflüge & Dungeons

**Format:** Kurzabenteuer statt Endlos-Dungeon. 3–5 Knoten, 5–10 Minuten.

```
      ┌─ Kampf ──┐        ┌─ Schatz ─┐
Start ┤          ├─ Wahl ─┤          ├─ Ziel (garantierte Belohnung)
      └─ Fund ───┘        └─ Ereignis┘
```

- Jeder Knoten ist eine **Wahl** zwischen 2 Optionen mit sichtbaren Risiko/Ertrag-Profilen.
- Kosten: Energie (nicht Echtzeit-Wartezeit, nicht Geld).
- **Kein Fail-State:** Bei Niederlage endet der Ausflug früher, alles Gesammelte bleibt,
  die Kreatur ist kurz „erschöpft". Kein Verlust — nur ein kürzerer Lauf.
- Jahreszeit und Wetter tauschen Knotentabellen aus → derselbe Dungeon fühlt sich im
  Winter anders an.
- Belohnungen: Materialien, Kleidung, Eier, EP, seltene Items, Album-Einträge.

**MVP:** 3 Dungeons × 4 Saisonvarianten. **Release:** 8 Dungeons.

---

## 9. Kampfsystem

Leicht zu lernen, strategisch statt zufällig. Kernentscheidungen:

- **Rundenbasiert**, 1 aktive Kreatur + bis zu 2 in Reserve (Wechsel kostet eine Runde).
- **Kein Trefferwurf, kein Miss.** Schaden ist deterministisch (±5 % Varianz).
- **Gegnerabsicht wird telegrafiert** — man sieht, was der Gegner nächste Runde vorhat.
  Das macht Planung möglich und ersetzt Glück durch Lesen.
- **Schwung (Momentum) 0–5:** Basisaktionen erzeugen Schwung, starke Fähigkeiten
  verbrauchen ihn. Kein Spam der stärksten Attacke — Rhythmus statt Reflex.
- **Haltungen:** Angriff / Schutz / Fokus, lesbares Dreieck, jede kontert eine andere.
- **Elementvorteil ×1.5 / ×0.75**, immer sichtbar vor Bestätigung der Aktion.
- Kampflänge: **4–8 Runden**. Kein PvP-Timing-Druck im MVP.

Kämpfe sind ein *optionaler* Inhaltspfad (siehe §5.8): Wer nicht kämpfen will, kommt über
Pflege, Garten, Zucht und Erkundung ans Ziel — nur langsamer bei kampfspezifischen Inhalten.

---

## 10. Sammeln, Zucht & Album

### 10.1 Sammelquellen
Erkundung · Eier (Fundstücke) · Zucht · Events · Quest-Belohnungen · Tausch (später)

### 10.2 Zucht
Zwei ausgewachsene Kreaturen → Ei nach Echtzeit-Reifung (2–12 h je nach Seltenheit).

Vererbung:
- **Element:** von einem Elternteil; 3 % Chance auf eine Kreuzungsart (Datentabelle)
- **Persönlichkeit:** Mittelwert der Eltern ± Rauschen
- **Anlagen** (verdeckte Stat-Talente 0–5 je Wert): jeweils besserer Elternwert, 1 neu gewürfelt
- **Variante:** erhöhte Schimmer-Chance, Pity-Zähler greift

Keine Kosten-Spirale, keine Zuchtkosten in Echtgeld, Cooldown statt Gebühr.

### 10.3 Album (Pokédex-Äquivalent)
Zeigt: entdeckte Arten, alle Evolutionsstufen und -pfade (inkl. *nicht* erfüllter
Bedingungen als Hinweis-Rätsel), Varianten, Fundorte, Jahreszeit/Wetter-Bedingungen,
getragene Kleidung, erste Begegnung, Zuchtstammbaum.

Album-Meilensteine geben Belohnungen — das Album ist der eigentliche Langzeit-Motor.

---

## 11. Quests & Story

| Typ | Menge | Regel gegen Druck |
|---|---|---|
| **Täglich** | 3 aus Pool | Nicht erledigte Tage sammeln sich als „Wochen-Puffer" (max. 7) — verpasste Tage lassen sich nachholen |
| **Wöchentlich** | 5 | laufen 7 Tage, keine Uhrzeitbindung |
| **Story** | Kapitel | kein Timer, jederzeit fortsetzbar |
| **Sammel** | Album-Meilensteine | dauerhaft |
| **Event** | saisonal | Reruns garantiert |

**Story:** ~3 Kapitel im MVP, 8–10 zum Release. Zweck: **Systeme freischalten und
erklären** (Kap. 1 → Pflege & Garten, Kap. 2 → Ausflüge & Kampf, Kap. 3 → Zucht & Album).
Vollständig überspringbar — beim Überspringen werden alle Systeme sofort freigeschaltet.
Ton: warm, leise, ohne Weltuntergang.

---

## 12. Fortschritt & Langzeitmotivation

Was einen Spieler in Monat 4 noch bindet:

1. **Album-Vervollständigung** — Evolutionspfade sind kleine Rätsel, keine Grind-Ziele
2. **Saisonwechsel** — alle 13 Wochen sieht die Welt anders aus, mit neuen Formen
3. **Events mit Rerun-Garantie** — Vorfreude ohne FOMO
4. **Zucht-Optimierung** — Anlagen, Varianten, Kreuzungsarten als Sandbox
5. **Achievements & Titel** — breit, nicht tief; auch für Cozy-Verhalten („1000× gestreichelt")
6. **Wohnraum & Deko** (Post-MVP) — Ausdruck statt Zahlen
7. **Bindungs-Meilensteine** — Freundschaftsstufen schalten Erinnerungs-Szenen frei

**Explizit verbotene Muster:** Energiebalken mit Kaufoption · tägliche Login-Ketten mit
Reset bei Aussetzer · zeitlich exklusive Inhalte ohne Nachholpfad · Ausdauer-Timer, die
Spielzeit begrenzen · Zufalls-Lootboxen gegen Geld.

---

## 13. Monetarisierung

**Modell:** Einmalkauf (Premium, ~7–10 €) + optionale kosmetische IAP.

| Erlaubt | Verboten |
|---|---|
| Kleidungssets, Deko | Alles, was Fortschritt beschleunigt |
| Alternative Skins | Energie, Rohstoffe, Währung |
| Soundtrack | Bessere Kampfwerte |
| Kosmetische Wohnraum-Themes | Zufalls-Lootboxen |
| Komfort ohne Fortschritt (z. B. zusätzliche Album-Filter, Foto-Modus Pro) | Exklusive Kreaturen mit Spielvorteil |

**Prüfregel für jeden künftigen IAP:** *„Kann ein Spieler ohne diesen Kauf am Ende
dasselbe erreichen, nur mit anderem Aussehen?"* — Wenn nein: nicht ins Spiel.

---

## 14. Umfang: MVP vs. Release

| Bereich | MVP (Phase 6–10) | Release 1.0 |
|---|---|---|
| Kreaturen (Arten) | 9 Basisarten + Evolutionen ≈ 18 Einträge | ~50 |
| Startauswahl | 3 Kreaturen | 3 (rotierend nach Saison) |
| Elemente | 7 (Daten stehen von Anfang an) | 7 |
| Dungeons | 3 | 8 |
| Kleidung | 20 Teile | 120+ |
| Story | 3 Kapitel | 8–10 |
| Wetter/Jahreszeiten | vollständig | vollständig |
| Zucht | ja | + Kreuzungsarten |
| Kampf | vollständig, 12 Fähigkeiten | 60+ Fähigkeiten |
| Cloud Sync | ja (Phase 9) | ja |
| Multiplayer | **nur Architektur vorbereitet** | Tausch + Freundesliste |

---

## 15. Risiken

| Risiko | Wirkung | Gegenmaßnahme |
|---|---|---|
| **Art-Aufwand für 50 Kreaturen × Stufen × Varianten** | größter Kostenblock des Projekts | Modularer Vektor-Aufbau (Körper + austauschbare Teile), Farbpaletten-Varianten statt neuer Zeichnungen; MVP mit programmatischen Platzhaltern |
| Zeitmanipulation (Uhr vorstellen) | Fortschritt-Exploit | Serverzeit bei Sync, monotone Zeitquelle, „Zeit kann nur vorwärts" -Regel im Save |
| Feature-Überfrachtung | MVP wird nie fertig | Phasenplan strikt, jedes System hinter Feature-Flag |
| „Kein Zwang" → „kein Grund zurückzukehren" | Retention bricht ein | Vorfreude-Anker: es wartet immer etwas Fertiges (Ei, Ernte, Quest) |
| Cloud-Konflikte (zwei Geräte offline) | Datenverlust | Ereignis-basierte Merge-Strategie + „letzter Stand gewinnt" nur als Fallback, Backup-Snapshots |
| Altersfreigabe 4+ und Multiplayer | Store-Ablehnung | Kein Freitext-Chat, nur vordefinierte Emotes/Stempel |

---

## 16. Getroffene Design-Entscheidungen

| Frage | Entscheidung | Folge für das Design |
|---|---|---|
| Wetterquelle | **simuliertes Spielwetter** | Wetter ist planbarer Content statt Zufall der Realität: Events können verlässlich auf „Schnee" oder „Nebel" bauen, Evolutionsbedingungen sind für jeden Spieler erreichbar, und es braucht keine Standortfreigabe |
| Cloud-Backend | **zunächst lokal**, Entscheidung in Phase 9 | Spielstandsicherheit muss bis dahin vollständig lokal gewährleistet sein (Snapshots, Backups) |
| Kunst-Pipeline MVP | **programmatische Vektor-Darstellung** | Kreaturen-Aussehen ist ein Datensatz aus Körperform, Teilen und Farbpalette — Varianten und Saisonformen kosten dadurch fast nichts |
| Mindest-iOS | **iOS 18+** | moderne SwiftUI-APIs, Swift 6 |

> Der Verzicht auf Echtwetter kostet den „draußen regnet es auch"-Moment. Falls das
> später doch gewünscht ist, bleibt der Weg offen (siehe ADR-003 in der Architektur):
> `ClimateSystem` bezieht seine Eingabe über ein Protokoll, ein Realwetter-Adapter wäre
> nachrüstbar, ohne Spiellogik zu ändern.

---

## 17. Was Phase 2 aus diesem Dokument mitnimmt

Die architektonisch bindenden Punkte aus diesem GDD:

- **Zeitstempelbasierte, deterministische Simulation** (nicht tickbasiert) → eigenes
  `TimeProgressionEngine`-Modul, vollständig unit-testbar
- **Species / Individual / State** als getrennte Datenebenen
- **Bedingungssystem für Evolution** als generischer, datengetriebener Regel-Evaluator —
  derselbe Evaluator bedient Quests, Spawns und Events
- **Content als Daten** → Content-Bundle mit Schema-Version und Validierung im Build
- **Feature-Flags pro System** → Story-Freischaltungen und schrittweiser Ausbau
- **Multiplayer-Vorbereitung** → alle Zustandsänderungen als Ereignisse, nicht als
  direkte Mutationen (macht spätere Server-Autorität möglich)

---

*Ende Phase 1 — Entwurf v0.1*
