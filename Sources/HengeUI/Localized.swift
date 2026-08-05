import Foundation
import HengeAstro
import HengeGeometry
// For `Weather`, whose four states VoiceOver reads aloud as the toggle's value.
import HengeEngine

/// Display names, in the reader's language.
///
/// The mapping lives here rather than beside the types, and that is the
/// layering doing its job rather than an accident of where it was easiest to
/// type. Three reasons, each of which bit before this file existed:
///
/// 1. **`HengeAstro` is Foundation-only and provable without a screen.** Its
///    `name` properties are canonical English, and the oracle asserts against
///    them by literal — `SymbolTests` pins all eight phase names. Localising
///    in place would turn a passing test into a statement about the machine's
///    locale rather than about the sky.
/// 2. **Some of those names are identity.** `ZodiacConstellation.id` *is* its
///    name; `Lore.all` deduplicates notes by `id`. Translating a value that
///    something else keys on breaks the keying in exactly the languages
///    nobody on the team reads.
/// 3. **Keys should not move when prose does.** Everything below is keyed by
///    the enum case, so rewording an English label never orphans eight
///    translations.
///
/// Two categories are deliberately **not** translated, and both are editorial
/// decisions rather than omissions:
///
/// - **The Gaelic and Welsh festival names.** Imbolc, Beltane, Lughnasadh,
///   Samhain and the Alban names are what those festivals are *called*, not
///   descriptions of them. They travel untranslated the way Hanukkah does.
///   The descriptive stations around them — Midsummer, the equinoxes — are
///   ordinary words and are translated.
/// - **Citation source titles.** A bibliography is a set of pointers into the
///   literature, and a translated book title points nowhere. `LoreView` shows
///   them exactly as written; only the tier labels around them are localised.
enum L10n {

    /// Look a key up in this module's catalogue.
    ///
    /// Wrapped rather than called directly at ninety sites so that the bundle
    /// cannot be forgotten at one of them: `Bundle.main` holds none of these
    /// strings, and a missed `bundle:` argument fails by silently displaying
    /// the raw key — in the one language nobody testing the app reads.
    static func string(_ key: String.LocalizationValue) -> String {
        String(localized: key, bundle: .module)
    }

    /// Look up a key that is assembled at runtime.
    ///
    /// Separate from `string(_:)` because interpolating into a
    /// `String.LocalizationValue` does not build a key — it builds a *format*
    /// with the interpolated text as an argument, so `"lore.\(id).title"`
    /// would look up `lore.%@.title` and find nothing. Going through the
    /// `String` initialiser keeps the assembled text a key.
    static func dynamic(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), bundle: .module)
    }
}

// ── the wheel of the year ───────────────────────────────────────────────────

extension WheelStation {

    /// The station as the reader should see it.
    ///
    /// The four Gaelic quarter days keep their own names in every language.
    /// `Lore.note(for:)` is explicit that they are Gaelic festivals recorded
    /// in medieval Irish sources, and rendering Samhain as "November feast"
    /// in eight languages would quietly undo that note.
    var localizedName: String {
        switch self {
        case .imbolc, .beltane, .lughnasadh, .samhain:
            name
        case .marchEquinox:
            L10n.string("station.marchEquinox")
        case .juneSolstice:
            L10n.string("station.juneSolstice")
        case .septemberEquinox:
            L10n.string("station.septemberEquinox")
        case .decemberSolstice:
            L10n.string("station.decemberSolstice")
        }
    }
}

extension Season {

    var localizedName: String {
        switch self {
        case .marchEquinox: L10n.string("season.marchEquinox")
        case .juneSolstice: L10n.string("season.juneSolstice")
        case .septemberEquinox: L10n.string("season.septemberEquinox")
        case .decemberSolstice: L10n.string("season.decemberSolstice")
        }
    }
}

// ── the moon ────────────────────────────────────────────────────────────────

extension LunarPhase {

    /// Keyed off the canonical English name rather than off the age bands.
    ///
    /// Re-deriving the boundaries here would put the same eight thresholds in
    /// two files, and "compute, don't hardcode" applies hardest to numbers
    /// that already exist somewhere. `LocalizedNameTests` asserts that every
    /// phase the arithmetic can produce lands on a translation, so a renamed
    /// band fails the oracle rather than shipping an English word into
    /// Japanese.
    var localizedName: String {
        switch name {
        case "New": L10n.string("moon.new")
        case "Waxing crescent": L10n.string("moon.waxingCrescent")
        case "First quarter": L10n.string("moon.firstQuarter")
        case "Waxing gibbous": L10n.string("moon.waxingGibbous")
        case "Full": L10n.string("moon.full")
        case "Waning gibbous": L10n.string("moon.waningGibbous")
        case "Last quarter": L10n.string("moon.lastQuarter")
        case "Waning crescent": L10n.string("moon.waningCrescent")
        default: name
        }
    }
}

// ── events on the ribbon ────────────────────────────────────────────────────

extension EventKind {

    /// Built as four whole sentences rather than by gluing " possible" onto
    /// an eclipse. The English concatenation reads fine and translates
    /// terribly: the qualifier lands in a different place in half these
    /// languages, and in several it changes the noun's ending.
    var localizedName: String {
        switch self {
        case .station(let station):
            station.localizedName
        case .newMoon:
            L10n.string("event.newMoon")
        case .firstQuarter:
            L10n.string("event.firstQuarter")
        case .fullMoon:
            L10n.string("event.fullMoon")
        case .lastQuarter:
            L10n.string("event.lastQuarter")
        case .eclipsePossible(let solar, let certain):
            switch (solar, certain) {
            case (true, true): L10n.string("event.solarEclipse")
            case (true, false): L10n.string("event.solarEclipse.possible")
            case (false, true): L10n.string("event.lunarEclipse")
            case (false, false): L10n.string("event.lunarEclipse.possible")
            }
        case .standstill(let major):
            major ? L10n.string("event.standstill.major")
                  : L10n.string("event.standstill.minor")
        }
    }
}

// ── the sky ─────────────────────────────────────────────────────────────────

extension ZodiacConstellation {

    /// Keyed by the canonical Latin name, which is also this type's `id` —
    /// hence the mapping rather than a translated stored property.
    ///
    /// The constellations are translated because most of these languages have
    /// had their own words for them for centuries and the Latin reads as
    /// jargon in them. The *star* names do not follow: Sirius and Aldebaran
    /// are catalogue entries, and an app that cites Hipparcos should call
    /// them what Hipparcos does.
    var localizedName: String {
        switch name {
        case "Aries": L10n.string("zodiac.aries")
        case "Taurus": L10n.string("zodiac.taurus")
        case "Gemini": L10n.string("zodiac.gemini")
        case "Cancer": L10n.string("zodiac.cancer")
        case "Leo": L10n.string("zodiac.leo")
        case "Virgo": L10n.string("zodiac.virgo")
        case "Libra": L10n.string("zodiac.libra")
        case "Scorpius": L10n.string("zodiac.scorpius")
        case "Sagittarius": L10n.string("zodiac.sagittarius")
        case "Capricornus": L10n.string("zodiac.capricornus")
        case "Aquarius": L10n.string("zodiac.aquarius")
        case "Pisces": L10n.string("zodiac.pisces")
        default: name
        }
    }
}

// ── the sky's condition ─────────────────────────────────────────────────────

extension Weather {

    /// Read aloud by VoiceOver as the toggle's value, so it needs to be a
    /// word in the reader's language rather than an enum's raw value.
    var localizedName: String {
        switch self {
        case .clear: L10n.string("weather.clear")
        case .overcast: L10n.string("weather.overcast")
        case .rain: L10n.string("weather.rain")
        case .frost: L10n.string("weather.frost")
        }
    }
}

// ── where the visitor stands ────────────────────────────────────────────────

extension SkyModel.Station {

    /// The four places, named after the stones rather than after camera
    /// positions — so the translations name stones too. "Heel Stone" and
    /// "Avenue" stay as they are in the languages whose archaeology already
    /// borrows the English terms, and take a native form where one exists.
    var localizedName: String {
        switch self {
        case .aerial: L10n.string("place.aerial")
        case .altarStone: L10n.string("place.altarStone")
        case .heelStone: L10n.string("place.heelStone")
        case .avenue: L10n.string("place.avenue")
        }
    }
}

extension SkyModel.Viewpoint {

    var localizedName: String {
        switch self {
        case .here: L10n.string("viewpoint.here")
        case .stonehenge: L10n.string("viewpoint.wiltshire")
        }
    }
}

extension Planet {

    /// The naked-eye planets, named as each language names them. Keyed by the
    /// raw value, which is the English name and this type's identity.
    var localizedName: String {
        switch self {
        case .mercury: L10n.string("planet.mercury")
        case .venus: L10n.string("planet.venus")
        case .mars: L10n.string("planet.mars")
        case .jupiter: L10n.string("planet.jupiter")
        case .saturn: L10n.string("planet.saturn")
        }
    }
}

extension HengeGeometry.Alignment {

    var localizedName: String {
        switch self {
        case .midsummerSunrise:
            L10n.string("alignment.midsummerSunrise")
        case .midwinterSunset:
            L10n.string("alignment.midwinterSunset")
        case .majorStandstillMoonrise:
            L10n.string("alignment.majorStandstillMoonrise")
        }
    }
}

// ── what the app is prepared to say ─────────────────────────────────────────

extension LoreTier {

    var localizedLabel: String {
        switch self {
        case .established: L10n.string("lore.tier.established")
        case .debated: L10n.string("lore.tier.debated")
        case .modernTradition: L10n.string("lore.tier.modernTradition")
        }
    }

    var localizedShortLabel: String {
        switch self {
        case .established: L10n.string("lore.tier.short.established")
        case .debated: L10n.string("lore.tier.short.debated")
        case .modernTradition: L10n.string("lore.tier.short.modernTradition")
        }
    }
}

extension LoreNote {

    /// Keyed by the note's own identifier, which is already stable enough to
    /// deduplicate `Lore.all` — so a reworded English claim carries its
    /// translations with it instead of orphaning them.
    ///
    /// The claims themselves are translated, which is a decision with a cost
    /// worth naming: MISSION.md's third invariant binds every claim to a tier
    /// and a citation, and a translated claim is one no reviewer of the
    /// original checked. The tiers travel with the claims, the citations are
    /// left in their published form so any reader can go and check, and
    /// `LoreLocalizationTests` refuses to let a note ship with a translation
    /// missing — a half-translated note would present an English sentence
    /// under a translated tier, which is the one outcome worse than either.
    var localizedTitle: String {
        L10n.dynamic("lore.\(id).title")
    }

    var localizedBody: String {
        L10n.dynamic("lore.\(id).body")
    }
}
