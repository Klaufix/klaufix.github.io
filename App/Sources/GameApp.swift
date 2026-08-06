import AppComposition
import SwiftUI

/// Das App-Ziel ist bewusst duenn: Es startet die Szene und sonst nichts.
/// Alles Weitere liegt in Modulen, die auch ohne Xcode gebaut und getestet
/// werden koennen.
@main
struct GameApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
