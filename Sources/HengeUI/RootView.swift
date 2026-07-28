import SwiftUI
import HengeAstro
import HengeGeometry

/// M1's screen: the light on the stones, and the numbers that prove it.
///
/// The Wheel of the Year replaces these controls at M4. What matters now is
/// that every value shown is read from the same `SkyModel` the renderer draws
/// from, so there is no way for the picture and the almanac to disagree.
public struct RootView: View {

    @State private var model = SkyModel()
    @State private var lastTick = Date()
    /// Gestures report a running total, so the previous value is kept to turn
    /// that into a per-frame delta. Without it a slow drag accelerates.
    @State private var lastDrag: CGSize = .zero
    @State private var lastZoom: CGFloat = 1
    @State private var showingLore = false
    /// MISSION.md invariant 7. Time-lapse is the app's one continuous motion,
    /// and at 100,000× the whole sky wheels — which is exactly the kind of
    /// thing this setting exists to stop. Honoured by capping the rate rather
    /// than by disabling the feature: the calendar still runs, it just does
    /// not spin.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public var body: some View {
        ZStack(alignment: .bottom) {
            HengeSceneView(model: model)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            model.drag(by: SIMD2(Double(value.translation.width - lastDrag.width),
                                                 Double(value.translation.height - lastDrag.height)))
                            lastDrag = value.translation
                        }
                        .onEnded { _ in lastDrag = .zero }
                )
                .simultaneousGesture(
                    MagnifyGesture()
                        .onChanged { value in
                            model.zoom(by: Double(value.magnification / lastZoom))
                            lastZoom = value.magnification
                        }
                        .onEnded { _ in lastZoom = 1 }
                )
                .accessibilityLabel("The monument")
                .accessibilityHint("Drag to look around, pinch to zoom")

            controls
                .padding(18)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(16)
        }
        .overlay(alignment: .topLeading) { readout.padding(20) }
        .task { await runClock() }
        .sheet(isPresented: $showingLore) {
            // The coming station first, then the monument itself — so the panel
            // opens on whatever the user was just looking at.
            LoreView(notes: [model.stationNote] + Lore.monument)
        }
    }

    // ── the almanac readout ─────────────────────────────────────────────────

    private var readout: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.formattedDate)
                .font(.title3.weight(.semibold))
            // Local time first: it is the time at the monument, which is what
            // anyone standing there wants. UT stays visible underneath because
            // it is what the ephemeris is actually computed in.
            Text(model.formattedLocalTime ?? model.formattedSolarTime)
                .font(.system(.callout, design: .monospaced))
            Text(model.formattedLocalTime == nil
                 ? "local apparent solar time" : model.formattedTime)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)

            Divider().frame(width: 190).padding(.vertical, 6)

            row("Sundial", model.formattedSolarTime)
            row("Sun over", model.viewpoint == .here
                ? SkyModel.deviceSite.name : "Stonehenge")
            row("Sun altitude", String(format: "%.3f°", model.sun.altitude.degrees))
            row("Sun azimuth", String(format: "%.3f°", model.sun.azimuth.degrees))
            if let sunrise = model.sunriseAzimuth {
                row("Sunrise bearing", String(format: "%.2f°", sunrise.degrees))
            }
            Divider().frame(width: 190).padding(.vertical, 6)

            row("Moon", model.moonPhase.name)
            row("Lit", String(format: "%.0f%%",
                              model.moonPhase.illuminatedFraction * 100))
            row("Moon altitude", String(format: "%.2f°", model.moon.altitude.degrees))
            row("Lunar swing", model.standstill)
            row("Pole star", model.poleStar)

            Divider().frame(width: 190).padding(.vertical, 6)

            row("Next", model.formattedNextStation)
            // The Aubrey counter, in the ring's own units. "Holes to a node" is
            // the only thing it can honestly say, so it is the only thing shown.
            row("Aubrey", String(format: "%.1f holes to node", model.aubrey.sunToNode))
            if model.isAubreyEclipseSeason {
                row("", "eclipse season — hypothesis")
            }

            Divider().frame(width: 190).padding(.vertical, 6)

            // Live alignment: how far off the line the sun is right now, not
            // whether today happens to be the right date.
            ForEach(model.alignments, id: \.alignment) { entry in
                row(entry.alignment.name + (entry.isOn ? " ●" : ""),
                    String(format: "%.2f° off", entry.deviation.degrees))
            }

            if let deviation = model.axisDeviation {
                row("Off the axis", String(format: "%.2f°", deviation.degrees))
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Almanac for \(model.formattedDate) at \(model.formattedTime)")
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .monospacedDigit()
        }
        // No fixed width: at the larger Dynamic Type sizes a 210-point row
        // clipped the value. The label and value now size themselves and the
        // panel grows, which is what Dynamic Type is for.
        .frame(maxWidth: 260, alignment: .leading)
    }

    // ── time and camera ─────────────────────────────────────────────────────

    private var controls: some View {
        VStack(spacing: 14) {
            Picker("Sun", selection: $model.viewpoint) {
                ForEach(SkyModel.Viewpoint.allCases) { viewpoint in
                    Text(viewpoint.rawValue).tag(viewpoint)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Whose sun to show")
            .accessibilityHint("Here uses this device's time zone, so solar noon "
                               + "falls when the sun is overhead where you are")

            Picker("Station", selection: $model.station) {
                ForEach(SkyModel.Station.allCases) { station in
                    Text(station.rawValue).tag(station)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Where you are standing")

            Toggle("As it stands", isOn: Binding(
                get: { model.monumentState == .asItStands },
                set: { model.monumentState = $0 ? .asItStands : .asItWas }
            ))
            .toggleStyle(.button)
            .accessibilityHint("Switch between the completed monument and the ruin")

            wheel
            ribbon

            HStack(spacing: 14) {
                Button {
                    model.isPlaying.toggle()
                } label: {
                    Label(model.isPlaying ? "Pause" : "Play",
                          systemImage: model.isPlaying ? "pause.fill" : "play.fill")
                }
                .accessibilityLabel(model.isPlaying ? "Pause time" : "Run time forward")

                Button("Now") { model.time = JulianDay(Date()) }
                Button("Lore") { showingLore = true }
                    .accessibilityHint("What is known, what is argued, and what is "
                                       + "modern tradition — each with its sources")
                Button("Recentre") { model.recentre() }

                Button("−1 day") { model.jump(toDaysFromNow: -1) }
                Button("+1 day") { model.jump(toDaysFromNow: 1) }
            }
            .buttonStyle(.bordered)

            labelled("Rate", String(format: "%.0f×", model.rate)) {
                // Logarithmic: the interesting rates span five orders of
                // magnitude, and a linear slider would spend all its travel
                // in the fast end where nothing is legible.
                Slider(value: Binding(
                    get: { log10(max(model.rate, 1)) },
                    set: { model.rate = pow(10, $0) }
                ), in: 0...(reduceMotion ? 2 : 5))
                .accessibilityHint(reduceMotion
                    ? "Limited to 100× because Reduce Motion is on"
                    : "How fast time runs, up to a hundred thousand times")
            }

            if model.station == .aerial {
                labelled("Bearing", String(format: "%.0f°", model.cameraAzimuth)) {
                    Slider(value: $model.cameraAzimuth, in: 0...360)
                }

                labelled("Height", String(format: "%.0f°", model.cameraElevation)) {
                    Slider(value: $model.cameraElevation, in: -2...80)
                }

                labelled("Range", String(format: "%.0f m", model.cameraDistance)) {
                    Slider(value: $model.cameraDistance, in: 25...260)
                }
            }
        }
        .frame(maxWidth: 460)
    }

    // ── the wheel of the year ───────────────────────────────────────────────

    /// Eight stations, and a jump that lands on the sunrise of each rather than
    /// on midnight of a calendar date. The tier badge is not decoration: four of
    /// these eight are modern tradition and the app says so at the point of use,
    /// not in a disclaimer nobody reads.
    private var wheel: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(WheelStation.allCases) { station in
                    Button(station.name) { model.jumpToSunrise(of: station) }
                        .font(.caption2)
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Jump to \(station.name) sunrise")
                        .accessibilityHint(Lore.note(for: station).tier.rawValue)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            let note = model.stationNote
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(note.tier.shortLabel.uppercased())
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(tint(for: note.tier), in: Capsule())
                Text(note.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(note.title). \(note.tier.rawValue).")
        }
    }

    /// What is coming, in the order it comes.
    ///
    /// Scrolls rather than truncates: an eclipse season puts three events in a
    /// fortnight and a quiet stretch puts four in as many months, and flattening
    /// that to a fixed count would hide exactly the clustering that makes the
    /// sky legible.
    private var ribbon: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.upcoming.prefix(24)) { event in
                    ribbonButton(for: event)
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(height: 44)
    }

    /// Split out of `ribbon` because the type-checker times out on the label
    /// builder when the string formatting is inlined into the ForEach.
    private func ribbonButton(for event: AstronomicalEvent) -> some View {
        let days = Int((event.instant.value - model.time.value).rounded())
        return Button {
            model.time = event.instant
        } label: {
            VStack(spacing: 1) {
                Text(event.kind.name)
                    .font(.caption2)
                Text("\(days) d")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.bordered)
        .tint(isEclipse(event) ? Color.orange : Color.accentColor)
        .accessibilityLabel("\(event.kind.name), in \(days) days")
    }

    private func isEclipse(_ event: AstronomicalEvent) -> Bool {
        if case .eclipsePossible = event.kind { return true }
        return false
    }

    private func tint(for tier: LoreTier) -> some ShapeStyle {
        switch tier {
        case .established: Color.green.opacity(0.25)
        case .debated: Color.orange.opacity(0.25)
        case .modernTradition: Color.purple.opacity(0.25)
        }
    }

    private func labelled<Control: View>(_ title: String, _ value: String,
                                         @ViewBuilder control: () -> Control) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .leading)
            control()
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .monospacedDigit()
                .frame(width: 56, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }

    /// Drive the time-lapse from a clock rather than from frame callbacks, so
    /// the rate means the same thing whether the display runs at 60 or 120 Hz.
    private func runClock() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(16))
            let now = Date()
            let elapsed = now.timeIntervalSince(lastTick)
            lastTick = now
            // Clamp on the way in too, so a rate restored from a previous
            // session cannot outrun the setting.
            if reduceMotion { model.rate = min(model.rate, 100) }
            model.advance(byRealSeconds: elapsed)
        }
    }
}
