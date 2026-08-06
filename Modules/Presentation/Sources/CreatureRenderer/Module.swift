//  CreatureRenderer
//
//  Verantwortung
//  Darstellung aus AppearanceDescriptor ueber ein AppearanceProvider-Protokoll. MVP:
//  programmatische Vektorformen. Spaeterer Asset-Provider ersetzt genau dieses Modul
//  (ADR-005).
//
//  Abhaengigkeiten
//  Darf importieren: DesignSystem, GameCore
//  Darf niemals ein anderes System importieren. Systemuebergreifende Wirkung
//  entsteht ausschliesslich ueber Events (siehe docs/02-technische-architektur.md).
//
//  Stand: Deskriptor, Aufloesung aus Content, Stimmungen, stabile
//  Farbableitung und CreatureView sind da (Phase 5).
//  Offen: Kleidungs-Ebenen zeichnen, Pflegegesten (Phase 6).
