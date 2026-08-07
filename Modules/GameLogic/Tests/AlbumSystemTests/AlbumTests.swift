import Foundation
import GameContent
import GameCore
import Testing

@testable import AlbumSystem

private let day = Date(timeIntervalSince1970: 1_750_000_000)

@Suite("Sammelalbum")
struct AlbumTests {

    @Test("Eine Entdeckung legt einen Eintrag an")
    func firstDiscovery() {
        var album = AlbumState()

        album.apply(.discovered(species: "sprout_youngling", variant: .standard, at: day))

        #expect(album.discoveredCount == 1)
        #expect(album.hasDiscovered("sprout_youngling"))
        #expect(album.entry(for: "sprout_youngling")?.hasSeen(.standard) == true)
    }

    @Test("Eine zweite Variante ergänzt denselben Eintrag")
    func variantsAccumulate() {
        var album = AlbumState()

        album.apply(.discovered(species: "sprout_youngling", variant: .standard, at: day))
        album.apply(.discovered(species: "sprout_youngling", variant: .shimmer, at: day))

        #expect(album.discoveredCount == 1)
        let entry = album.entry(for: "sprout_youngling")
        #expect(entry?.variants.count == 2)
        #expect(entry?.timesOwned == 2)
    }

    @Test("Das früheste Datum bleibt stehen")
    func earliestDateWins() {
        var album = AlbumState()
        let later = day.addingTimeInterval(86_400)

        album.apply(.discovered(species: "sprout_youngling", variant: .standard, at: later))
        album.apply(.discovered(species: "sprout_youngling", variant: .shimmer, at: day))

        // „Erstmals gesehen" muss auch dann stimmen, wenn Ereignisse aus zwei
        // Geräten in beliebiger Reihenfolge eintreffen.
        #expect(album.entry(for: "sprout_youngling")?.firstSeenAt == day)
    }

    @Test("Ein Eintrag verschwindet nie wieder")
    func entriesAreNeverLost() {
        var album = AlbumState()
        album.apply(.discovered(species: "sprout_youngling", variant: .standard, at: day))

        // Es gibt bewusst keine Methode zum Entfernen. Das Album speichert
        // Entdeckungen, nie Verluste.
        album.apply(.discovered(species: "sprout_adult_bloom", variant: .standard, at: day))

        #expect(album.hasDiscovered("sprout_youngling"))
        #expect(album.discoveredCount == 2)
    }

    @Test("Der Spielstand überlebt eine Kodier-Runde")
    func survivesRoundTrip() throws {
        var album = AlbumState()
        album.apply(.discovered(species: "sprout_youngling", variant: .shimmer, at: day))

        let decoded = try JSONDecoder().decode(
            AlbumState.self, from: JSONEncoder().encode(album)
        )

        #expect(decoded == album)
    }
}

@Suite("Meilensteine")
struct MilestoneTests {

    @Test("Der erste Meilenstein liegt bei einer einzigen Art")
    func firstMilestoneIsEarly() {
        // Die erste Belohnung soll kommen, bevor jemand sich fragt, wofür er
        // eigentlich sammelt.
        #expect(AlbumSystem.reachedMilestone(discovered: 1) == 1)
    }

    @Test("Zwischenzahlen sind keine Meilensteine")
    func nonMilestonesAreIgnored() {
        #expect(AlbumSystem.reachedMilestone(discovered: 2) == nil)
        #expect(AlbumSystem.reachedMilestone(discovered: 4) == nil)
    }

    @Test("Der nächste Meilenstein ist ablesbar")
    func nextMilestoneIsKnown() {
        #expect(AlbumSystem.nextMilestone(after: 1) == 3)
        #expect(AlbumSystem.nextMilestone(after: 35) == 50)
        #expect(AlbumSystem.nextMilestone(after: 50) == nil)
    }

    @Test("Unentdeckte Arten zeigen ihren Fundort statt eines leeren Feldes")
    func teaserShowsHabitat() {
        let species = ContentBundle.sample.species["sprout_youngling"]!

        #expect(AlbumSystem.teaser(for: species) == "meadow")
    }
}
