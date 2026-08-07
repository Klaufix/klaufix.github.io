//  ClimateSystem
//
//  Verantwortung
//  Simuliertes Wetter, Jahreszeiten, Tageszeit, Mondphase. Bezieht seine Eingabe ueber
//  ein Protokoll, damit ein Realwetter-Adapter nachruestbar bleibt (ADR-003).
//
//  Abhaengigkeiten
//  Darf importieren: GameCore, GameContent, GameRules
//  Darf niemals ein anderes System importieren. Systemuebergreifende Wirkung
//  entsteht ausschliesslich ueber Events (siehe docs/02-technische-architektur.md).
//
//  Stand: Jahreszeit aus Datum und Hemisphaere, zustandsloses Wetter aus
//  Startwert und Zeitfenster, Zerlegung der Zeit in Stundenabschnitte (Phase 6).
//  Offen: Wetterwirkung auf Spawns und Aktivitaeten (Phase 7).
