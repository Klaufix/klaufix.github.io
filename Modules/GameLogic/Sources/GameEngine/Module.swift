//  GameEngine
//
//  Verantwortung
//  Command-Dispatch an das zustaendige System, Anwendung der erzeugten Events auf den
//  GameState, Zeitaufloesung, Bereitstellung des FactProvider, Snapshot-Erzeugung fuer
//  die UI.
//
//  Abhaengigkeiten
//  Darf importieren: GameState, GameRules + alle Systeme
//  Darf niemals ein anderes System importieren. Systemuebergreifende Wirkung
//  entsteht ausschliesslich ueber Events (siehe docs/02-technische-architektur.md).
//
//  Stand: Zeitaufloesung, Command-Dispatch fuer Pflege, FactProvider und
//  Neue-Partie-Aufbau (Phase 6).
//  Offen: Event-Journal, weitere Systeme (Phase 7/8).
