import Foundation

/// Per-stone heights, transcribed from the printed page.
///
/// **Provenance (invariant 5):** Cleal, Walker & Montague, *Stonehenge in its
/// Landscape: Twentieth-century Excavations* (English Heritage Archaeological
/// Report 10, 1995), Appendix 5, "Heights of Stones", pp 547–548. The
/// appendix compiles the Chief Architect's Report of 1919 and Professor
/// Atkinson's records. It is published on the Archaeology Data Service under
/// terms that allow this reuse with acknowledgement; `SECURITY.md` has the
/// row and the info view the credit.
///
/// Two things the table is not. It is not one epoch: stones re-erected in
/// 1958 (22, 57, 58) are listed as they lay, in lettered pieces, and their
/// standing height is simply absent. And a lettered entry is not a standing
/// height unless the stone stands: the appendix lists pieces of fallen
/// stones the same way it lists the one figure of a standing bluestone. So
/// the scene asks `standingHeight(of:)` only for a stone the plan says is
/// standing, and that returns the unlettered figure, or the sole "A" figure,
/// and nothing for a stone the appendix records as it lay.
public struct StoneSurvey: Sendable {

    public struct Row: Sendable, Hashable {
        public let petrie: String
        /// Empty for a single standing figure; "A", "B", … for the pieces of
        /// a fallen or broken stone; "lintel" for a lintel's thickness.
        public let part: String
        public let feetAsPrinted: String
        public let metres: Double?
        public let source: String
        public let page: Int
        public let note: String
    }

    public let rows: [Row]

    public static let citation = Citation(
        "Cleal, Walker & Montague, Stonehenge in its Landscape (EH Archaeological Report 10, 1995)",
        "Appendix 5, Heights of Stones, pp 547–548")

    /// The vendored transcription, or nil if the resource is missing.
    public static let cleal: StoneSurvey? = {
        guard let url = bundledURL(), let text = try? String(contentsOf: url, encoding: .utf8)
        else { return nil }
        return try? StoneSurvey(csv: text)
    }()

    static func bundledURL(subdirectoryOnly: Bool = false) -> URL? {
        let nested = Bundle.module.url(forResource: "cleal-1995-appendix5",
                                       withExtension: "csv",
                                       subdirectory: "Resources/stones")
        if subdirectoryOnly { return nested }
        return nested
            ?? Bundle.module.url(forResource: "cleal-1995-appendix5", withExtension: "csv",
                                 subdirectory: "stones")
            ?? Bundle.module.url(forResource: "cleal-1995-appendix5", withExtension: "csv")
    }

    public enum SurveyError: Error {
        case malformedRow(String)
        case empty
    }

    public init(csv text: String) throws {
        var rows: [Row] = []
        var header: [String] = []
        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            let cells = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            if header.isEmpty { header = cells; continue }
            var row: [String: String] = [:]
            for (key, value) in zip(header, cells) { row[key] = value }
            guard let petrie = row["petrie"], !petrie.isEmpty,
                  let page = row["page"].flatMap(Int.init),
                  let source = row["source"]
            else { throw SurveyError.malformedRow(line) }
            rows.append(Row(petrie: petrie,
                            part: row["part"] ?? "",
                            feetAsPrinted: row["feet_as_printed"] ?? "",
                            metres: row["metres"].flatMap(Double.init),
                            source: source,
                            page: page,
                            note: row["note"] ?? ""))
        }
        guard !rows.isEmpty else { throw SurveyError.empty }
        self.rows = rows
    }

    public func rows(for petrie: String) -> [Row] {
        rows.filter { $0.petrie == petrie }
    }

    /// The height above ground of a stone that stands, or nil when the
    /// appendix has no such figure: no row, a row recorded as the stone lay
    /// before re-erection, or only the pieces of a broken stone.
    public func standingHeight(of petrie: String) -> Double? {
        let mine = rows(for: petrie).filter { $0.part != "lintel" }
        guard !mine.isEmpty else { return nil }
        if mine.contains(where: { $0.note.contains("re-erection") }) { return nil }
        if let single = mine.first(where: { $0.part.isEmpty }) { return single.metres }
        if mine.count == 1, mine[0].part == "A" { return mine[0].metres }
        // Several lettered pieces on a stone that still stands (34, 49): the
        // first is the stone's own height, the rest are broken-off parts,
        // which is how the appendix reads for both.
        return mine.first(where: { $0.part == "A" })?.metres
    }

    /// A lintel's thickness, where the Chief Architect recorded one.
    public func lintelThickness(of petrie: String) -> Double? {
        rows(for: petrie).first { $0.part == "lintel" }?.metres
    }

    // MARK: - Petrie 1880

    /// One row of Petrie's 1877 survey table, pp 9–12: height above ground
    /// and level of the top, both in inches. Public domain. The independent
    /// check on the appendix above, from before every re-erection.
    public struct PetrieRow: Sendable, Hashable {
        public let petrie: String
        public let heightInches: Double?
        public let topLevelInches: Double?
        public let remarks: String
        public let page: Int

        public var height: Double? { heightInches.map { $0 * 0.0254 } }
    }

    public static let petrieCitation = Citation(
        "Petrie, Stonehenge: Plans, Description, and Theories (1880)",
        "Details of the Stones, pp 9–12; surveyed 1874–77")

    public static let petrie: [PetrieRow]? = {
        guard let url = petrieURL(), let text = try? String(contentsOf: url, encoding: .utf8)
        else { return nil }
        var rows: [PetrieRow] = []
        var header: [String] = []
        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            let cells = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            if header.isEmpty { header = cells; continue }
            var row: [String: String] = [:]
            for (key, value) in zip(header, cells) { row[key] = value }
            guard let petrie = row["petrie"], !petrie.isEmpty,
                  let page = row["page"].flatMap(Int.init) else { return nil }
            rows.append(PetrieRow(petrie: petrie,
                                  heightInches: row["height_in"].flatMap(Double.init),
                                  topLevelInches: row["top_level_in"].flatMap(Double.init),
                                  remarks: row["remarks"] ?? "",
                                  page: page))
        }
        return rows.isEmpty ? nil : rows
    }()

    static func petrieURL() -> URL? {
        Bundle.module.url(forResource: "petrie-1880-heights", withExtension: "csv",
                          subdirectory: "Resources/stones")
            ?? Bundle.module.url(forResource: "petrie-1880-heights", withExtension: "csv",
                                 subdirectory: "stones")
            ?? Bundle.module.url(forResource: "petrie-1880-heights", withExtension: "csv")
    }
}
