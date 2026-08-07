# Cloud Sync — Projekt „NUBI"

> **Status:** Phase 9 — v0.1
> **Grundlage:** [Architektur §10](02-technische-architektur.md) · [Save System](08-save-system.md)

---

## 1. Die Entscheidung: CloudKit

In Phase 1 wurde das Backend bewusst offen gelassen. Jetzt ist gewählt.

| | CloudKit | Firebase |
|---|---|---|
| Serverbetrieb | keiner | keiner, aber Konfiguration |
| Kosten | kostenlos bis sehr hohe Nutzerzahlen | ab Wachstum laufend |
| Backup | iCloud, automatisch | selbst zu bauen |
| Datenschutz bei Altersfreigabe 4+ | Daten bleiben in Apples Konto des Nutzers | eigene Erklärung, eigene Verantwortung |
| Plattformen | nur Apple | überall |
| Multiplayer mit Server-Autorität | begrenzt | stark |

Ausschlaggebend war die vierte Zeile. Ein Spiel für Kinder, das Spielstände auf eigenen
Servern hält, braucht eine Datenschutzerklärung, ein Löschkonzept und jemanden, der
dafür geradesteht. CloudKit legt die Daten in das iCloud-Konto des Nutzers — er besitzt
sie, wir sehen sie nie.

Der Preis ist die Bindung an Apple-Plattformen. Für ein iOS-Spiel ist das keiner.

Für späteren Multiplayer mit Server-Autorität wird ein eigener kleiner Dienst dazukommen
müssen. Das ist absehbar und kein Widerspruch: Der Abgleich der eigenen Geräte und ein
Spielserver sind zwei verschiedene Aufgaben.

**ADR-008** ersetzt damit den offenen Punkt aus ADR-002.

---

## 2. Was tatsächlich abgeglichen wird

Nicht der Spielstand, sondern die **Ereignisse**, die zu ihm geführt haben. Der Umschlag
dafür steht seit Phase 4 bereit: Kennung, Geräte-ID, logische Uhr, Zeitstempel.

```
Gerät A: [fed#1, petted#2]          Gerät B: [slept#3]
                    \                  /
                     ── Zusammenführung ──
                              │
              [fed#1, petted#2, slept#3]   auf beiden Geräten identisch
```

Die Zusammenführung ist **reine Rechnerei über Listen** — kein Netzwerk, kein Konto,
keine Apple-Plattform. Genau deshalb ist sie vollständig getestet, während der
CloudKit-Adapter dünn bleibt.

---

## 3. Drei Eigenschaften, die stimmen müssen

### Reihenfolgeunabhängig
Ob die Pakete in der Reihenfolge 1-2-3 oder 3-2-1 eintreffen, ändert das Ergebnis nicht.
Sortiert wird nach logischer Uhr, bei Gleichstand nach Geräte-ID, zuletzt nach Kennung.

Der letzte Schritt sieht überflüssig aus und ist es nicht: Ohne ihn könnten zwei
Ereignisse desselben Geräts mit derselben Uhr unterschiedlich einsortiert werden — und
zwei Geräte kämen zu unterschiedlichen Spielständen.

### Idempotent
Dasselbe Ereignis zweimal zu empfangen ändert nichts. Auf CloudKit-Seite trägt der Satz
die Ereignis-Kennung als Namen — zweimaliges Hochladen ist derselbe Satz, nicht zwei.
Idempotenz aus der Datenstruktur statt aus Logik.

### Additiv
**Ein Abgleich nimmt niemals etwas weg.** Wenn zwei Geräte dieselbe Kreatur
weiterentwickelt haben, behält der Spieler beides. Ein Abgleich, der etwas wegnimmt,
wäre die schlimmste Form von Bestrafung: Sie träfe jemanden, der alles richtig gemacht
hat. Ein Test hält es fest.

---

## 4. Das Journal wird nicht ewig länger

`prune(upTo:)` verwirft Einträge unterhalb des Zeigers — also nur das, was **beide**
Seiten bestätigt haben. Deshalb der Zeiger als Grenze und kein Datum: Ein Gerät, das
drei Monate offline war, darf seine Ereignisse nicht verlieren, nur weil sie alt sind.

Der vollständige Schnappschuss aus Phase 8 bleibt als Rettungsleine daneben: Wenn ein
Journal einmal nicht ausreicht, gibt es immer noch den ganzen Zustand.

---

## 5. Ohne Konto läuft alles weiter

`LocalOnlySyncBackend` ist die Voreinstellung. Es tut nichts, und das ist die Zusage:
**Cloud ist Komfort, nicht Voraussetzung.** Wer sich nie bei iCloud anmeldet, spielt ein
vollständiges Spiel — mit lokalem Spielstand, Sicherungen und Migration wie gehabt.

Auch die Fehlermeldungen folgen dem: „Nicht bei iCloud angemeldet. Das Spiel läuft
weiter, nur ohne Abgleich." Kein Ausrufezeichen, keine Sperre.

---

## 6. Was geprüft ist — und was nicht

| Teil | Stand |
|---|---|
| Zusammenführung, Ordnung, Idempotenz, Kappen | **17 Tests**, laufen auf Linux |
| `LocalOnlySyncBackend` | getestet |
| `CloudKitSyncBackend` | **kompiliert, sonst nichts** |

Das ist eine bewusste Aufteilung, keine Nachlässigkeit. Der Adapter ist gegen keinen
echten Container gelaufen — die CI hat weder Apple-Konto noch Berechtigungen. Das Risiko
sitzt aber ohnehin nicht dort: Ein Adapter, der Sätze falsch abbildet, fällt beim ersten
Versuch auf. Eine Zusammenführung, die je nach Reihenfolge unterschiedliche Spielstände
erzeugt, fällt erst Monate später auf — bei einem Nutzer, mit echten Daten.

### Was außerhalb des Codes nötig ist

- Apple Developer Programm
- iCloud-Berechtigungsschein im App-Ziel
- Ein Feld-Index auf `lamport` im CloudKit-Dashboard. **Ohne ihn liefert die Abfrage
  nichts — ohne Fehlermeldung.**

---

## 7. Offene Punkte für Phase 10

- **Verdrahtung in der App**: Der Abgleich läuft noch nicht automatisch beim Start und
  beim Wechsel in den Hintergrund.
- **Konflikt-Anzeige**: Wenn zwei Geräte dieselbe Kreatur weiterentwickelt haben, soll
  der Spieler das erfahren — freundlich, nicht als Fehler.
- **Push-Benachrichtigungen** von CloudKit, damit ein zweites Gerät nicht erst beim
  Öffnen erfährt, dass es etwas Neues gibt.
- **Journal-Kappung** wird noch nicht automatisch ausgelöst.

---

*Ende Phase 9 — v0.1*
