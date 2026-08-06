//  GameState
//
//  Verantwortung
//  Aggregierter, Codable Zustandsbaum aus allen System-Teilzustaenden. Kennt die
//  Systeme, aber kein System kennt GameState.
//
//  Abhaengigkeiten
//  Darf importieren: GameCore + alle Systeme
//  Darf niemals ein anderes System importieren. Systemuebergreifende Wirkung
//  entsteht ausschliesslich ueber Events (siehe docs/02-technische-architektur.md).
//
//  Stand: Spielstand-Wurzel und PlayerState sind da (Phase 4).
//  Offen: Teilzustaende der uebrigen Systeme, sobald diese entstehen.
