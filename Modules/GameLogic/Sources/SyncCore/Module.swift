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
//  Stand: Journal, Zusammenfuehrung, Zeiger, Kappung und CloudKit-Adapter
//  (Phase 9). Die Zusammenfuehrung ist plattformunabhaengig und getestet,
//  der Adapter kompiliert nur.
//  Offen: Verdrahtung in der App, Push-Benachrichtigungen (Phase 10).
