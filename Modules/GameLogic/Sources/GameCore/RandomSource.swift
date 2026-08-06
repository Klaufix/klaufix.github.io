/// Deterministischer Zufallsgenerator (SplitMix64).
///
/// Nirgends im Projekt darf `Int.random(in:)` o. ae. verwendet werden: Ohne
/// festen Startwert waeren Tests nicht reproduzierbar, und der Spieler koennte
/// durch Neustart der App so lange wuerfeln, bis das Ergebnis passt.
public struct SeededRandom: RandomNumberGenerator, Sendable, Hashable, Codable {
    public private(set) var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Getrennte Zufallsstroeme.
///
/// Jeder Bereich zieht aus seinem eigenen Strom. Sonst wuerde ein zusaetzlicher
/// Wurf beim Ausflug die naechste Zuchtvariante verschieben - und ein Test, der
/// nur die Zucht betrifft, braeche, sobald jemand die Beutetabelle anfasst.
public enum RandomStream: String, Sendable, Codable, CaseIterable {
    case breeding
    case expedition
    case loot
    case spawn
    case weather
    case quests
    case battle
}

/// Haelt Startwert und Zaehlerstaende. Wird im Spielstand gesichert, damit ein
/// Neustart der App exakt dieselbe Folge fortsetzt.
public struct RandomSource: Sendable, Hashable, Codable {
    public let seed: UInt64
    private var counters: [String: UInt64]

    public init(seed: UInt64) {
        self.seed = seed
        self.counters = [:]
    }

    /// Liefert einen Generator fuer den naechsten Wurf des Stroms und erhoeht
    /// dessen Zaehler. Zweimaliges Ziehen ergibt zwei verschiedene Ergebnisse -
    /// dieselbe Zaehlerposition ergibt jedoch immer dasselbe.
    public mutating func generator(for stream: RandomStream) -> SeededRandom {
        let counter = counters[stream.rawValue, default: 0]
        counters[stream.rawValue] = counter &+ 1
        return SeededRandom(
            seed: seed
                ^ RandomSource.hash(stream.rawValue)
                ^ (counter &* 0x9E37_79B9_7F4A_7C15)
        )
    }

    public func drawCount(for stream: RandomStream) -> UInt64 {
        counters[stream.rawValue, default: 0]
    }

    /// FNV-1a. Nicht kryptografisch - es geht nur darum, Stroeme auseinanderzuhalten.
    private static func hash(_ text: String) -> UInt64 {
        var result: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in text.utf8 {
            result ^= UInt64(byte)
            result = result &* 0x0000_0100_0000_01B3
        }
        return result
    }
}
