import SwiftUI
import HengeAstro

/// Where we are in the year, as a bar you can drag — the day bar's sibling,
/// one octave down.
///
/// The whole civil year, coloured by season between the sun's own quarter
/// days, with the wheel's eight stations and every syzygy marked along it.
/// The marks are lights, deliberately: the ceremonial days burn bronze and
/// the full moons burn pale, each with a halo, because they are the points
/// you navigate the year by. A new moon is a dark bead with no halo — a new
/// moon does not shine, and the bar does not pretend otherwise.
///
/// The seasons are bounded by the solved equinoxes and solstices rather than
/// by month edges: the sun decides where spring begins on this instrument,
/// not the calendar page. Quarter stations wear a ring rather than a filled
/// bead — they are astronomy; the filled cross-quarters are ceremony, and
/// the two registers stay visually distinct the same way the lore tiers do.
public struct YearBar: View {

    @Bindable var model: SkyModel

    public init(model: SkyModel) {
        self.model = model
    }

    /// Winter, spring, summer, autumn — the sward's own year, muted to sit
    /// on glass: grey-green cold, fresh growth, dry gold, tawny seed.
    static let seasonColours: [Color] = [
        Color(red: 0.47, green: 0.53, blue: 0.58),
        Color(red: 0.55, green: 0.68, blue: 0.42),
        Color(red: 0.86, green: 0.77, blue: 0.48),
        Color(red: 0.76, green: 0.58, blue: 0.36)
    ]
    /// Computed, not stored: a `static let` freezes whichever language
    /// was current when it was first touched.
    static var seasonNames: [String] {
        [L10n.string("season.name.winter"), L10n.string("season.name.spring"),
         L10n.string("season.name.summer"), L10n.string("season.name.autumn")]
    }

    public var body: some View {
        let year = model.yearAlmanac
        let stations = year.stations.map { entry in
            (station: entry.station,
             fraction: year.fraction(of: entry.instant))
        }
        // The four quarter days split the strip: winter | spring | summer |
        // autumn | winter again.
        let quarterFractions = stations
            .filter { isQuarter($0.station) }
            .map(\.fraction)
            .sorted()

        VStack(spacing: 2) {
            labelRow(for: stations, parity: 0)
            GeometryReader { geometry in
                let width = geometry.size.width
                ZStack(alignment: .leading) {
                    seasonBand(quarters: quarterFractions, width: width)

                    ForEach(Array(year.newMoons.enumerated()), id: \.offset) { _, moon in
                        moonJump(to: moon,
                                 label: EventKind.newMoon.localizedName) { newMoonBead }
                            .position(x: width * year.fraction(of: moon), y: 9)
                    }
                    ForEach(Array(year.fullMoons.enumerated()), id: \.offset) { _, moon in
                        moonJump(to: moon,
                                 label: EventKind.fullMoon.localizedName) { fullMoonLamp }
                            .position(x: width * year.fraction(of: moon), y: 9)
                    }

                    ForEach(stations, id: \.station) { entry in
                        stationLight(entry.station)
                            .position(x: width * entry.fraction, y: 9)
                    }

                    nowCursor
                        .offset(x: max(0, min(width - 3,
                                              width * model.yearFraction - 1.5)))
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard width > 0 else { return }
                            model.isPlaying = false
                            model.scrubYear(toFraction: value.location.x / width)
                        }
                )
            }
            .frame(height: 18)
            labelRow(for: stations, parity: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("yearbar.label", bundle: .module))
        .accessibilityValue(model.formattedDate)
        .accessibilityHint(Text("yearbar.hint", bundle: .module))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: model.scrubYear(toFraction: model.yearFraction + 1.0 / 366)
            case .decrement: model.scrubYear(toFraction: model.yearFraction - 1.0 / 366)
            @unknown default: break
            }
        }
    }

    private func isQuarter(_ station: WheelStation) -> Bool {
        switch station {
        case .marchEquinox, .juneSolstice, .septemberEquinox, .decemberSolstice:
            true
        default:
            false
        }
    }

    // ── the band ────────────────────────────────────────────────────────────

    private func seasonBand(quarters: [Double], width: CGFloat) -> some View {
        // Boundaries: year start, the four quarter days, year end. The strip
        // opens and closes in winter. Proportional widths in an HStack, the
        // day bar's own construction — a ZStack of offset rectangles sizes
        // itself to one child and clips the rest away.
        let bounds = [0.0] + quarters + [1.0]
        let colourIndex = [0, 1, 2, 3, 0]
        return HStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { span in
                let spanWidth = width * (bounds[span + 1] - bounds[span])
                Self.seasonColours[colourIndex[span]].opacity(0.55)
                    .frame(width: max(0, spanWidth))
                    .overlay {
                        // The season's name, sensed rather than read, where
                        // the span is wide enough to carry it.
                        if spanWidth > 64 {
                            Text(Self.seasonNames[colourIndex[span]])
                                .font(Henge.body(.caption2))
                                .foregroundStyle(.white.opacity(0.6))
                                .fixedSize()
                        }
                    }
            }
        }
        .frame(height: 18)
        .clipShape(Capsule())
    }

    // ── the lights ──────────────────────────────────────────────────────────

    /// A ceremonial day burns; a quarter day is drawn. Filled bead with a
    /// bronze halo for the cross-quarters, a ring with a fainter halo for
    /// the equinoxes and solstices.
    private func stationLight(_ station: WheelStation) -> some View {
        Button {
            model.jumpToSunrise(of: station)
        } label: {
            Group {
                if isQuarter(station) {
                    Circle()
                        .strokeBorder(Henge.bronze, lineWidth: 1.5)
                        .frame(width: 8, height: 8)
                        .shadow(color: Henge.bronze.opacity(0.6), radius: 3)
                } else {
                    Circle()
                        .fill(Henge.bronze)
                        .frame(width: 7, height: 7)
                        .shadow(color: Henge.bronze.opacity(0.95), radius: 3)
                        .shadow(color: Henge.bronze.opacity(0.5), radius: 7)
                }
            }
            .frame(width: 26, height: 26)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("yearbar.jumpToSunrise \(station.localizedName)",
                                 bundle: .module))
    }

    /// A moon light is a jump: tapping it goes to the *moonrise* of that
    /// day — the owner's order — the way a station light goes to sunrise.
    private func moonJump(to instant: JulianDay, label: String,
                          @ViewBuilder mark: () -> some View) -> some View {
        Button {
            model.jumpToMoonrise(nearestTo: instant)
        } label: {
            mark()
                .frame(width: 20, height: 20)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        // Phrased so the name drops in whole. The English original lowercased
        // it to read naturally mid-sentence, which is a transformation with no
        // meaning in Japanese or Korean and the wrong one in German, where
        // the noun is capitalised on purpose.
        .accessibilityLabel(Text("yearbar.jumpToMoonrise \(label)",
                                 bundle: .module))
    }

    private var fullMoonLamp: some View {
        Circle()
            .fill(Color(red: 0.93, green: 0.93, blue: 0.88))
            .frame(width: 5, height: 5)
            .shadow(color: .white.opacity(0.9), radius: 2.5)
            .shadow(color: Color(red: 0.75, green: 0.8, blue: 1).opacity(0.6),
                    radius: 5)
            .allowsHitTesting(false)
    }

    private var newMoonBead: some View {
        Circle()
            .fill(Color.black.opacity(0.45))
            .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 0.5))
            .frame(width: 5, height: 5)
            .allowsHitTesting(false)
    }

    private var nowCursor: some View {
        Capsule()
            .fill(Henge.bronze)
            .frame(width: 3)
            .overlay(
                Circle()
                    .fill(Henge.bronze)
                    .frame(width: 11, height: 11)
                    .shadow(color: Henge.bronze.opacity(0.9), radius: 4)
                    .shadow(color: Henge.bronze.opacity(0.45), radius: 9)
            )
            .allowsHitTesting(false)
    }

    // ── the names ───────────────────────────────────────────────────────────

    /// Half the stations name themselves above the band and half below, so
    /// eight names fit a phone's width without touching. The *marks* stay at
    /// their true dates; a name tag may shuffle a few points sideways to
    /// clear its neighbour — a label is a label, not a measurement.
    private func labelRow(for stations: [(station: WheelStation, fraction: Double)],
                          parity: Int) -> some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let row = stations.enumerated()
                .filter { $0.offset % 2 == parity }
                .map { (station: $0.element.station, fraction: $0.element.fraction) }
            let xs = resolvedLabelCentres(for: row, width: width)
            ForEach(Array(row.enumerated()), id: \.element.station) { index, entry in
                Text(entry.station.localizedName)
                    .font(Henge.body(.caption2))
                    .opacity(Henge.Ink.faint)
                    .fixedSize()
                    .position(x: xs[index], y: 7)
            }
        }
        .frame(height: 14)
    }

    /// A serif caption's width, estimated well enough to keep names apart.
    private func labelHalfWidth(_ station: WheelStation) -> CGFloat {
        // Measured off the *translated* name: "Frühlingstagundnachtgleiche"
        // needs more of the bar than "Spring equinox" does, and reserving
        // the English width would overlap its neighbours in half the
        // languages the app now ships in.
        CGFloat(station.localizedName.count) * 3.1 + 4
    }

    /// Centres for a row of labels: pinned inside the edges, then swept
    /// right-to-left so no name touches the one after it.
    private func resolvedLabelCentres(
        for row: [(station: WheelStation, fraction: Double)],
        width: CGFloat) -> [CGFloat] {
        var xs: [CGFloat] = row.map { entry in
            let half = labelHalfWidth(entry.station)
            return max(half, min(width - half, width * CGFloat(entry.fraction)))
        }
        guard xs.count > 1 else { return xs }
        for index in stride(from: xs.count - 2, through: 0, by: -1) {
            let limit = xs[index + 1] - labelHalfWidth(row[index + 1].station)
                - labelHalfWidth(row[index].station) - 6
            xs[index] = min(xs[index], limit)
        }
        return xs
    }
}
