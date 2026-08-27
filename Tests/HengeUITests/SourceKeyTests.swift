import XCTest
// @testable for `Bundle.module`, which is internal to the module whose
// catalogue is under test — the same reach `LocalizationTests` takes.
@testable import HengeUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// **Every key the interface asks for exists in the catalogue.**
///
/// `LocalizationTests` walks the catalogue and proves the nine languages agree
/// with each other. That is one half of the guarantee and it was the only half
/// there was: a key the *source* asks for and the catalogue has never heard of
/// passes every one of those tests, because the catalogue is self-consistent
/// about a string it does not contain.
///
/// The gap was found through GitHub issue #1, which reported that no control
/// in the macOS build exposed a label to the accessibility API and named a
/// missing localisation as one of two suspects. The suspect was half right in
/// a way nobody had a test for: the labels on nine of the app's controls were
/// not localised *at all* — they were English literals compiled into
/// `RootView`, so a reader using VoiceOver in Korean heard "Light the torch".
/// Nothing in the build said so, because nothing was looking from this side.
///
/// So this test reads the shipped Swift sources, collects every key-shaped
/// string literal in them, and asserts the English catalogue answers for each
/// one. It is deliberately the awkward direction — source to catalogue — since
/// that is the direction the failure runs in.
final class SourceKeyTests: XCTestCase {

    /// The module's sources, found relative to this file.
    ///
    /// Reading source from a test is unusual and worth the oddness here: a
    /// hand-written list of keys would drift the first time somebody added a
    /// control, which is exactly when this needs to fire.
    private var sourceDirectory: URL {
        URL(fileURLWithPath: #filePath)          // …/Tests/HengeUITests/this
            .deletingLastPathComponent()          // …/Tests/HengeUITests
            .deletingLastPathComponent()          // …/Tests
            .deletingLastPathComponent()          // …/
            .appendingPathComponent("Sources/HengeUI")
    }

    /// Dotted, unspaced, ASCII, and starting lower case — what every key in
    /// the catalogue looks like and what no display string does.
    private static let keyShaped = try! NSRegularExpression(
        pattern: "^[a-z][A-Za-z0-9]*(?:\\.[A-Za-z0-9]+)+$")

    /// Whether a name belongs to SF Symbols rather than to the catalogue.
    ///
    /// Symbol names are dotted and lower case too — `chevron.compact.left`,
    /// `hand.draw.fill` — so they are indistinguishable from keys by shape.
    /// Rather than keep a list of them by hand, ask the system: if it draws,
    /// it is a symbol. A catalogue key that happened to name a real symbol
    /// would be skipped, which is a gap this accepts; no key in the app is
    /// shaped like `sun.max`.
    private func namesASystemSymbol(_ name: String) -> Bool {
        #if canImport(AppKit)
        return NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
        #elseif canImport(UIKit)
        return UIImage(systemName: name) != nil
        #else
        return false
        #endif
    }

    /// Every key-shaped literal in one file, with the noise stripped first.
    private func keys(in source: String) -> Set<String> {
        var text = source
        for pattern in [
            // Symbols named at the call site, and accessibility identifiers,
            // which are dotted by design and are not catalogue keys.
            "systemName:\\s*\"[^\"]*\"",
            "accessibilityIdentifier\\(\\s*\"[^\"]*\"\\s*\\)",
        ] {
            let regex = try! NSRegularExpression(pattern: pattern)
            text = regex.stringByReplacingMatches(
                in: text, range: NSRange(text.startIndex..., in: text),
                withTemplate: "")
        }

        var found = Set<String>()
        let literal = try! NSRegularExpression(pattern: "\"([^\"\\\\\n]+)\"")
        for match in literal.matches(in: text,
                                     range: NSRange(text.startIndex..., in: text)) {
            guard let range = Range(match.range(at: 1), in: text) else { continue }
            let candidate = String(text[range])
            let whole = NSRange(candidate.startIndex..., in: candidate)
            guard Self.keyShaped.firstMatch(in: candidate, range: whole) != nil,
                  // The app's own accessibility identifiers all carry this
                  // prefix precisely so they can be told apart from keys.
                  !candidate.hasPrefix("henge."),
                  !namesASystemSymbol(candidate)
            else { continue }
            found.insert(candidate)
        }
        return found
    }

    /// The English catalogue, which is the authority on which keys exist.
    private func englishCatalogue() throws -> [String: String] {
        let root = try XCTUnwrap(Bundle.module.resourcePath,
                                 "the test bundle carries no resources")
        let entries = try FileManager.default.contentsOfDirectory(atPath: root)
        let folder = try XCTUnwrap(entries.first { $0.lowercased() == "en.lproj" },
                                   "the English strings did not ship")
        return try XCTUnwrap(
            NSDictionary(contentsOfFile: root + "/" + folder + "/Localizable.strings")
                as? [String: String],
            "the English strings did not parse")
    }

    // ── the test ────────────────────────────────────────────────────────────

    /// **No control, sheet or readout asks for a string the catalogue lacks.**
    ///
    /// A missing key does not crash and does not warn. `Text("toggle.x")`
    /// renders the raw key, and an accessibility label built from one speaks
    /// it — so the failure is invisible in every English screenshot and
    /// audible only to the person least able to work around it.
    func testEveryKeyTheSourceAsksForIsInTheCatalogue() throws {
        let catalogue = try englishCatalogue()
        let files = try FileManager.default
            .contentsOfDirectory(at: sourceDirectory,
                                 includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }

        XCTAssertGreaterThan(files.count, 5,
                             "the sources were not found at \(sourceDirectory.path) "
                             + "— this test cannot see what it is guarding")

        var checked = 0
        for file in files {
            let source = try String(contentsOf: file, encoding: .utf8)
            for key in keys(in: source).sorted() {
                checked += 1
                XCTAssertNotNil(
                    catalogue[key],
                    "\(file.lastPathComponent) asks for '\(key)', which the "
                    + "English catalogue does not contain — it will render as "
                    + "the raw key, and be spoken as one")
            }
        }

        XCTAssertGreaterThan(checked, 100,
                             "only \(checked) keys were found in the sources, "
                             + "which means the scan stopped seeing them")
    }

    /// Every string literal written inside an accessibility call.
    ///
    /// A regular expression cannot do this: the labels that were wrong were
    /// wrong *inside* a ternary — `accessibilityLabel(on ? "Hide it" : "Show
    /// it")` — so a pattern anchored to the opening bracket sees nothing. The
    /// first draft of this test was written that way and reported zero
    /// offenders against the very code it was written to catch, which is a
    /// worse outcome than having no test. So the argument list is walked with
    /// the brackets counted, and every literal in it is examined.
    private func literals(inAccessibilityCallsOf source: String) -> [(call: String,
                                                                      text: String)] {
        let triggers = ["accessibilityLabel(", "accessibilityValue(",
                        "accessibilityHint(", "accessibilityAction("]
        var found: [(String, String)] = []

        for trigger in triggers {
            var searchFrom = source.startIndex
            while let opening = source.range(of: trigger,
                                             range: searchFrom..<source.endIndex) {
                var index = opening.upperBound
                var depth = 1
                while index < source.endIndex, depth > 0 {
                    let character = source[index]
                    if character == "\"" {
                        // Run to the closing quote, honouring escapes.
                        var end = source.index(after: index)
                        while end < source.endIndex,
                              !(source[end] == "\"" && source[source.index(before: end)] != "\\") {
                            end = source.index(after: end)
                        }
                        found.append((trigger,
                                      String(source[source.index(after: index)..<end])))
                        index = end < source.endIndex ? source.index(after: end) : end
                        continue
                    }
                    if character == "(" { depth += 1 }
                    else if character == ")" { depth -= 1 }
                    index = source.index(after: index)
                }
                searchFrom = opening.upperBound
            }
        }
        return found
    }

    /// **No accessibility label is a bare English sentence.**
    ///
    /// The defect issue #1 half-caught, and the one nothing in the build could
    /// see. `accessibilityLabel("Light the torch")` compiles, reads perfectly
    /// in every English screenshot, and is the one class of string in the app
    /// that nine translations cannot reach — so the reader it fails is the
    /// reader who is using VoiceOver in Korean, and no screenshot will ever
    /// show it.
    ///
    /// A label must therefore come from the catalogue: a `Text(_:bundle:)`, or
    /// a name the model has already localised. A literal is allowed only when
    /// it is key-shaped, which is what a catalogue key looks like, or when it
    /// interpolates — those are format keys and `testEveryKeyTheSourceAsksFor`
    /// covers them.
    func testNoAccessibilityLabelIsAHardcodedSentence() throws {
        let files = try FileManager.default
            .contentsOfDirectory(at: sourceDirectory,
                                 includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        XCTAssertGreaterThan(files.count, 5, "the sources were not found")

        for file in files {
            let source = try String(contentsOf: file, encoding: .utf8)
            for (call, text) in literals(inAccessibilityCallsOf: source) {
                guard text.contains(" "), !text.contains("\\(") else { continue }
                XCTFail("\(file.lastPathComponent): \(call)…\"\(text)\") is an "
                        + "untranslated accessibility string — it can only ever "
                        + "be spoken in English")
            }
        }
    }
}
