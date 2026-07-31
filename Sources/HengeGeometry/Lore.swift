import Foundation
import HengeAstro

/// How much weight a claim carries.
///
/// This is the type that keeps MISSION.md's third invariant honest. Everything
/// the app *says* — as opposed to computes — is a `LoreNote`, and a `LoreNote`
/// cannot exist without a tier and at least one citation. The compiler enforces
/// the shape; `LoreTests` enforces that nothing ships with an empty source list
/// or a claim so long it has stopped being a claim.
///
/// The three tiers exist because Stonehenge attracts all three kinds of
/// statement and they get told in the same voice everywhere else.
public enum LoreTier: String, Sendable, CaseIterable, Hashable {

    /// Survey, excavation, radiocarbon. Things that would take new evidence to
    /// overturn rather than a new argument.
    case established = "Established"

    /// Real scholarly disagreement. The astronomical claims mostly live here,
    /// and so does almost everything about purpose.
    case debated = "Debated"

    /// Living practice, and none the worse for it — but it is eighteenth
    /// century onward, not Neolithic, and the app never lets the two blur.
    case modernTradition = "Modern tradition"

    public var shortLabel: String {
        switch self {
        case .established: "fact"
        case .debated: "debated"
        case .modernTradition: "tradition"
        }
    }
}

/// Where a claim comes from. Free text on purpose — a bibliography, not a
/// database — but never empty.
public struct Citation: Sendable, Hashable {

    public let source: String
    /// Page, chapter or section, where it helps a reader find the passage.
    public let locator: String?

    public init(_ source: String, _ locator: String? = nil) {
        self.source = source
        self.locator = locator
    }

    public var text: String {
        guard let locator else { return source }
        return "\(source), \(locator)"
    }
}

/// One thing the app is prepared to say out loud.
public struct LoreNote: Sendable, Hashable, Identifiable {

    public let id: String
    public let title: String
    public let body: String
    public let tier: LoreTier
    public let citations: [Citation]

    public init(id: String, title: String, body: String,
                tier: LoreTier, citations: [Citation]) {
        self.id = id
        self.title = title
        self.body = body
        self.tier = tier
        self.citations = citations
    }
}

/// The notes themselves.
public enum Lore {

    /// What the app says about each station of the year.
    ///
    /// Note the shape of it: the two solstices are `established` as *alignments*
    /// and `debated` as intentions; the cross-quarters are `modernTradition`
    /// throughout, because there is no evidence Stonehenge marks them and
    /// saying otherwise would be inventing an archaeology to fit a calendar.
    public static func note(for station: WheelStation) -> LoreNote {
        switch station {
        case .juneSolstice:
            LoreNote(
                id: "wheel.june",
                title: "Midsummer — the axis",
                body: """
                    The monument's axis points at the midsummer sunrise, and it is \
                    the one alignment nobody argues with: the Avenue, the Heel Stone \
                    and the Great Trilithon all lie on it. What is argued is which \
                    way it was meant to be read. The same axis runs the other way at \
                    midwinter sunset, and the midwinter feasting debris at Durrington \
                    Walls is the stronger evidence for when people actually gathered.
                    """,
                tier: .established,
                citations: [Citation("Ruggles, Astronomy in Prehistoric Britain and Ireland", "ch. 3"),
                            Citation("Parker Pearson, Stonehenge: Exploring the Greatest Stone Age Mystery")])

        case .decemberSolstice:
            LoreNote(
                id: "wheel.december",
                title: "Midwinter — the other end of the same line",
                body: """
                    Stand at the Heel Stone at midwinter and the sun sets down the \
                    axis between the uprights of the Great Trilithon. The pig bones \
                    from Durrington Walls were slaughtered in midwinter, which is the \
                    closest thing there is to a direct record of when the monument \
                    was used.
                    """,
                tier: .established,
                citations: [Citation("Parker Pearson et al., 'Stonehenge Riverside Project'", "Antiquity 80"),
                            Citation("Ruggles, Astronomy in Prehistoric Britain and Ireland", "ch. 3")])

        case .marchEquinox, .septemberEquinox:
            LoreNote(
                id: "wheel.equinox",
                title: "The equinoxes — a modern reading",
                body: """
                    No feature of Stonehenge points at the equinoctial sunrise, and \
                    there is a good reason to doubt the builders reckoned equinoxes \
                    at all: an equinox is defined by arithmetic on the year, not by \
                    anything the sun visibly does that morning. The eightfold wheel \
                    that includes them was assembled in the twentieth century.
                    """,
                tier: .modernTradition,
                citations: [Citation("Ruggles, Astronomy in Prehistoric Britain and Ireland", "ch. 5"),
                            Citation("Hutton, The Stations of the Sun")])

        case .imbolc, .beltane, .lughnasadh, .samhain:
            LoreNote(
                id: "wheel.crossQuarter",
                title: "The cross-quarter days",
                body: """
                    Imbolc, Beltane, Lughnasadh and Samhain are Gaelic quarter days, \
                    first recorded in medieval Irish sources and kept on fixed \
                    calendar dates rather than solar ones — which is why the sun \
                    reaches the true midpoint of the season a few days after the \
                    date the festival is held. Their attachment to Stonehenge is \
                    modern. Ronald Hutton traces the eightfold wheel itself to Ross \
                    Nichols and Gerald Gardner in the 1950s.
                    """,
                tier: .modernTradition,
                citations: [Citation("Hutton, The Stations of the Sun"),
                            Citation("Hutton, Blood and Mistletoe: The History of the Druids in Britain")])
        }
    }

    /// Notes about the monument itself, keyed for the stone panels at M5.
    public static let monument: [LoreNote] = [
        LoreNote(
            id: "monument.sarsen",
            title: "The sarsens",
            body: """
                The great stones are sarsen, a silcrete that caps the chalk. \
                Geochemical fingerprinting in 2020 matched fifty of the fifty-two \
                surviving sarsens to West Woods, near Marlborough — about 25 km \
                north, and the first time the source was pinned rather than \
                guessed.
                """,
            tier: .established,
            citations: [Citation("Nash et al., 'Origins of the sarsen megaliths'", "Science Advances 6, 2020")]),

        LoreNote(
            id: "monument.bluestone",
            title: "The bluestones",
            body: """
                The smaller stones come from the Preseli hills in west Wales, \
                some 250 km away — established by petrology, and now by quarry \
                excavation at Carn Goedog and Craig Rhos-y-felin. How they \
                travelled is not established: human haulage and glacial transport \
                have both been argued for a century.
                """,
            tier: .debated,
            citations: [Citation("Parker Pearson et al., 'Megalithic quarries for Stonehenge's bluestones'", "Antiquity 93, 2019"),
                        Citation("Ixer & Bevins, 'The petrography of the Stonehenge bluestones'")]),

        LoreNote(
            id: "monument.aubrey",
            title: "The Aubrey Holes",
            body: """
                Fifty-six pits inside the bank, named for John Aubrey, who noted \
                depressions here in 1666. Hoyle proposed in 1966 that moving \
                markers around them could predict eclipses. The arithmetic works — \
                56 is three saros-adjacent counts — but nothing excavated from the \
                holes supports it, and they held cremated human bone. The app \
                offers the eclipse count as a toy, labelled as one.
                """,
            tier: .debated,
            citations: [Citation("Hoyle, 'Stonehenge — an eclipse predictor'", "Nature 211, 1966"),
                        Citation("Ruggles, Astronomy in Prehistoric Britain and Ireland", "ch. 3"),
                        Citation("Parker Pearson et al., 'Who was buried at Stonehenge?'", "Antiquity 83, 2009")]),

        LoreNote(
            id: "monument.druids",
            title: "The druids",
            body: """
                Stonehenge was raised between roughly 3000 and 1500 BC. The druids \
                are Iron Age, described by classical writers from the first century \
                BC — two thousand years later, nearer to us than to the builders. \
                The association is John Aubrey's and William Stukeley's, seventeenth \
                and eighteenth century. Modern druid orders have gathered here since \
                1905. All of that is real history; none of it is the builders'.
                """,
            tier: .modernTradition,
            citations: [Citation("Hutton, Blood and Mistletoe: The History of the Druids in Britain"),
                        Citation("Chippindale, Stonehenge Complete")]),

        LoreNote(
            id: "monument.stationStones",
            title: "The Station Stones",
            body: """
                Four stones set on the Aubrey circle, two surviving. Their \
                rectangle's short side runs on the solstitial axis and the long \
                side points, within a degree or so, at the southernmost moonrise \
                of the major standstill. That the geometry works at this latitude \
                and almost nowhere else in Britain is a real observation; that the \
                builders intended it is an inference.
                """,
            tier: .debated,
            citations: [Citation("Ruggles, Astronomy in Prehistoric Britain and Ireland", "ch. 3"),
                        Citation("Thom, Thom & Thom, 'Stonehenge as a possible lunar observatory'", "JHA 6, 1975")]),

        LoreNote(
            id: "monument.altarStone",
            title: "The Altar Stone",
            body: """
                The six-tonne slab lying flat at the monument's heart is not \
                from Wales, as long assumed alongside the bluestones. Dating \
                of zircon, apatite and rutile grains within it traces the \
                stone to the Orcadian Basin of north-east Scotland — at \
                least 750 km away, likely moved by sea. The finding argues \
                for a scale of Neolithic long-range contact across Britain \
                not previously credited for this period.
                """,
            tier: .established,
            citations: [Citation("Clarke et al., 'A Scottish provenance for the Altar Stone of Stonehenge'", "Nature 632, 570–575, 2024"),
                        Citation("Gaind & Smith, news feature", "Nature 632, 484–485, 2024")]),

        LoreNote(
            id: "monument.slaughterStone",
            title: "The Slaughter Stone",
            body: """
                The fallen sarsen at the north-east entrance owes its name to \
                antiquarian imagination, not evidence: early observers read \
                the rust-red iron staining on its surface as old blood and \
                named it accordingly. Nothing excavated here supports \
                sacrifice of any kind — animal or human — at this stone or \
                anywhere else on site. A popular infographic circulating as \
                stock imagery labels it the "Stone of the sacrifice"; that \
                phrasing repeats the same nineteenth-century misreading this \
                note exists to correct.
                """,
            tier: .established,
            citations: [Citation("Chippindale, Stonehenge Complete"),
                        Citation("English Heritage, Stonehenge World Heritage Site guidebook")]),

        LoreNote(
            id: "monument.overlay",
            title: "The drawn lines and the gold markers",
            body: """
                The overlay draws the monument's researched geometry on the \
                turf. The cardinal strokes, the solstice axis and the Avenue \
                are established survey. The Station-Stone rectangle's lunar \
                long sides are a serious, contested reading. The gold markers \
                act out the Aubrey-hole eclipse machine proposed by Hoyle in \
                1966 — placed here at the real computed positions of sun, \
                moon and nodes, because the shuffling of counters is the part \
                nothing excavated supports: the holes held cremated human \
                remains. Gold means moving, and moving means hypothesis.
                """,
            tier: .debated,
            citations: [Citation("Hoyle, 'Stonehenge — an eclipse predictor'", "Nature 211, 1966"),
                        Citation("Newham, The Enigma of Stonehenge", "1964"),
                        Citation("Ruggles, Astronomy in Prehistoric Britain and Ireland", "ch. 3"),
                        Citation("Parker Pearson et al., 'Who was buried at Stonehenge?'", "Antiquity 83, 2009")])
    ]

    /// Everything the app can say, each note once.
    ///
    /// Deduplicated by identifier because several stations deliberately share a
    /// note — there is one honest thing to say about the equinoxes and one about
    /// the cross-quarters, and writing it four times each would be four places
    /// for the tiering to drift apart.
    public static var all: [LoreNote] {
        var seen = Set<String>()
        return (monument + WheelStation.allCases.map { note(for: $0) })
            .filter { seen.insert($0.id).inserted }
    }
}
