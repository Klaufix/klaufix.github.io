// swift-tools-version: 6.0

import PackageDescription

// Feature-Module sind pro Bildschirmbereich geschnitten. Sie kennen einander nicht
// und sprechen ausschliesslich mit der GameEngine. Zusammengesteckt werden sie an
// genau einer Stelle: in AppComposition.
let features = [
    "FeatureHome",
    "FeatureAlbum",
    "FeatureExpedition",
    "FeatureBattle",
    "FeatureWardrobe",
    "FeatureBreeding",
    "FeatureQuests",
    "FeatureStory",
    "FeatureSettings",
]

let logic: Target.Dependency = .product(name: "GameLogic", package: "GameLogic")
let featureBase: [Target.Dependency] = ["DesignSystem", "CreatureRenderer", logic]

var targets: [Target] = [
    .target(name: "DesignSystem"),
    .target(name: "CreatureRenderer", dependencies: ["DesignSystem", logic]),
]

targets += features.map { Target.target(name: $0, dependencies: featureBase) }

targets += [
    .target(
        name: "AppComposition",
        dependencies: features.map { Target.Dependency.target(name: $0) }
            + [
                Target.Dependency.target(name: "DesignSystem"),
                Target.Dependency.target(name: "CreatureRenderer"),
                logic,
            ]
    ),

    // Die SwiftUI-freien Teile des Renderers - Aufloesung aus Content,
    // Stimmung, Farbableitung - sind hier geprueft. Das Zeichnen selbst
    // pruefen Menschen.
    .testTarget(name: "CreatureRendererTests", dependencies: ["CreatureRenderer", logic]),
]

let package = Package(
    name: "Presentation",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "AppComposition", targets: ["AppComposition"])
    ],
    dependencies: [
        .package(path: "../GameLogic")
    ],
    targets: targets
)
