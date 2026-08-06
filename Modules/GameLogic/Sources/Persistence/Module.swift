//  Persistence
//
//  Verantwortung
//  Atomares Schreiben des Snapshots, angehaengtes Event-Journal, rollierende Backups, Migrationskette.
//
//  Abhaengigkeiten
//  Darf importieren: GameCore, GameState
//  Darf niemals ein anderes System importieren. Systemuebergreifende Wirkung
//  entsteht ausschliesslich ueber Events (siehe docs/02-technische-architektur.md).
//
//  Wird mit Inhalt gefuellt in Phase 8.
