# UI-Konzept — Projekt „NUBI"

> **Status:** Phase 5 — v0.1
> **Grundlage:** [Game Design](01-game-design-document.md) · [Architektur](02-technische-architektur.md)

---

## 1. Die Leitfrage

Ein Virtual Pet lebt oder stirbt an einer Frage: **Wohin schaut der Spieler zuerst?**

Bei Tamagotchi schaut er auf die Balken. Deshalb fühlt es sich an wie Buchhaltung mit
Fell. Bei NUBI soll er auf die **Kreatur** schauen — und ihren Zustand *an ihr* ablesen,
nicht an einer Zahl daneben.

Daraus folgt die gesamte Oberfläche.

---

## 2. Fünf Regeln für jeden Bildschirm

### Regel 1 — Die Kreatur ist die Hauptsache, nicht ein Bild neben Werten
Auf dem Hauptbildschirm gehören der Kreatur mindestens 55 % der Fläche. Bedürfniswerte
sind sekundär und stehen darunter, klein, ohne Rahmen, ohne Alarm.

### Regel 2 — Zustand wird gespielt, nicht angezeigt
Hunger sieht man daran, dass die Kreatur zum Napf blickt. Müdigkeit an halb geschlossenen
Augen. Die Zahl daneben ist die Bestätigung, nicht die Information.

### Regel 3 — Kein Rot, keine Ausrufezeichen, keine Badges mit Zahlen
Es gibt in der gesamten Farbpalette **kein Alarmrot**. Die stärkste Warnfarbe ist ein
warmes Bernstein, und sie bedeutet „möchte etwas", nicht „du hast versagt". Badges zeigen
nie „7 offene Aufgaben" — das ist eine Schuldenliste, und Schulden sind Bestrafung.

### Regel 4 — Jede Pflegegeste ist eine Berührung, kein Formular
Streicheln ist ein Wisch über die Kreatur. Füttern ist ein Ziehen des Futters auf sie.
Zudecken ist ein Tippen aufs Bett. Keine Bestätigungsdialoge für zärtliche Handlungen.

### Regel 5 — Die Rückkehr ist ein Wiedersehen
Nach längerer Abwesenheit öffnet sich keine Statusmeldung, sondern eine kleine Szene:
Die Kreatur freut sich. Erst danach, und nur wenn nötig, ein leiser Hinweis, was sie
gerade möchte.

---

## 3. Navigationsmodell

**iPhone:** `TabView` mit fünf Reitern — mehr passt nicht, ohne zu verwässern.

```
┌──────────────────────────────────────┐
│                                      │
│            KREATUR                   │  ← Zuhause: Pflege, Stimmung,
│         (55–65 % Fläche)             │     Rückkehr-Szene, Ernte
│                                      │
├──────────────────────────────────────┤
│  Bedürfnisse (klein, ohne Rahmen)    │
│  Tagesangebot: 1–3 sanfte Vorschläge │
├──────────────────────────────────────┤
│  🏠 Zuhause  📖 Album  🧭 Ausflug     │
│  ✅ Aufgaben  ⋯ Mehr                  │
└──────────────────────────────────────┘
```

**iPad:** `NavigationSplitView` — Seitenleiste statt Reiter, Kreatur bleibt im
Detailbereich groß. Deshalb sind schon jetzt alle Maße relativ und keine Ansicht auf
eine Breite festgenagelt.

**„Mehr"** sammelt Kleiderschrank, Zucht, Story und Einstellungen. Diese vier sind
selten, aber nicht unwichtig — sie in die Hauptleiste zu heben, würde die täglichen
Wege verlängern.

---

## 4. Der Hauptbildschirm im Detail

| Zone | Inhalt | Anteil |
|---|---|---|
| Himmel | Wetter, Jahreszeit, Tageszeit — als Hintergrund, nicht als Symbolleiste | 15 % |
| Bühne | Kreatur, Kleidung, Leerlauf-Animation, Berührungsziele | 55 % |
| Ablage | Bedürfnisse, Freundschaftsherz, 1–3 Vorschläge | 20 % |
| Reiter | Navigation | 10 % |

**Der Vorschlagsbereich ist das Gegenmodell zur Aufgabenliste.** Statt „3 Quests offen"
steht dort höchstens: *„Sie schaut zum Beet — die Sonnenbeere ist reif."* Ein Vorschlag
verschwindet, wenn er erledigt ist, und mahnt nie.

---

## 5. Designsystem

### Farben
Zwei vollständige Paletten (Tag/Nacht), semantisch benannt statt nach Farbton:
`canvas`, `surface`, `ink`, `accent`, `attention`, `positive`, `outline`.

Warum semantisch: Die Jahreszeiten sollen später die Kulisse einfärben. Wer im Code
`Color.green` schreibt, hat den Winter schon verloren.

Die Palette liegt in der SwiftUI-Umgebung (`\.palette`). Eine saisonale oder eine
Event-Palette ist damit ein Austausch an genau einer Stelle.

### Typografie
`design: .rounded` durchgehend — runde Schrift passt zum Cartoon-Stil und liest sich
freundlich. Alle Größen sind **relative Textstile** (`.largeTitle`, `.body` …), damit
Dynamic Type ohne Sonderbehandlung funktioniert.

### Abstände
Vierer-Raster: 4 / 8 / 12 / 16 / 24 / 32. Mindestgröße für Berührungsziele: 44 pt.

### Komponenten (Startsatz)
`SoftCard` · `PrimaryActionButton` · `NeedMeter` · `TagChip`

`NeedMeter` verdient eine Erklärung: Er zeigt **keine Zahl**, sondern einen Balken mit
Symbol und Beschriftung. Unterhalb des Komfort-Korridors wechselt er auf `attention` —
Bernstein, nie Rot. Für VoiceOver und für Farbfehlsichtigkeit steht der Zustand
zusätzlich als Wort da; Farbe ist nie der einzige Träger einer Information.

---

## 6. Darstellung der Kreatur

Das Aussehen ist Daten (ADR-005). Der Renderer bekommt einen `AppearanceDescriptor`
und zeichnet daraus:

```
AppearanceDefinition (Content)          AppearanceDescriptor (Darstellung)
 silhouette, parts, defaultPalette  ──►  silhouette, parts, palette,
 variantPalettes                          scale, cosmetics (in Zeichenreihenfolge)
        + Variante + Wachstumsstufe
        + getragene Kleidung
```

Die Auflösung (`AppearanceResolver`) ist **frei von SwiftUI** und dadurch testbar. Nur
das Zeichnen selbst braucht SwiftUI.

**Stimmung statt Zustandsliste:** Der Renderer kennt fünf Stimmungen — `content`,
`happy`, `sleepy`, `hungry`, `unwell`. Sie verändern Augen, Mund und Neigung. Das ist
Regel 2 in Code: Der Zustand ist am Gesicht ablesbar.

**Farbpaletten mit stabilem Rückfall:** Unbekannte Paletten-IDs ergeben keine graue Box,
sondern eine aus der ID abgeleitete Farbe. Wichtig dabei: Die Ableitung benutzt eine
eigene FNV-Streuung, **nicht** Swifts `hashValue` — der ist pro Programmstart anders
gesalzen, die Kreatur hätte bei jedem Start eine andere Farbe.

**Reduzierte Bewegung** wird respektiert: Die Atem-Animation hält an, die Kreatur bleibt
sichtbar und lesbar.

---

## 7. Barrierefreiheit

Kein Nachtrag, sondern Teil der Komponenten:

| Anforderung | Umsetzung |
|---|---|
| Dynamic Type | ausschließlich relative Textstile, keine festen Punktgrößen |
| VoiceOver | Die Kreatur ist **ein** Element mit einer Beschreibung in Worten: „Möhrchen, zufrieden, ein wenig hungrig" — nicht fünf Balken zum Durchtabben |
| Farbfehlsichtigkeit | Zustand immer über Symbol **und** Text, Farbe nur als Verstärkung |
| Reduzierte Bewegung | Leerlauf- und Übergangsanimationen halten an |
| Motorik | Mindestziel 44 pt; jede Wischgeste hat eine Tipp-Alternative |
| Kontrast | Text auf `surface` erreicht mindestens 4.5:1 in beiden Paletten |

---

## 8. Sprache

Deutsch und Englisch zum Start. **Kein Anzeigetext im Content** — Content trägt
Lokalisierungsschlüssel (`species.sprout_youngling.name`), die Übersetzung liegt in den
String-Katalogen.

Der Ton ist warm und knapp. Nie tadelnd, nie ironisch, nie dringlich. „Sie hat dich
vermisst" statt „Du warst 3 Tage weg".

---

## 9. Was in dieser Phase gebaut wurde

| Modul | Inhalt |
|---|---|
| `DesignSystem` | Palette (Tag/Nacht, über Umgebung austauschbar), Typografie, Raster, vier Komponenten |
| `CreatureRenderer` | Deskriptor, Auflösung aus Content, Stimmungen, Farbpaletten, `CreatureView` |
| `AppComposition` | Schaubild, das Kreatur, Stimmungen und Komponenten zeigt |

Die Feature-Module bleiben leer — sie entstehen in Phase 6 mit dem echten Gameplay.

---

## 10. Offene Punkte für Phase 6

- **Hintergrund-Kulisse** je Wetter und Jahreszeit (bisher nur Farbfläche)
- **Übergänge** zwischen den Reitern; die Kreatur soll nicht „wegblenden"
- **Rückkehr-Szene** als eigener Ablauf inkl. Ton
- **String-Kataloge** anlegen, sobald die ersten echten Texte entstehen
- **Haptik** für Pflegegesten

---

*Ende Phase 5 — v0.1*
