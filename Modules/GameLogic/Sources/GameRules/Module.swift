//  GameRules
//
//  Verantwortung
//  Generischer Bedingungs-Evaluator (ConditionExpression, Fact, Comparator) sowie
//  Balancing-Formeln und -Kurven. Bedient Evolution, Quests, Spawns, Events und
//  Achievements gleichermassen.
//
//  Abhaengigkeiten
//  Darf importieren: GameCore, GameContent
//  Darf niemals ein anderes System importieren. Systemuebergreifende Wirkung
//  entsteht ausschliesslich ueber Events (siehe docs/02-technische-architektur.md).
//
//  Stand: FactProvider und ConditionEvaluator inkl. unmetChecks sind da (Phase 4).
//  Offen: Balancing-Formeln und -Kurven (Phase 6).
