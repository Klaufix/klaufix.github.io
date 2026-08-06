//  GameCore
//
//  Verantwortung
//  Typisierte IDs, Zeitquelle, seedbasierter Zufall, Basis-Protokolle fuer
//  Commands und Events, gemeinsame Wertetypen sowie die *Form* der
//  Bedingungsausdruecke (ausgewertet werden sie in GameRules).
//
//  Abhaengigkeiten
//  Darf importieren: nichts aus diesem Projekt (Foundation ausgenommen)
//  Darf niemals ein anderes System importieren. Systemuebergreifende Wirkung
//  entsteht ausschliesslich ueber Events (siehe docs/02-technische-architektur.md).
//
//  Stand: Identifier, Wertetypen mit Invarianten, Taxonomie, Bedingungs-
//  Ausdruecke, Zeitzeiger, Zufallsstroeme und Event-Umschlag sind da (Phase 4).
//  Offen: Command-Registry und Event-Dekodierung (Phase 6).
