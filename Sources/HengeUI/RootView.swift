import SwiftUI
import HengeAstro
import HengeGeometry

/// The screen: the light on the stones, and the numbers that prove it.
///
/// The chrome went through one reorganisation worth recording. It used to be a
/// single floating slab of controls with sliders for bearing, height and range
/// — a navigation overlay sitting on top of the monument, in front of the thing
/// it was meant to help you look at. Two problems with that. It occupied the
/// bottom third of the sky at exactly the hour the sky is worth watching, and
/// the sliders duplicated gestures that already existed: drag turns the view,
/// pinch pulls it in. A control that does what your thumb already does is not
/// a control, it is furniture.
///
/// So: **where you stand is a tab bar**, because it is a choice between four
/// places rather than a continuum, and the fine adjustment stays on the
/// gestures. Everything else is glass, which means the panels take their colour
/// from the sunrise behind them instead of asserting one of their own.
public struct RootView: View {

    @State private var model = SkyModel()
    @State private var lastTick = Date()
    /// Gestures report a running total, so the previous value is kept to turn
    /// that into a per-frame delta. Without it a slow drag accelerates.
    @State private var lastDrag: CGSize = .zero
    @State private var lastZoom: CGFloat = 1
    @State private var showingLore = false
    @State private var showingAlmanac = true
    /// MISSION.md invariant 7. Time-lapse is the app's one continuous motion,
    /// and at 100,000× the whole sky wheels — which is exactly the kind of
    /// thing this setting exists to stop. Honoured by capping the rate rather
    /// than by disabling the feature: the calendar still runs, it just does
    /// not spin.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public var body: some View {
        ZStack(alignment: .bottom) {
            scene

            HengeGlass(spacing: 14) {
                VStack(spacing: 10) {
                    if showingAlmanac { events }
                    timeBar
                    stations
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
        .overlay(alignment: .topLeading) {
            if showingAlmanac { HengeGlass { almanac }.padding(16) }
        }
        .overlay(alignment: .topTrailing) { HengeGlass { almanacToggle }.padding(16) }
        .foregroundStyle(Henge.stone)
        .tint(Henge.bronze)
        .task { await runClock() }
        .sheet(isPresented: $showingLore) {
            // The coming station first, then the monument itself — so the panel
            // opens on whatever the user was just looking at.
            LoreView(notes: [model.stationNote] + Lore.monument)
                // The sheet is glass too, so the monument stays faintly
                // present behind the reading rather than being boxed out.
                .presentationBackground(.ultraThinMaterial)
        }
    }

    // ── the monument ────────────────────────────────────────────────────────

    private var scene: some View {
        HengeSceneView(model: model)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            // Composed with `simultaneously` rather than stacked as a
            // `.gesture` plus a `.simultaneousGesture`. Stacked, the drag —
            // which has `minimumDistance: 0` and so claims the very first touch
            // — would start tracking a pinch's first finger and swing the view
            // while the other finger was still arriving. Composed, SwiftUI
            // resolves them as one recognition and the pinch reads cleanly.
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        model.drag(by: SIMD2(Double(value.translation.width - lastDrag.width),
                                             Double(value.translation.height - lastDrag.height)))
                        lastDrag = value.translation
                    }
                    .onEnded { _ in lastDrag = .zero }
                    .simultaneously(with:
                        MagnifyGesture(minimumScaleDelta: 0)
                            .onChanged { value in
                                let magnification = Double(value.magnification)
                                guard magnification > 0, lastZoom > 0 else { return }
                                model.zoom(by: magnification / Double(lastZoom))
                                lastZoom = value.magnification
                            }
                            .onEnded { _ in lastZoom = 1 }
                    )
            )
            // Recentre lost its button along with the slider panel, so it
            // becomes what it should always have been: the gesture you already
            // try when a view has drifted.
            .onTapGesture(count: 2) {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) {
                    model.recentre()
                }
            }
            .accessibilityLabel("The monument")
            .accessibilityHint("Drag to look around, pinch or scroll to zoom, "
                               + "double tap to recentre")
            .accessibilityAction(named: "Recentre") { model.recentre() }
            // VoiceOver cannot pinch. Zoom has to be reachable as an action or
            // it does not exist for anyone using it — invariant 7.
            .accessibilityAction(named: "Zoom in") { model.zoom(by: 1.25) }
            .accessibilityAction(named: "Zoom out") { model.zoom(by: 0.8) }
            .modifier(ScrollZoom { model.zoom(by: $0) })
    }

    // ── where you stand ─────────────────────────────────────────────────────

    /// The four places, as a tab bar.
    ///
    /// These are *stations*, not camera presets — three of them put you on the
    /// ground at eye height in a spot that means something, and the fourth
    /// lifts you off it. Naming them after the stones rather than after camera
    /// positions is the whole point: you are choosing where to stand.
    private var stations: some View {
        HStack(spacing: 6) {
            ForEach(SkyModel.Station.allCases) { station in
                Button {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                        model.station = station
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: symbol(for: station))
                            .font(.system(size: 17))
                        Text(station.rawValue)
                            .font(Henge.body(.caption2))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .foregroundStyle(model.station == station ? Henge.bronze : Henge.stone)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(station.rawValue)
                .accessibilityAddTraits(model.station == station ? [.isSelected] : [])
            }
        }
        .padding(.horizontal, 6)
        .hengePanel(cornerRadius: 22)
    }

    private func symbol(for station: SkyModel.Station) -> String {
        switch station {
        case .aerial: "eye"
        case .altarStone: "figure.stand"
        case .heelStone: "triangle"
        case .avenue: "arrow.up.forward"
        }
    }

    // ── time ────────────────────────────────────────────────────────────────

    /// The rates worth having, as steps rather than a slider.
    ///
    /// A logarithmic slider spent most of its travel in speeds where nothing is
    /// legible. These are the four that mean something: real time, a minute a
    /// second (a day in twenty-four), an hour a second (a year in a day), and a
    /// day a second (the wheel turning).
    private static let rates: [(label: String, value: Double)] = [
        ("1×", 1), ("min", 60), ("hour", 3600), ("day", 86_400)
    ]

    private var timeBar: some View {
        HStack(spacing: 8) {
            Button {
                model.isPlaying.toggle()
            } label: {
                Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                    .frame(width: 34, height: 30)
            }
            .buttonStyle(.plain)
            .hengeControl()
            .accessibilityLabel(model.isPlaying ? "Pause time" : "Run time forward")

            ForEach(Self.rates, id: \.label) { rate in
                let allowed = !reduceMotion || rate.value <= 100
                Button(rate.label) { model.rate = rate.value }
                    .font(Henge.figure(.caption2))
                    .padding(.horizontal, 9).padding(.vertical, 7)
                    .hengeControl(isSelected: abs(model.rate - rate.value) < 0.5)
                    .buttonStyle(.plain)
                    .disabled(!allowed)
                    .opacity(allowed ? 1 : 0.35)
                    .accessibilityLabel("\(rate.label) per second")
                    .accessibilityHint(allowed ? "" : "Unavailable while Reduce Motion is on")
            }

            Spacer(minLength: 0)

            Button { model.jump(toDaysFromNow: -1) } label: {
                Image(systemName: "chevron.left").frame(width: 28, height: 30)
            }
            .buttonStyle(.plain).hengeControl()
            .accessibilityLabel("Back one day")

            Button("Now") { model.time = JulianDay(Date()) }
                .font(Henge.body(.caption))
                .padding(.horizontal, 10).padding(.vertical, 7)
                .hengeControl()
                .buttonStyle(.plain)

            Button { model.jump(toDaysFromNow: 1) } label: {
                Image(systemName: "chevron.right").frame(width: 28, height: 30)
            }
            .buttonStyle(.plain).hengeControl()
            .accessibilityLabel("Forward one day")

            Button { showingLore = true } label: {
                Image(systemName: "book.closed").frame(width: 34, height: 30)
            }
            .buttonStyle(.plain).hengeControl()
            .accessibilityLabel("Lore")
            .accessibilityHint("What is known, what is argued, and what is modern "
                               + "tradition — each with its sources")
        }
        .padding(8)
        .hengePanel()
    }

    // ── what is coming ──────────────────────────────────────────────────────

    /// The wheel of the year and the events on it, in one scrolling band.
    ///
    /// Scrolls rather than truncates: an eclipse season puts three events in a
    /// fortnight and a quiet stretch puts four in as many months, and flattening
    /// that to a fixed count would hide exactly the clustering that makes the
    /// sky legible.
    private var events: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(WheelStation.allCases) { station in
                        Button(station.name) { model.jumpToSunrise(of: station) }
                            .font(Henge.body(.caption2))
                            .padding(.horizontal, 9).padding(.vertical, 6)
                            .hengeControl()
                            .buttonStyle(.plain)
                            .accessibilityLabel("Jump to \(station.name) sunrise")
                            .accessibilityHint(Lore.note(for: station).tier.rawValue)
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(model.upcoming.prefix(20)) { event in
                        ribbonButton(for: event)
                    }
                }
            }
        }
        .padding(10)
        .hengePanel()
    }

    private func ribbonButton(for event: AstronomicalEvent) -> some View {
        let days = Int((event.instant.value - model.time.value).rounded())
        return Button {
            model.time = event.instant
        } label: {
            VStack(spacing: 1) {
                Text(event.kind.name).font(Henge.body(.caption2))
                Text("\(days) d").font(Henge.figure(.caption2)).opacity(0.7)
            }
            .padding(.horizontal, 9).padding(.vertical, 5)
            .foregroundStyle(isEclipse(event) ? Henge.bronze : Henge.stone)
        }
        .buttonStyle(.plain)
        .hengeControl()
        .accessibilityLabel("\(event.kind.name), in \(days) days")
    }

    private func isEclipse(_ event: AstronomicalEvent) -> Bool {
        if case .eclipsePossible = event.kind { return true }
        return false
    }

    // ── the almanac ─────────────────────────────────────────────────────────

    private var almanacToggle: some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                showingAlmanac.toggle()
            }
        } label: {
            Image(systemName: showingAlmanac ? "text.justify" : "text.alignleft")
                .frame(width: 36, height: 32)
        }
        .buttonStyle(.plain)
        .hengeControl()
        .foregroundStyle(Henge.stone)
        .accessibilityLabel(showingAlmanac ? "Hide the almanac" : "Show the almanac")
    }

    private var almanac: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.formattedDate)
                .font(Henge.title(.title3))
            // Local time first: it is the time at the monument, which is what
            // anyone standing there wants. UT stays visible underneath because
            // it is what the ephemeris is actually computed in.
            Text(model.formattedLocalTime ?? model.formattedSolarTime)
                .font(Henge.figure(.callout))
            Text(model.formattedLocalTime == nil
                 ? "local apparent solar time" : model.formattedTime)
                .font(Henge.figure(.caption2))
                .opacity(0.65)

            rule

            row("Sundial", model.formattedSolarTime)
            row("Sun over", model.viewpoint == .here
                ? SkyModel.deviceSite.name : "Stonehenge")
            row("Sun altitude", String(format: "%.3f°", model.sun.altitude.degrees))
            row("Sun azimuth", String(format: "%.3f°", model.sun.azimuth.degrees))
            if let sunrise = model.sunriseAzimuth {
                row("Sunrise bearing", String(format: "%.2f°", sunrise.degrees))
            }

            rule

            row("Moon", model.moonPhase.name)
            row("Lit", String(format: "%.0f%%", model.moonPhase.illuminatedFraction * 100))
            row("Moon altitude", String(format: "%.2f°", model.moon.altitude.degrees))
            row("Lunar swing", model.standstill)
            row("Pole star", model.poleStar)
            row("Aubrey", String(format: "%.1f holes to node", model.aubrey.sunToNode))
            if model.isAubreyEclipseSeason {
                row("", "eclipse season — hypothesis")
            }

            rule

            // Live alignment: how far off the line the sun is right now, not
            // whether today happens to be the right date.
            ForEach(model.alignments, id: \.alignment) { entry in
                HStack(spacing: 10) {
                    Text(entry.alignment.name)
                        .font(Henge.body(.caption))
                        .opacity(0.75)
                    Spacer(minLength: 12)
                    Text(String(format: "%.2f°", entry.deviation.degrees))
                        .font(Henge.figure(.caption))
                        .foregroundStyle(entry.isOn ? Henge.mistletoe : Henge.stone)
                }
                .frame(maxWidth: 260, alignment: .leading)
            }

            // The two viewpoint choices and the two states of the monument,
            // demoted to the bottom of the almanac: they are read far less
            // often than they were reached for when they sat in the main bar.
            HStack(spacing: 6) {
                ForEach(SkyModel.Viewpoint.allCases) { viewpoint in
                    Button(viewpoint.rawValue) { model.viewpoint = viewpoint }
                        .font(Henge.body(.caption2))
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .hengeControl(isSelected: model.viewpoint == viewpoint)
                        .buttonStyle(.plain)
                }
                Button(model.monumentState == .asItStands ? "Ruin" : "Whole") {
                    model.monumentState = model.monumentState == .asItStands
                        ? .asItWas : .asItStands
                }
                .font(Henge.body(.caption2))
                .padding(.horizontal, 8).padding(.vertical, 5)
                .hengeControl()
                .buttonStyle(.plain)
                .accessibilityHint("Switch between the completed monument and the ruin")
            }
            .padding(.top, 8)
        }
        .padding(14)
        .hengePanel()
    }

    private var rule: some View {
        Rectangle()
            .fill(Henge.stone.opacity(0.22))
            .frame(width: 180, height: 1)
            .padding(.vertical, 5)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(Henge.body(.caption))
                .opacity(0.7)
            Spacer(minLength: 12)
            Text(value)
                .font(Henge.figure(.caption))
                .monospacedDigit()
        }
        // No fixed width: at the larger Dynamic Type sizes a 210-point row
        // clipped the value. The label and value now size themselves and the
        // panel grows, which is what Dynamic Type is for.
        .frame(maxWidth: 260, alignment: .leading)
    }

    // ── the clock ───────────────────────────────────────────────────────────

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
