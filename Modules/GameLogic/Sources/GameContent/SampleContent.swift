import GameCore

extension ContentBundle {

    /// Ein kleines, im Code definiertes Bundle.
    ///
    /// Zweck: Vorschauen, Tests und der Entwicklungs-Build der App. Das
    /// Ausliefern des echten Content-Verzeichnisses als App-Ressource kommt in
    /// Phase 8 zusammen mit der Persistenz — bis dahin wäre die App sonst nicht
    /// startbar, und ein nicht startbarer Build ist schwer zu beurteilen.
    ///
    /// Die Werte spiegeln `Content/` bewusst nur grob. Wer Balancing prüfen
    /// will, nimmt den echten Loader.
    public static var sample: ContentBundle {
        ContentBundle(
            species: [sampleSprout, sampleBloom],
            evolutions: [sampleEvolution],
            items: [sampleBerry, sampleTea],
            cosmetics: [],
            elementChart: sampleChart,
            balancing: sampleBalancing,
            climate: sampleClimate
        )
    }

    private static var sampleSprout: SpeciesDefinition {
        SpeciesDefinition(
            id: "sprout_youngling",
            schemaVersion: ContentSchema.current,
            nameKey: "species.sprout_youngling.name",
            descriptionKey: "species.sprout_youngling.description",
            element: "leaf",
            rarity: .common,
            growthStage: .youngling,
            baseStats: BaseStats(vitality: 24, power: 12, resilience: 16, speed: 14),
            preferences: SpeciesPreferences(
                favoriteFoodTags: ["sweet", "fruit"],
                dislikedFoodTags: ["bitter"],
                favoriteWeather: ["rain"],
                sleepsFrom: 21,
                sleepsUntil: 6
            ),
            appearance: AppearanceDefinition(
                silhouette: "round_sprout",
                parts: ["leaf_crest"],
                defaultPalette: "sprout_green",
                variantPalettes: ["shimmer": "sprout_gold"]
            ),
            habitats: ["meadow"],
            retired: nil
        )
    }

    private static var sampleBloom: SpeciesDefinition {
        SpeciesDefinition(
            id: "sprout_adult_bloom",
            schemaVersion: ContentSchema.current,
            nameKey: "species.sprout_adult_bloom.name",
            descriptionKey: "species.sprout_adult_bloom.description",
            element: "leaf",
            rarity: .common,
            growthStage: .adult,
            baseStats: BaseStats(vitality: 38, power: 20, resilience: 28, speed: 22),
            preferences: SpeciesPreferences(
                favoriteFoodTags: ["sweet", "flower"],
                favoriteWeather: ["sun"],
                sleepsFrom: 22,
                sleepsUntil: 7
            ),
            appearance: AppearanceDefinition(
                silhouette: "round_sprout",
                parts: ["bloom_crown"],
                defaultPalette: "bloom_pink",
                variantPalettes: nil
            ),
            habitats: ["meadow"],
            retired: nil
        )
    }

    /// Ein friedlicher Entwicklungsweg: Stufe und Freundschaft genügen — kein
    /// Kampf nötig (Design-Säule 4).
    private static var sampleEvolution: EvolutionDefinition {
        EvolutionDefinition(
            id: "evo_sprout_youngling",
            schemaVersion: ContentSchema.current,
            from: "sprout_youngling",
            branches: [
                EvolutionBranch(
                    to: "sprout_adult_bloom",
                    requires: .all([
                        .fact(.level, .greaterOrEqual, .number(5)),
                        .fact(.friendship, .greaterOrEqual, .number(20)),
                    ]),
                    hintKey: "evolution.hint.bloom",
                    peaceful: true
                )
            ]
        )
    }

    private static var sampleBerry: ItemDefinition {
        ItemDefinition(
            id: "sun_berry",
            schemaVersion: ContentSchema.current,
            nameKey: "item.sun_berry.name",
            kind: .food,
            tags: ["sweet", "fruit"],
            stackSize: 99,
            effects: [
                NeedEffect(need: .satiation, amount: 30),
                NeedEffect(need: .mood, amount: 5),
            ],
            retired: nil
        )
    }

    private static var sampleTea: ItemDefinition {
        ItemDefinition(
            id: "herb_tea",
            schemaVersion: ContentSchema.current,
            nameKey: "item.herb_tea.name",
            kind: .medicine,
            tags: ["bitter", "warm"],
            stackSize: 20,
            effects: [
                NeedEffect(need: .health, amount: 20),
                NeedEffect(need: .tiredness, amount: -10),
            ],
            retired: nil
        )
    }

    private static var sampleChart: ElementChart {
        ElementChart(
            schemaVersion: ContentSchema.current,
            elements: ["leaf", "wave", "ember", "stone", "wind", "shimmer", "night"],
            multipliers: [
                ElementMatchup(attacker: "leaf", defender: "wave", value: 1.5),
                ElementMatchup(attacker: "wave", defender: "ember", value: 1.5),
                ElementMatchup(attacker: "ember", defender: "leaf", value: 1.5),
            ]
        )
    }

    private static var sampleBalancing: BalancingDefinition {
        BalancingDefinition(
            schemaVersion: ContentSchema.current,
            satiationDecayPerHour: 4,
            satiationDecayPerHourAsleep: 1,
            energyDecayPerHour: 3,
            moodDecayPerHour: 2,
            offlineFloor: 25,
            dampeningHalfLifeHours: 8,
            reunionAfterHours: 24,
            reunionFriendshipBonus: 3,
            shimmerChanceWild: 0.0025,
            shimmerChanceBred: 0.0067,
            shimmerPityThreshold: 200
        )
    }

    private static var sampleClimate: ClimateDefinition {
        ClimateDefinition(
            schemaVersion: ContentSchema.current,
            slotHours: 6,
            weather: [
                WeatherDefinition(
                    id: "sun",
                    nameKey: "weather.sun",
                    weights: ["spring": 40, "summer": 55, "autumn": 28, "winter": 20]
                ),
                WeatherDefinition(
                    id: "rain",
                    nameKey: "weather.rain",
                    weights: ["spring": 32, "summer": 20, "autumn": 34, "winter": 18]
                ),
                WeatherDefinition(
                    id: "snow",
                    nameKey: "weather.snow",
                    weights: ["winter": 34]
                ),
            ]
        )
    }
}
