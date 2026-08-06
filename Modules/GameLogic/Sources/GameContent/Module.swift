//  GameContent
//
//  Verantwortung
//  Content-Schema, Laden und Zusammenfuehren von Content-Quellen, Referenz-Validierung,
//  Schema-Versionierung.
//
//  Abhaengigkeiten
//  Darf importieren: GameCore
//  Darf niemals ein anderes System importieren. Systemuebergreifende Wirkung
//  entsteht ausschliesslich ueber Events (siehe docs/02-technische-architektur.md).
//
//  Stand: Schema, Loader mit mehreren Quellen und Validator sind da (Phase 4).
//  Offen: Migration alter Schema-Versionen, sobald es eine zweite gibt.
