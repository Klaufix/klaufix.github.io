//  SyncCore
//
//  Verantwortung
//  SyncBackend-Protokoll, Geraete-IDs, Lamport-Zaehler, Merge-Strategie. Enthaelt
//  bewusst kein konkretes Backend.
//
//  Abhaengigkeiten
//  Darf importieren: GameCore
//  Darf niemals ein anderes System importieren. Systemuebergreifende Wirkung
//  entsteht ausschliesslich ueber Events (siehe docs/02-technische-architektur.md).
//
//  Wird mit Inhalt gefuellt in Phase 9.
