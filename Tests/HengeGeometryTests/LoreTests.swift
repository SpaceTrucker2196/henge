import XCTest
@testable import HengeGeometry
import HengeAstro

/// MISSION.md invariant 3, made enforceable.
///
/// The rule is that nothing the app *says* ships untiered or uncited. The type
/// makes tier and citations non-optional; these tests close the gaps the type
/// cannot — an empty citation list, a blank source, a duplicate identifier.
final class LoreTests: XCTestCase {

    func testNothingShipsUncited() {
        for note in Lore.all {
            XCTAssertFalse(note.citations.isEmpty, "\(note.id) has no source")
            for citation in note.citations {
                XCTAssertFalse(citation.source.trimmingCharacters(in: .whitespaces).isEmpty,
                               "\(note.id) has a blank source")
            }
        }
    }

    func testEveryNoteHasSubstance() {
        for note in Lore.all {
            XCTAssertFalse(note.title.isEmpty, note.id)
            XCTAssertGreaterThan(note.body.count, 80, "\(note.id) is too thin to be worth saying")
        }
    }

    func testIdentifiersAreUnique() {
        let ids = Lore.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "duplicate lore identifier")
    }

    /// Notes shared between stations must genuinely be the same note. If two
    /// stations ever return different text under one identifier, `all` would
    /// silently drop one of them and the tiering test would only see the first.
    func testSharedIdentifiersCarryIdenticalNotes() {
        var byID: [String: LoreNote] = [:]
        for station in WheelStation.allCases {
            let note = Lore.note(for: station)
            if let existing = byID[note.id] {
                XCTAssertEqual(existing, note, "\(note.id) differs between stations")
            }
            byID[note.id] = note
        }
    }

    /// Every station of the year has something to say, and the tiering is the
    /// point: the solstices are established, everything else is not.
    func testTheWheelIsTieredHonestly() {
        for station in WheelStation.allCases {
            let note = Lore.note(for: station)
            switch station {
            case .juneSolstice, .decemberSolstice:
                XCTAssertEqual(note.tier, .established, station.name)
            default:
                XCTAssertEqual(note.tier, .modernTradition,
                               "\(station.name) is not an archaeological claim about Stonehenge")
            }
        }
    }

    /// The one thing this project must never blur.
    func testTheDruidNoteIsMarkedAsModernTradition() throws {
        let note = try XCTUnwrap(Lore.monument.first { $0.id == "monument.druids" })
        XCTAssertEqual(note.tier, .modernTradition)
        XCTAssertTrue(note.body.contains("Iron Age"))
    }

    /// All three tiers are actually in use. A tier nobody reaches for is a sign
    /// the content has quietly flattened into one voice.
    func testAllThreeTiersAreRepresented() {
        let tiers = Set(Lore.all.map(\.tier))
        XCTAssertEqual(tiers, Set(LoreTier.allCases))
    }
}
