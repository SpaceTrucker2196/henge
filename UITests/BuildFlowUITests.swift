import XCTest
import Vision

/// The rebuild card, read back off the pixels.
///
/// This suite exists because of an escape. In a landscape window the rebuild
/// progress card — the one panel composited outside the chrome's glass
/// container — drew its text rotated 180° from every other panel. No layout
/// assertion could see it: the accessibility tree reported the text present,
/// positioned and correct while the screen showed it upside down. Worse, OCR
/// alone cannot see it either — Vision recognises text at any rotation, so
/// "the words are on screen" is true of an upside-down card too.
///
/// So the inspection compares layout truth against render truth. The
/// accessibility frame says where the card *should* be; the bronze fill of
/// its progress bar says where the card actually *drew*. In the card's
/// layout the bar sits below the text; a render rotated 180° about its
/// centre puts the bar above it. The test finds the bar as a band of
/// bronze pixels and asserts it lies on the correct side.
///
/// A scope note, recorded because the mutation check earned it: the escape
/// itself lived in the OS glass compositor and only manifested under a
/// springboard launch into an already-rotated simulator — reintroducing the
/// glass dress under this runner did *not* re-break the card, in either
/// landscape, so this suite cannot claim to re-create that exact state.
/// What it pins is the enforceable contract the bug violated: launched
/// straight into either orientation, the card's pixels agree with its
/// layout. The fix itself was verified against the escape's own
/// environment by screenshot before this suite existed.
final class BuildFlowUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testRebuildCardRendersUprightInLandscape() throws {
        try assertRebuildCardRendersUpright(in: .landscapeRight)
    }

    @MainActor
    func testRebuildCardRendersUprightInPortrait() throws {
        try assertRebuildCardRendersUpright(in: .portrait)
    }

    @MainActor
    private func assertRebuildCardRendersUpright(
        in orientation: UIDeviceOrientation) throws {
        let app = XCUIApplication()
        // The fixture seam: RootView pins the rebuild card open at 40%
        // when asked by name, because the real card lives for about a
        // second — long enough to mislead a user, too short to inspect.
        // The pinned 40% also fixes the bronze band's width, which is
        // what the pixel search below is calibrated to.
        app.launchEnvironment["HENGE_UITEST_PIN_REBUILD_CARD"] = "1"
        // Rotate *before* launching, deliberately: the escape this suite
        // pins only manifested when the app came up already rotated — a
        // live rotation lets the glass portal pick up the transform, and a
        // test that rotates after launch verified nothing (the mutation
        // check said so). Give the device a beat to finish turning, then
        // launch into it.
        XCUIDevice.shared.orientation = orientation
        Thread.sleep(forTimeInterval: 1.0)
        app.launch()
        let wantsLandscape = orientation.isLandscape
        let rotationDeadline = Date().addingTimeInterval(15)
        while Date() < rotationDeadline,
              (app.frame.width > app.frame.height) != wantsLandscape {
            Thread.sleep(forTimeInterval: 0.25)
        }
        XCTAssertEqual(app.frame.width > app.frame.height, wantsLandscape,
                       "the window never adopted the requested orientation")

        let cardText = app.staticTexts["Raising the stones"]
        XCTAssertTrue(cardText.waitForExistence(timeout: 20),
                      "the pinned rebuild card never appeared")
        _ = app.staticTexts["Sundial"].waitForExistence(timeout: 20)

        // ── capture, and calibrate the capture's framing ────────────────
        // A screenshot of a rotated simulator may be framed four ways, and
        // the claim must not depend on which. Two anchors whose layout is
        // known pin it: the date panel is pinned to the top of the screen
        // and the station tabs to the bottom. Whichever of the four
        // rotations puts them there maps capture pixels into upright app
        // coordinates. In landscape the date panel's centre sits near 35%
        // of the short axis, so the bands are generous — what
        // disambiguates is that both anchors must land at once, and that
        // exactly one framing may satisfy it. A capture taken while the
        // rotation animation is still settling calibrates as none or as
        // several, so the capture retries until one framing fits.
        var screen: CGImage?
        var width = 0, height = 0
        var framing: Int?
        func rotate(_ p: CGPoint, by k: Int) -> CGPoint {
            switch k {
            case 1: return CGPoint(x: CGFloat(height) - p.y, y: p.x)
            case 2: return CGPoint(x: CGFloat(width) - p.x,
                                   y: CGFloat(height) - p.y)
            case 3: return CGPoint(x: p.y, y: CGFloat(width) - p.x)
            default: return p
            }
        }
        func rotatedSize(_ k: Int) -> CGSize {
            k % 2 == 0 ? CGSize(width: width, height: height)
                       : CGSize(width: height, height: width)
        }
        var lastDiagnostic = "no capture attempted"
        for attempt in 1...5 {
            if attempt > 1 { Thread.sleep(forTimeInterval: 1.5) }
            // The screen, not the app element: in landscape the element
            // screenshot composites the portrait-framed framebuffer
            // unrotated into a landscape canvas — scaled, clipped and
            // black-padded — while the screen screenshot returns the raw
            // framebuffer. The framing calibration exists precisely so
            // this claim never depends on how that framebuffer is held.
            let shot = XCUIScreen.main.screenshot()
            guard let candidateImage = shot.image.cgImage else { continue }
            width = candidateImage.width
            height = candidateImage.height

            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            try VNImageRequestHandler(cgImage: candidateImage, orientation: .up)
                .perform([request])
            func recognizedCenter(of needle: String) -> CGPoint? {
                for observation in request.results ?? [] {
                    guard let candidate = observation.topCandidates(1).first,
                          candidate.string
                              .localizedCaseInsensitiveContains(needle)
                    else { continue }
                    let box = observation.boundingBox
                    return CGPoint(x: box.midX * CGFloat(width),
                                   y: (1 - box.midY) * CGFloat(height))
                }
                return nil
            }
            guard let dateAnchor = recognizedCenter(of: "July")
                    ?? recognizedCenter(of: "Sundial"),
                  let stationAnchor = recognizedCenter(of: "Altar Stone")
                    ?? recognizedCenter(of: "Heel Stone") else {
                lastDiagnostic = "anchor text unreadable in capture "
                    + "\(width)x\(height)"
                continue
            }
            var candidates: [Int] = []
            for k in 0..<4 {
                let date = rotate(dateAnchor, by: k)
                let station = rotate(stationAnchor, by: k)
                let size = rotatedSize(k)
                if date.y < size.height * 0.45,
                   station.y > size.height * 0.6 {
                    candidates.append(k)
                }
            }
            lastDiagnostic = "candidates \(candidates), capture "
                + "\(width)x\(height), date \(dateAnchor), station "
                + "\(stationAnchor), app frame \(app.frame)"
            if candidates.count == 1 {
                screen = candidateImage
                framing = candidates.first
                let attachment = XCTAttachment(screenshot: shot)
                attachment.lifetime = .keepAlways
                attachment.name = "rebuild-card-\(orientation.rawValue)"
                add(attachment)
                break
            }
        }
        guard let screen, let framing else {
            XCTFail("no capture calibrated to a single framing — "
                    + lastDiagnostic)
            return
        }

        // ── layout truth: where the card claims to be ───────────────────
        let scale = rotatedSize(framing).width / app.frame.width
        XCTAssertGreaterThan(scale, 0.5, "implausible capture scale")
        let claimed = CGPoint(x: cardText.frame.midX * scale,
                              y: cardText.frame.midY * scale)

        // ── render truth: where the bronze bar actually drew ────────────
        // The pinned bar is 180 points long, 40% filled with the theme's
        // bronze — a band no glyph or chip nearby can imitate in width.
        // Histogram bronze pixels by row in the card's neighbourhood; the
        // densest row is the bar.
        guard let buffer = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            XCTFail("could not rasterise the screenshot")
            return
        }
        buffer.draw(screen, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let raw = buffer.data?.assumingMemoryBound(to: UInt8.self) else {
            XCTFail("the rasterised screenshot has no bytes")
            return
        }
        let windowX = 100 * scale, windowY = 50 * scale
        var rows: [Int: Int] = [:]
        for y in 0..<height {
            for x in 0..<width {
                let p = (y * width + x) * 4
                let r = Int(raw[p]), g = Int(raw[p + 1]), b = Int(raw[p + 2])
                // Bronze in either appearance: warm mid-brown, well away
                // from the sandy day bar and the pale plates.
                guard r > 110, r < 210, g > 75, g < 160, b < 90,
                      r > g + 25, g > b + 25 else { continue }
                let q = rotate(CGPoint(x: CGFloat(x), y: CGFloat(y)), by: framing)
                let dy = q.y - claimed.y
                if abs(q.x - claimed.x) < windowX && abs(dy) < windowY {
                    rows[Int(dy), default: 0] += 1
                }
            }
        }
        // 40% of 180 points of bar; ask for a comfortable majority of it.
        let barThreshold = Int(45 * scale)
        guard let bar = rows.max(by: { $0.value < $1.value }),
              bar.value > barThreshold else {
            XCTFail("no bar-like band of bronze near the card (densest row "
                    + "\(rows.values.max() ?? 0) px, needed \(barThreshold)) — "
                    + "the card did not render where its layout claims")
            return
        }

        // ── the claim ────────────────────────────────────────────────────
        // In the card's layout the bar sits below the text. A render
        // rotated 180° puts it above; rotated 90°, beside. Either way this
        // sign flips or collapses.
        XCTAssertGreaterThan(
            CGFloat(bar.key), 5 * scale,
            "the progress bar drew \(bar.key) px from the card text where "
            + "layout puts it about \(Int(14 * scale)) px below — the card "
            + "is rendering rotated against its own layout")
    }
}
