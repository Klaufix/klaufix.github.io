import Foundation
import GameCore

/// Der Umschlag um einen Spielstand.
///
/// Der Zustand liegt als **lesbares JSON** in der Datei, nicht als undurchsichtiger
/// Blob. Das ist Absicht: Wer einen kaputten Spielstand untersuchen muss, soll ihn
/// öffnen können — auch in zwei Jahren, auch ohne dieses Projekt zur Hand.
public struct SaveEnvelope: Sendable, Hashable {
    public let saveVersion: Int
    public let savedAt: Date
    /// Prüfsumme über den kanonisch serialisierten Zustand.
    public let checksum: String

    public init(saveVersion: Int, savedAt: Date, checksum: String) {
        self.saveVersion = saveVersion
        self.savedAt = savedAt
        self.checksum = checksum
    }
}

public enum SaveError: Error, CustomStringConvertible, Sendable {
    case unreadable(String)
    case malformed(String)
    case checksumMismatch
    case versionTooNew(found: Int, supported: Int)
    case noSaveFound

    public var description: String {
        switch self {
        case .unreadable(let detail): "Spielstand nicht lesbar: \(detail)"
        case .malformed(let detail): "Spielstand beschädigt: \(detail)"
        case .checksumMismatch: "Prüfsumme stimmt nicht — Datei unvollständig geschrieben?"
        case .versionTooNew(let found, let supported):
            "Spielstand ist Version \(found), unterstützt wird bis \(supported). "
                + "Vermutlich wurde er mit einer neueren App-Version erzeugt."
        case .noSaveFound: "Kein Spielstand vorhanden."
        }
    }
}

/// Prüfsumme über Bytes.
///
/// FNV-1a, nicht kryptografisch — und ausdrücklich **kein Manipulationsschutz**.
/// Wer die Datei absichtlich ändert, kann die Prüfsumme neu berechnen. Ihr Zweck
/// ist ein anderer und bescheidenerer: einen halb geschriebenen oder auf dem
/// Datenträger beschädigten Spielstand erkennen, bevor er als gültig durchgeht.
///
/// Gegen Zeitmanipulation schützt der `TimeCursor` (Zeit läuft nie rückwärts,
/// Sprünge sind gedeckelt) — und auch der bestraft niemanden, er ignoriert nur.
public enum Checksum {
    public static func of(_ data: Data) -> String {
        var result: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in data {
            result ^= UInt64(byte)
            result = result &* 0x0000_0100_0000_01B3
        }
        return String(result, radix: 16)
    }
}
