import SwiftUI

/// Einstiegspunkt der Oberflaeche.
///
/// AppComposition ist die einzige Stelle, an der Feature-Module, Engine,
/// Persistenz und Sync zusammengesteckt werden. Deshalb steht hier die
/// Wurzelansicht - und ausdruecklich keine Spiellogik.
///
/// Der aktuelle Inhalt ist ein Platzhalter und wird in Phase 6 durch die
/// Navigation zwischen den Feature-Modulen ersetzt.
public struct RootView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            Text("Gerüst steht")
                .font(.largeTitle.bold())

            Text("Die Oberfläche entsteht ab Phase 5.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    RootView()
}
