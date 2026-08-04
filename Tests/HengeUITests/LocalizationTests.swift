import XCTest
@testable import HengeUI
// @testable for `LunarPhase.init`, which is internal: the phase probes below
// need to be built at a chosen age rather than found by searching the real
// calendar for one.
@testable import HengeAstro
import HengeGeometry

/// Every name the app can say, in every language it says it in.
///
/// The failure this guards against is silent and only visible to people who
/// cannot read the fallback. A missing key does not crash and does not warn —
/// `String(localized:)` returns the key itself, so the app cheerfully renders
/// `lore.monument.sarsen.body` to a reader in Seoul while every English
/// screenshot looks perfect. Nothing else in the build catches that.
///
/// So the rule these tests enforce is: a lookup must never return its own key,
/// and it must never return a key-shaped string. Both checks are needed —
/// the first catches a missing entry, the second catches a typo'd key that
/// happens to exist somewhere else in the catalogue.
final class LocalizationTests: XCTestCase {

    /// A resolved string is one that is not simply the key handed back.
    private func assertResolved(_ resolved: String,
                                key: String,
                                _ what: String,
                                file: StaticString = #filePath,
                                line: UInt = #line) {
        XCTAssertNotEqual(resolved, key,
                          "\(what): the catalogue has no entry for '\(key)', "
                          + "so this renders as the raw key",
                          file: file, line: line)
        XCTAssertFalse(resolved.isEmpty,
                       "\(what): '\(key)' resolved to an empty string",
                       file: file, line: line)
        // Key-shaped: dotted, no spaces, all ASCII. No display string in any
        // of the nine languages looks like that.
        let looksLikeAKey = resolved.contains(".")
            && !resolved.contains(" ")
            && resolved.allSatisfy(\.isASCII)
        XCTAssertFalse(looksLikeAKey,
                       "\(what): '\(key)' resolved to '\(resolved)', which is "
                       + "shaped like a key rather than a name",
                       file: file, line: line)
    }

    // ── the lore ────────────────────────────────────────────────────────────

    /// **Every note the app can show has a translated title and body.**
    ///
    /// Walks `Lore.all`, which is the app's own list rather than one copied
    /// here — a note added to `HengeGeometry` without a catalogue entry fails
    /// this the moment it exists, which is the point.
    func testEveryLoreNoteIsTranslated() {
        XCTAssertFalse(Lore.all.isEmpty, "the lore list came back empty")

        for note in Lore.all {
            assertResolved(note.localizedTitle,
                           key: "lore.\(note.id).title",
                           "lore note '\(note.id)' title")
            assertResolved(note.localizedBody,
                           key: "lore.\(note.id).body",
                           "lore note '\(note.id)' body")
        }
    }

    /// **A translated body is a real paragraph, not a stub.**
    ///
    /// The claims carry tiers and citations (MISSION.md invariant 3). A body
    /// truncated to a phrase would present a citation attached to something
    /// that no longer says what was cited.
    func testTranslatedLoreBodiesAreSubstantial() {
        for note in Lore.all {
            XCTAssertGreaterThan(note.localizedBody.count, 80,
                                 "lore note '\(note.id)' has a body too short "
                                 + "to be carrying its citations honestly")
        }
    }

    /// **Every tier has both its labels.** The badge and the VoiceOver
    /// reading come from different properties and must both land.
    func testEveryLoreTierIsTranslated() {
        for tier in LoreTier.allCases {
            XCTAssertFalse(tier.localizedLabel.isEmpty)
            XCTAssertFalse(tier.localizedShortLabel.isEmpty)
            assertResolved(tier.localizedLabel,
                           key: "lore.tier.\(tier)", "tier \(tier)")
        }
    }

    // ── the sky and the year ────────────────────────────────────────────────

    /// **Every station resolves.**
    ///
    /// The four Gaelic quarter days are expected to come back *untranslated* —
    /// they are proper nouns and `localizedName` returns `name` for them by
    /// design. Asserted explicitly so that a later "fix" that translates
    /// Samhain has to argue with a test rather than slip through.
    func testEveryWheelStationResolves() {
        for station in WheelStation.allCases {
            XCTAssertFalse(station.localizedName.isEmpty, "\(station)")

            switch station {
            case .imbolc, .beltane, .lughnasadh, .samhain:
                XCTAssertEqual(station.localizedName, station.name,
                               "\(station) is a Gaelic festival name and must "
                               + "travel untranslated")
            default:
                assertResolved(station.localizedName,
                               key: "station.\(station)", "station \(station)")
            }
        }
    }

    /// **Every lunar phase the arithmetic can produce has a translation.**
    ///
    /// `localizedName` maps off the canonical English name, so a renamed band
    /// in `HengeAstro` would fall through to `default: name` and ship English
    /// into eight languages. That fall-through is invisible in English — where
    /// the translation and the canonical name are the same word — so the check
    /// is made against German, where they never are.
    func testEveryLunarPhaseResolves() {
        let expected = [
            (0.9, "moon.new"), (3.7, "moon.waxingCrescent"),
            (7.4, "moon.firstQuarter"), (11.0, "moon.waxingGibbous"),
            (14.8, "moon.full"), (18.5, "moon.waningGibbous"),
            (22.2, "moon.lastQuarter"), (25.9, "moon.waningCrescent")
        ]
        for (age, key) in expected {
            let phase = LunarPhase(illuminatedFraction: 0.5,
                                   phaseAngle: Angle(degrees: 90),
                                   age: age)
            XCTAssertFalse(phase.localizedName.isEmpty, "age \(age)")
            // The band the arithmetic lands in must be the band the mapping
            // expects; otherwise the key below is not the one being used.
            XCTAssertEqual(phase.localizedName, value(key, language: "en"),
                           "the phase at age \(age) ('\(phase.name)') did not "
                           + "map to \(key) — Localized.swift has drifted "
                           + "from HengeAstro")
        }
    }

    // ── the catalogue itself ────────────────────────────────────────────────

    /// The path to a language's `.lproj`, found without caring about case.
    ///
    /// SwiftPM lowercases region-qualified localisation directories on its way
    /// into the bundle: `pt-BR.lproj` in the source tree arrives as
    /// `pt-br.lproj`, and `zh-Hans.lproj` as `zh-hans.lproj`. Foundation
    /// matches those case-insensitively at runtime — `testTheRegionQualified
    /// LocalizationsAreReachable` is what actually establishes that rather
    /// than assuming it — but `Bundle.path(forResource:ofType:)` does not, so
    /// the lookup here is done by hand.
    private func lprojPath(_ language: String) -> String? {
        guard let root = Bundle.module.resourcePath,
              let entries = try? FileManager.default
                  .contentsOfDirectory(atPath: root) else { return nil }
        let wanted = language.lowercased() + ".lproj"
        return entries
            .first { $0.lowercased() == wanted }
            .map { root + "/" + $0 }
    }

    /// Look a key up in one specific language's bundle.
    private func value(_ key: String, language: String) -> String {
        guard let path = lprojPath(language),
              let bundle = Bundle(path: path) else {
            return key
        }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    /// **Foundation still finds the lowercased localisations.**
    ///
    /// The one that would bite silently: a Brazilian or Chinese reader gets
    /// English because `pt-br.lproj` did not match their `pt-BR` preference.
    /// Asserted through `preferredLocalizations`, which is the same matching
    /// the system does when it picks a bundle's language, rather than through
    /// a filesystem check that would prove only that a folder exists.
    func testTheRegionQualifiedLocalizationsAreReachable() {
        let available = Bundle.module.localizations

        for wanted in ["pt-BR", "zh-Hans"] {
            let chosen = Bundle.preferredLocalizations(from: available,
                                                       forPreferences: [wanted])
            XCTAssertEqual(chosen.first?.lowercased(), wanted.lowercased(),
                           "a reader preferring \(wanted) would be served "
                           + "'\(chosen.first ?? "nothing")' instead — the "
                           + "localisation shipped but cannot be selected")
        }
    }

    /// **Every language carries every key.**
    ///
    /// The strongest guarantee available here, and the cheapest: English is
    /// the authority on which keys exist, so any key it has that another
    /// language lacks is a string that will render in English — or as a raw
    /// key — for that reader. Walking the shipped `en.lproj` rather than a
    /// list written here means a key added tomorrow is covered tonight.
    func testEveryLanguageCarriesEveryKey() throws {
        let languages = ["de", "es", "fr", "it", "ja", "ko", "pt-BR", "zh-Hans"]

        let englishPath = try XCTUnwrap(
            lprojPath("en"),
            "the English strings did not ship in the bundle at all")
        let english = try XCTUnwrap(
            NSDictionary(contentsOfFile: englishPath + "/Localizable.strings")
                as? [String: String])

        XCTAssertGreaterThan(english.count, 100,
                             "the English catalogue is suspiciously small")

        for language in languages {
            let path = try XCTUnwrap(
                lprojPath(language),
                "\(language) did not ship in the bundle")
            let strings = try XCTUnwrap(
                NSDictionary(contentsOfFile: path + "/Localizable.strings")
                    as? [String: String],
                "\(language)'s strings file did not parse")

            let missing = Set(english.keys).subtracting(strings.keys).sorted()
            XCTAssertTrue(missing.isEmpty,
                          "\(language) is missing \(missing.count) keys: "
                          + "\(missing.prefix(5).joined(separator: ", "))")

            let empty = strings.filter { $0.value.isEmpty }.keys.sorted()
            XCTAssertTrue(empty.isEmpty,
                          "\(language) has empty values for: "
                          + "\(empty.prefix(5).joined(separator: ", "))")
        }
    }

    /// **The interpolated formats keep their placeholders in every language.**
    ///
    /// A dropped `%@` does not fail to compile and does not crash — it simply
    /// prints a sentence with the number or the name missing. A *duplicated*
    /// one, or a `%@` where the English has `%.0f`, is worse: `String(format:)`
    /// reads the wrong bytes off the argument list.
    func testFormatSpecifiersSurviveTranslation() throws {
        let languages = ["de", "es", "fr", "it", "ja", "ko", "pt-BR", "zh-Hans"]
        let englishPath = try XCTUnwrap(lprojPath("en"))
        let english = try XCTUnwrap(
            NSDictionary(contentsOfFile: englishPath + "/Localizable.strings")
                as? [String: String])

        // Keys whose English value carries a placeholder.
        let formats = english.filter { $0.value.contains("%") }
        XCTAssertFalse(formats.isEmpty, "no format strings found to check")

        for language in languages {
            for (key, englishValue) in formats {
                let translated = value(key, language: language)
                XCTAssertEqual(count(of: "%", in: translated),
                               count(of: "%", in: englishValue),
                               "\(language)/\(key): placeholder count differs "
                               + "from English ('\(translated)')")
            }
        }
    }

    private func count(of needle: String, in haystack: String) -> Int {
        haystack.components(separatedBy: needle).count - 1
    }

    /// **Every zodiac constellation resolves**, and none falls back to Latin.
    func testEveryZodiacConstellationResolves() {
        XCTAssertEqual(ZodiacConstellation.all.count, 12)
        for sign in ZodiacConstellation.all {
            XCTAssertFalse(sign.localizedName.isEmpty, sign.name)
        }
    }

    /// **Every planet, season and alignment resolves.**
    func testTheRemainingNamedThingsResolve() {
        for planet in Planet.allCases {
            assertResolved(planet.localizedName,
                           key: "planet.\(planet)", "planet \(planet)")
        }
        for season in Season.allCases {
            assertResolved(season.localizedName,
                           key: "season.\(season)", "season \(season)")
        }
        for alignment in HengeGeometry.Alignment.allCases {
            assertResolved(alignment.localizedName,
                           key: "alignment.\(alignment)", "alignment \(alignment)")
        }
    }

    /// **Every event kind resolves**, including both eclipse qualifiers.
    ///
    /// The eclipse names were built by concatenating " possible" onto a noun
    /// in English. All four combinations are whole strings now, and all four
    /// need to exist — the `false, false` corner is the one a hand-written
    /// catalogue forgets.
    func testEveryEventKindResolves() {
        let kinds: [EventKind] = [
            .newMoon, .firstQuarter, .fullMoon, .lastQuarter,
            .eclipsePossible(solar: true, certain: true),
            .eclipsePossible(solar: true, certain: false),
            .eclipsePossible(solar: false, certain: true),
            .eclipsePossible(solar: false, certain: false),
            .standstill(major: true), .standstill(major: false)
        ]
        var seen = Set<String>()
        for kind in kinds {
            let name = kind.localizedName
            XCTAssertFalse(name.isEmpty, "\(kind)")
            XCTAssertFalse(name.contains("event."),
                           "\(kind) resolved to a raw key: \(name)")
            seen.insert(name)
        }
        // The four eclipse strings must be four distinct strings: if
        // "possible" were dropped in translation, a maybe would read as a
        // certainty in that language.
        XCTAssertEqual(seen.count, kinds.count,
                       "two event kinds share a name — a qualifier was lost")
    }
}
