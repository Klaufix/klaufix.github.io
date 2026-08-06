//  GameState
//
//  Verantwortung
//  Aggregierter, Codable Zustandsbaum aus allen System-Teilzustaenden. Kennt die Systeme, aber kein System kennt GameState.
//
//  Abhaengigkeiten
//  Darf importieren: GameCore + alle Systeme
//  Darf niemals ein anderes System importieren. Systemuebergreifende Wirkung
//  entsteht ausschliesslich ueber Events (siehe docs/02-technische-architektur.md).
//
//  Wird mit Inhalt gefuellt in Phase 4.
