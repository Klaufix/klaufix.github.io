import Foundation

public enum ContentSource {

    /// Lädt den ausgelieferten Content, mit Rückfall auf das Fixture.
    ///
    /// Der Rückfall ist kein Schönwetter-Komfort: Eine App, die beim Fehlen
    /// einer Ressource gar nicht erst startet, ist im Zweifel schlechter als
    /// eine, die mit weniger Inhalt startet. Der Aufrufer erfährt über
    /// `usedFallback`, was passiert ist, und kann es melden.
    public static func load(from url: URL?) -> (bundle: ContentBundle, usedFallback: Bool) {
        guard let url else { return (.sample, true) }

        do {
            return (try ContentLoader().load(from: [url]), false)
        } catch {
            return (.sample, true)
        }
    }
}
