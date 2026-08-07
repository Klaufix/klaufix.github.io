//  Persistence
//
//  Verantwortung
//  Atomares Schreiben des Snapshots, angehaengtes Event-Journal, rollierende Backups,
//  Migrationskette.
//
//  Abhaengigkeiten
//  Darf importieren: GameCore, GameState
//  Darf niemals ein anderes System importieren. Systemuebergreifende Wirkung
//  entsteht ausschliesslich ueber Events (siehe docs/02-technische-architektur.md).
//
//  Stand: Snapshot mit Pruefsumme, atomares Schreiben, rollierende
//  Sicherungen, Migrationskette (Phase 8).
//  Offen: Event-Journal (Phase 9).
