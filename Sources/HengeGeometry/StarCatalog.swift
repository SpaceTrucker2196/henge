import Foundation
import HengeAstro

/// The naked-eye sky, from the Hipparcos catalogue.
///
/// **Provenance (invariant 5):** ESA, 1997, *The Hipparcos and Tycho
/// Catalogues*, ESA SP-1200 — free with attribution, which this header and
/// `SECURITY.md` provide. The bundled file is `hip_main.dat` (CDS I/239)
/// filtered to V ≤ 6.5 — the 8,870 stars a dark-adapted eye can see — with
/// each line carrying HIP identifier, ICRS position at epoch J1991.25,
/// V magnitude, B−V colour index, and the two proper-motion components.
///
/// The catalogue lives in `HengeGeometry` beside the terrain heightfield
/// because `HengeAstro` is a no-I/O module: the arithmetic that moves these
/// stars is there and provable without a file system, and the file is here
/// with the other bundled survey data.
public struct StarCatalog: Sendable {

    /// One catalogue star, as vendored.
    public struct Entry: Sendable, Hashable {
        public let hip: Int
        /// ICRS at epoch J1991.25.
        public let rightAscension: HengeAstro.Angle
        public let declination: HengeAstro.Angle
        public let magnitude: Double
        /// B−V colour index; 0 for the handful of entries without one.
        public let colourIndex: Double
        /// μα★ (already × cos δ) and μδ, mas/yr.
        public let pmRACosDec: Double
        public let pmDeclination: Double
    }

    /// A star ready for the sky of a particular date.
    public struct Instance: Sendable {
        /// Unit vector against the equator and equinox of that date.
        public let direction: SIMD3<Double>
        public let magnitude: Double
        /// Linear RGB, an artistic reading of the B−V index — a blackbody
        /// impression, not photometry, and labelled as such.
        public let colour: SIMD3<Float>
    }

    public let entries: [Entry]

    /// Where the bundled catalogue lives. Subdirectory first, flat second —
    /// the same pair the terrain uses, and for the same reason: this package
    /// ships its files with `.copy("Resources")`, and the macOS app bundle
    /// keeps that nesting where the flat lookup cannot see it. The flat
    /// lookup alone found the file under SwiftPM and on iOS and returned nil
    /// inside the macOS app — a starless night on exactly one platform,
    /// silent because nil means "no stars tonight" by contract. Internal so
    /// the test can hold the subdirectory path specifically.
    static func bundledCatalogueURL(subdirectoryOnly: Bool = false) -> URL? {
        let nested = Bundle.module.url(forResource: "hipparcos-bright",
                                       withExtension: "csv",
                                       subdirectory: "Resources")
        if subdirectoryOnly { return nested }
        return nested ?? Bundle.module.url(forResource: "hipparcos-bright",
                                           withExtension: "csv")
    }

    /// Load the bundled catalogue. Nil rather than a throw, and the renderer
    /// treats nil as "no stars tonight": the almanac must not die for want
    /// of decoration — same contract as the surface textures.
    public static func load() -> StarCatalog? {
        guard let url = bundledCatalogueURL(),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        var entries: [Entry] = []
        entries.reserveCapacity(9000)
        for line in text.split(separator: "\n") {
            let fields = line.split(separator: ",")
            guard fields.count == 7,
                  let hip = Int(fields[0]),
                  let ra = Double(fields[1]),
                  let dec = Double(fields[2]),
                  let magnitude = Double(fields[3]),
                  let colourIndex = Double(fields[4]),
                  let pmRA = Double(fields[5]),
                  let pmDec = Double(fields[6]) else { continue }
            entries.append(Entry(hip: hip,
                                 rightAscension: Angle(degrees: ra),
                                 declination: Angle(degrees: dec),
                                 magnitude: magnitude,
                                 colourIndex: colourIndex,
                                 pmRACosDec: pmRA,
                                 pmDeclination: pmDec))
        }
        guard !entries.isEmpty else { return nil }
        return StarCatalog(entries: entries)
    }

    /// Every star, moved to a date: proper motion first, then precession —
    /// the sky the builders had, not tonight's with the labels changed.
    public func instances(at tt: JulianDay) -> [Instance] {
        entries.map { entry in
            let moved = StarField.properMotionApplied(
                rightAscension: entry.rightAscension,
                declination: entry.declination,
                pmRACosDec: entry.pmRACosDec,
                pmDeclination: entry.pmDeclination,
                at: tt)
            let dated = StarField.equatorialOfDate(
                rightAscension: moved.rightAscension,
                declination: moved.declination,
                at: tt)
            return Instance(direction: StarField.unitVector(
                                rightAscension: dated.rightAscension,
                                declination: dated.declination),
                            magnitude: entry.magnitude,
                            colour: Self.colour(forIndex: entry.colourIndex))
        }
    }

    /// B−V to a linear RGB impression: blue-white for the hot stars, solar
    /// white near 0.65, ember orange past 1.5. Piecewise between published
    /// anchor temperatures, but the palette itself is an artistic choice —
    /// deliberately more saturated than a photometric conversion, because at
    /// three pixels the eye needs the type to *read*: Rigel against
    /// Betelgeuse is the sky's own lesson in stellar type, and a timid
    /// palette teaches nothing.
    static func colour(forIndex bv: Double) -> SIMD3<Float> {
        let anchors: [(index: Double, colour: SIMD3<Float>)] = [
            (-0.30, SIMD3(0.50, 0.64, 1.00)),
            (0.00, SIMD3(0.70, 0.80, 1.00)),
            (0.65, SIMD3(1.00, 0.95, 0.84)),
            (1.50, SIMD3(1.00, 0.55, 0.26))
        ]
        if bv <= anchors[0].index { return anchors[0].colour }
        for i in 1..<anchors.count where bv <= anchors[i].index {
            let a = anchors[i - 1], b = anchors[i]
            let t = Float((bv - a.index) / (b.index - a.index))
            return a.colour + (b.colour - a.colour) * t
        }
        return anchors[anchors.count - 1].colour
    }

    // ── proper names ────────────────────────────────────────────────────────

    /// Every star that has a name — the full IAU register, filtered to the
    /// stars this catalogue carries.
    ///
    /// **Provenance:** the IAU Working Group on Star Names' Catalog of Star
    /// Names (IAU-CSN, maintained by E. Mamajek, fetched 2026-07-28),
    /// matched by HIP identifier against the bundled Hipparcos subset: 338
    /// of the register's names belong to naked-eye stars and all of them
    /// are here. Generated, not typed — regenerate against a fresh IAU-CSN
    /// rather than editing.
    public static let properNames: [Int: String] = [
        13847: "Acamar", 7588: "Achernar", 3821: "Achird",
        78820: "Acrab", 60718: "Acrux", 44066: "Acubens",
        50335: "Adhafera", 33579: "Adhara", 6411: "Adhil",
        20889: "Ain", 92761: "Ainalrami", 94481: "Aladfar",
        94141: "Albaldah", 102618: "Albali", 95947: "Albireo",
        59199: "Alchiba", 65477: "Alcor", 17702: "Alcyone",
        21421: "Aldebaran", 105199: "Alderamin", 108085: "Aldhanab",
        83895: "Aldhibah", 101421: "Aldulfin", 106032: "Alfirk",
        100064: "Algedi", 1067: "Algenib", 50583: "Algieba",
        14576: "Algol", 60965: "Algorab", 31681: "Alhena",
        62956: "Alioth", 102488: "Aljanah", 67301: "Alkaid",
        75411: "Alkalurops", 44471: "Alkaphrah", 115623: "Alkarab",
        53740: "Alkes", 23416: "Almaaz", 9640: "Almach",
        109268: "Alnair", 88635: "Alnasl", 26311: "Alnilam",
        26727: "Alnitak", 80112: "Alniyat", 46390: "Alphard",
        76267: "Alphecca", 677: "Alpheratz", 7097: "Alpherg",
        83608: "Alrakis", 9487: "Alrescha", 86782: "Alruba",
        96100: "Alsafi", 41075: "Alsciaukat", 42913: "Alsephina",
        98036: "Alshain", 100310: "Alshat", 97649: "Altair",
        94376: "Altais", 46750: "Alterf", 35904: "Aludra",
        55219: "Alula Borealis", 92946: "Alya", 32362: "Alzirr",
        110003: "Ancha", 13288: "Angetenar", 2081: "Ankaa",
        95771: "Anser", 80763: "Antares", 69673: "Arcturus",
        95294: "Arkab Posterior", 95241: "Arkab Prior", 25985: "Arneb",
        93506: "Ascella", 42911: "Asellus Australis", 42806: "Asellus Borealis",
        43109: "Ashlesha", 45556: "Aspidiske", 17579: "Asterope",
        80331: "Athebyne", 17448: "Atik", 17847: "Atlas",
        82273: "Atria", 41037: "Avior", 107136: "Azelfafage",
        13701: "Azha", 38170: "Azmidi", 8645: "Baten Kaitos",
        20535: "Beemim", 19587: "Beid", 25336: "Bellatrix",
        27989: "Betelgeuse", 13209: "Bharani", 109427: "Biham",
        14838: "Botein", 73714: "Brachium", 106786: "Bunda",
        30438: "Canopus", 24608: "Capella", 746: "Caph",
        36850: "Castor", 4422: "Castula", 86742: "Cebalrai",
        17489: "Celaeno", 86796: "Cervantes", 53721: "Chalawan",
        20894: "Chamukuy", 61317: "Chara", 99894: "Chechia",
        54879: "Chertan", 33719: "Citala", 43587: "Copernicus",
        63125: "Cor Caroli", 80463: "Cujam", 23875: "Cursa",
        100345: "Dabih", 14879: "Dalim", 102098: "Deneb",
        107556: "Deneb Algedi", 57632: "Denebola", 64241: "Diadem",
        3419: "Diphda", 78401: "Dschubba", 54061: "Dubhe",
        86614: "Dziban", 75458: "Edasich", 17499: "Electra",
        70755: "Elgafar", 29034: "Elkurud", 25428: "Elnath",
        87833: "Eltanin", 107315: "Enif", 116727: "Errai",
        90344: "Fafnir", 78265: "Fang", 97165: "Fawaris",
        48615: "Felis", 113368: "Fomalhaut", 56508: "Formosa",
        2920: "Fulu", 113889: "Fumalsamakah", 30122: "Furud",
        87261: "Fuyue", 61084: "Gacrux", 56211: "Giausar",
        59803: "Gienah", 60260: "Ginan", 36188: "Gomeisa",
        87585: "Grumium", 77450: "Gudja", 94645: "Gumala",
        84405: "Guniibuu", 68702: "Hadar", 23767: "Haedus",
        9884: "Hamal", 23015: "Hassaleh", 26241: "Hatysa",
        113357: "Helvetios", 66249: "Heze", 112029: "Homam",
        78104: "Iklil", 59747: "Imai", 46471: "Intercrus",
        72105: "Izar", 79374: "Jabbah", 37265: "Jishui",
        12706: "Kaffaljidhma", 69427: "Kang", 90185: "Kaus Australis",
        90496: "Kaus Borealis", 89931: "Kaus Media", 19849: "Keid",
        69974: "Khambalia", 104987: "Kitalpha", 72607: "Kochab",
        80816: "Kornephoros", 61359: "Kraz", 108917: "Kurhah",
        62223: "La Superba", 82396: "Larawag", 85696: "Lesath",
        97938: "Libertas", 13061: "Lilii Borea", 85693: "Maasym",
        24003: "Mago", 28380: "Mahasim", 17573: "Maia",
        80883: "Marfik", 113963: "Markab", 45941: "Markeb",
        79043: "Marsic", 112158: "Matar", 32246: "Mebsuta",
        59774: "Megrez", 26207: "Meissa", 34088: "Mekbuda",
        42556: "Meleph", 28360: "Menkalinan", 14135: "Menkar",
        68933: "Menkent", 18614: "Menkib", 53910: "Merak",
        72487: "Merga", 94114: "Meridiana", 17608: "Merope",
        8832: "Mesarthim", 45238: "Miaplacidus", 62434: "Mimosa",
        42402: "Minchir", 63090: "Minelauva", 25930: "Mintaka",
        10826: "Mira", 5447: "Mirach", 13268: "Miram",
        15863: "Mirfak", 30324: "Mirzam", 14668: "Misam",
        65378: "Mizar", 8796: "Mothallah", 34045: "Muliphein",
        67927: "Muphrid", 41704: "Muscida", 103527: "Musica",
        44946: "Nahn", 39429: "Naos", 106985: "Nashira",
        73555: "Nekkar", 7607: "Nembus", 33856: "Nganurganity",
        25606: "Nihal", 92855: "Nunki", 75695: "Nusakan",
        93747: "Okab", 81266: "Paikauhale", 100751: "Peacock",
        26634: "Phact", 58001: "Phecda", 75097: "Pherkad",
        40881: "Piautos", 82545: "Pipirima", 17851: "Pleione",
        11767: "Polaris", 104382: "Polaris Australis", 89341: "Polis",
        37826: "Pollux", 61941: "Porrima", 53229: "Praecipua",
        20205: "Prima Hyadum", 37279: "Procyon", 29655: "Propus",
        16537: "Ran", 17378: "Rana", 48455: "Rasalas",
        84345: "Rasalgethi", 86032: "Rasalhague", 85670: "Rastaban",
        49669: "Regulus", 5737: "Revati", 24436: "Rigel",
        71683: "Rigil Kentaurus", 101769: "Rotanev", 6686: "Ruchbah",
        95347: "Rukbat", 84012: "Sabik", 23453: "Saclateni",
        110395: "Sadachbia", 112748: "Sadalbari", 109074: "Sadalmelik",
        106278: "Sadalsuud", 100453: "Sadr", 27366: "Saiph",
        115250: "Salm", 86228: "Sargas", 84379: "Sarin",
        21594: "Sceptrum", 113881: "Scheat", 3179: "Schedar",
        20455: "Secunda Hyadum", 8886: "Segin", 71075: "Seginus",
        96757: "Sham", 85927: "Shaula", 92420: "Sheliak",
        8903: "Sheratan", 32349: "Sirius", 111710: "Situla",
        113136: "Skat", 65474: "Spica", 101958: "Sualocin",
        47508: "Subra", 44816: "Suhail", 93194: "Sulafat",
        69701: "Syrma", 22449: "Tabit", 57399: "Taiyangshou",
        63076: "Taiyi", 44127: "Talitha", 50801: "Tania Australis",
        50372: "Tania Borealis", 97278: "Tarazed", 40526: "Tarf",
        17531: "Taygeta", 40167: "Tegmine", 30343: "Tejat",
        98066: "Terebellum", 21393: "Theemin", 68756: "Thuban",
        112122: "Tiaki", 26451: "Tianguan", 62423: "Tianyi",
        7513: "Titawin", 71681: "Toliman", 58952: "Tonatiuh",
        8198: "Torcular", 39757: "Tureis", 47431: "Ukdah",
        77070: "Unukalhai", 91262: "Vega", 116076: "Veritate",
        63608: "Vindemiatrix", 35550: "Wasat", 27628: "Wazn",
        34444: "Wezen", 5348: "Wurren", 82514: "Xamidimura",
        91852: "Xihe", 69732: "Xuange", 79882: "Yed Posterior",
        79593: "Yed Prior", 85822: "Yildun", 60129: "Zaniah",
        18543: "Zaurak", 57757: "Zavijava", 48356: "Zhang",
        15197: "Zibal", 54872: "Zosma", 72622: "Zubenelgenubi",
        76333: "Zubenelhakrabi", 74785: "Zubeneschamali"
    ]

    /// The named stars, moved to a date — the label layer's whole diet.
    public func namedStars(at tt: JulianDay)
        -> [(name: String, direction: SIMD3<Double>, magnitude: Double)] {
        entries.compactMap { entry in
            guard let name = Self.properNames[entry.hip] else { return nil }
            let moved = StarField.properMotionApplied(
                rightAscension: entry.rightAscension,
                declination: entry.declination,
                pmRACosDec: entry.pmRACosDec,
                pmDeclination: entry.pmDeclination,
                at: tt)
            let dated = StarField.equatorialOfDate(
                rightAscension: moved.rightAscension,
                declination: moved.declination,
                at: tt)
            return (name,
                    StarField.unitVector(rightAscension: dated.rightAscension,
                                         declination: dated.declination),
                    entry.magnitude)
        }
    }
}
