//  AppComposition
//
//  Verantwortung
//  Einziger Ort, an dem die Feature-Module, die Engine, Persistenz und Sync
//  zusammengesteckt werden. Enthaelt selbst keine Spiellogik.
//
//  Abhaengigkeiten
//  Darf importieren: alle Feature-Module, GameEngine, Persistence, SyncCore
//  Darf niemals ein anderes System importieren. Systemuebergreifende Wirkung
//  entsteht ausschliesslich ueber Events (siehe docs/02-technische-architektur.md).
//
//  Stand: RootView als Platzhalter vorhanden.
//  Offen: Navigation zwischen den Feature-Modulen und das Verdrahten von
//  Engine, Persistenz und Sync (Phase 6).
