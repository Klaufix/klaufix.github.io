//  CreatureRenderer
//
//  Verantwortung
//  Darstellung aus AppearanceDescriptor ueber ein AppearanceProvider-Protokoll. MVP: programmatische Vektorformen. Spaeterer Asset-Provider ersetzt genau dieses Modul (ADR-005).
//
//  Abhaengigkeiten
//  Darf importieren: DesignSystem, GameCore
//  Darf niemals ein anderes System importieren. Systemuebergreifende Wirkung
//  entsteht ausschliesslich ueber Events (siehe docs/02-technische-architektur.md).
//
//  Wird mit Inhalt gefuellt in Phase 5.
