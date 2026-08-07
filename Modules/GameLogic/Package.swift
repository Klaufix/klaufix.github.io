// swift-tools-version: 6.0

import PackageDescription

// Die zwoelf Spielsysteme. Sie kennen einander nicht: jedes haengt ausschliesslich
// von der Kern-Schicht ab. Diese Regel steht nicht in einem Dokument, sondern hier
// im Paketgraphen - ein Verstoss ist ein Compilerfehler.
let systems = [
    "CreatureSystem",
    "InventorySystem",
    "WardrobeSystem",
    "ClimateSystem",
    "ExpeditionSystem",
    "BattleSystem",
    "BreedingSystem",
    "QuestSystem",
    "StorySystem",
    "AlbumSystem",
    "ProgressionSystem",
    "EconomySystem",
]

let kernel: [Target.Dependency] = ["GameCore", "GameContent", "GameRules"]
let allSystems: [Target.Dependency] = systems.map { .target(name: $0) }

var targets: [Target] = [
    .target(name: "GameCore"),
    .target(name: "GameContent", dependencies: ["GameCore"]),
    .target(name: "GameRules", dependencies: ["GameCore", "GameContent"]),
]

targets += systems.map { Target.target(name: $0, dependencies: kernel) }

targets += [
    // Aggregierter Zustand und Engine duerfen die Systeme kennen - umgekehrt nie.
    .target(name: "GameState", dependencies: kernel + allSystems),
    .target(
        name: "GameEngine",
        dependencies: [Target.Dependency.target(name: "GameState")] + kernel + allSystems
    ),

    // Infrastruktur
    .target(name: "Persistence", dependencies: ["GameCore", "GameState"]),
    .target(name: "SyncCore", dependencies: ["GameCore"]),

    // Werkzeug: prueft das Content-Bundle in der CI, bevor Inhalte im Spiel landen.
    .executableTarget(name: "ContentValidator", dependencies: ["GameContent"]),

    // Testziele fuehren jede Abhaengigkeit auf, die sie importieren - auch die
    // ohnehin transitiv erreichbaren. Ein implizit mitgezogener Import ist
    // genau die Art von Kopplung, die dieser Paketgraph verhindern soll.
    .testTarget(name: "GameCoreTests", dependencies: ["GameCore"]),
    .testTarget(name: "GameContentTests", dependencies: ["GameContent", "GameCore"]),
    .testTarget(name: "GameRulesTests", dependencies: ["GameRules", "GameCore"]),
    .testTarget(
        name: "CreatureSystemTests",
        dependencies: ["CreatureSystem", "GameCore", "GameContent"]
    ),
    .testTarget(
        name: "ClimateSystemTests",
        dependencies: ["ClimateSystem", "GameCore", "GameContent"]
    ),
    .testTarget(
        name: "GameEngineTests",
        dependencies: [
            "GameEngine", "GameCore", "GameContent", "CreatureSystem", "ClimateSystem",
            "BreedingSystem", "AlbumSystem",
        ]
    ),
    .testTarget(
        name: "BreedingSystemTests",
        dependencies: ["BreedingSystem", "GameCore", "GameContent"]
    ),
    .testTarget(
        name: "AlbumSystemTests",
        dependencies: ["AlbumSystem", "GameCore", "GameContent"]
    ),
    .testTarget(
        name: "PersistenceTests",
        dependencies: ["Persistence", "GameCore", "GameState", "CreatureSystem"]
    ),
    .testTarget(name: "SyncCoreTests", dependencies: ["SyncCore", "GameCore"]),
]

let package = Package(
    name: "GameLogic",
    // Plattformangaben richten sich an Apple-Konsumenten. Die Module selbst sind
    // UI-frei und bauen deshalb auch unter Linux - genau das nutzt die CI.
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(
            name: "GameLogic",
            targets: [
                "GameCore", "GameContent", "GameRules",
                "GameState", "GameEngine",
                "Persistence", "SyncCore",
            ] + systems
        )
    ],
    targets: targets
)
