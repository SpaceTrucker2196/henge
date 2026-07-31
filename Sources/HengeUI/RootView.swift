import SwiftUI
import HengeAstro
import HengeEngine
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
    @State private var showingTravel = false
    @State private var showingInfo = false
    @State private var showingAlmanac = true
    /// Whether each panel is on screen or slid away to its edge, leaving a
    /// handle. The monument is the point of the app; every piece of chrome
    /// should be dismissible to nothing but a handle.
    @State private var controlsDrawerOpen = true
    @State private var stripDrawerOpen = true
    @State private var railDrawerOpen = true
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

            // The control stack is a drawer: tap the handle at its left edge
            // and it slides off westward, leaving only the handle to bring
            // it back. The stones deserve the whole frame sometimes.
            if controlsDrawerOpen {
                HengeGlass(spacing: Henge.Space.margin) {
                    VStack(spacing: Henge.Space.panel) {
                        // The research note behind the marker mode is binding:
                        // "the mode must say so on screen, every time." A lore
                        // sheet the user may never open does not satisfy that,
                        // and neither does a VoiceOver hint — this chip is the
                        // on-screen badge, present exactly as long as the gold
                        // stones are.
                        if model.showsLunarMarkers { hypothesisBadge }
                        if showingAlmanac { events }
                        timeBar
                            // The tab lives *inside* the glass container and
                            // straddles the plate's edge, so the material
                            // merges the two into one silhouette — a pull on
                            // the drawer, not a chip floating beside it. It
                            // rides the time bar in particular because a tab
                            // centred over a stack of plates lands on a seam.
                            .overlay(alignment: .leading) {
                                drawerHandle(isOpen: true, edge: .leading,
                                             label: "Hide the control panels") {
                                    controlsDrawerOpen = false
                                }
                                .offset(x: drawerTabOverhang)
                            }
                        stations
                    }
                }
                .padding(.horizontal, Henge.Space.margin)
                .padding(.bottom, Henge.Space.panel)
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottomLeading) {
            if !controlsDrawerOpen {
                drawerHandle(isOpen: false, edge: .leading,
                             label: "Show the control panels") {
                    controlsDrawerOpen = true
                }
                // Flush with the screen edge, the way a closed drawer's tab
                // should be: the capsule touches the bezel and the hit
                // region runs off it — edge targets are the easy ones.
                .offset(x: drawerTabTuck)
                .padding(.bottom, 72)
            }
        }
        .overlay {
            // The named stars' labels, projected through the same camera the
            // sky is drawn with. The projection itself lives in HengeEngine
            // (`Camera.screenFraction`) where a test holds it; this layer
            // only places text. Not hit-testable — a label must never steal
            // a drag from the sky it annotates.
            if model.showsStarLabels {
                GeometryReader { proxy in
                    let aspect = proxy.size.height > 0
                        ? proxy.size.width / proxy.size.height : 1
                    ForEach(model.starLabels(aspect: Double(aspect))) { label in
                        Text(label.id)
                            .font(Henge.body(.caption2))
                            // Starlight, not the adaptive ink: these sit on
                            // the night sky, dark in every appearance.
                            .foregroundStyle(Henge.starlight.opacity(Henge.Ink.dim))
                            .shadow(color: .black.opacity(0.6), radius: 2)
                            .position(x: label.x * proxy.size.width,
                                      y: label.y * proxy.size.height - 12)
                    }
                }
                .allowsHitTesting(false)
            }
        }
        .overlay {
            // The ruin/whole switch rebuilds every stone; this card is the
            // honest account of that second. Not hit-testable — you can
            // keep looking around while the masons work.
            if let progress = model.rebuildProgress {
                VStack(spacing: Henge.Space.element) {
                    Text(model.monumentState == .asItWas
                         ? "Raising the stones" : "Four thousand years pass")
                        .font(Henge.body(.caption))
                    ProgressView(value: progress)
                        .tint(Henge.bronze)
                        .frame(width: 180)
                }
                .padding(Henge.Space.margin)
                // Material rather than glass — `hengeCard` records why: in
                // a landscape window the glass portal drew this very card
                // upside down.
                .hengeCard()
                .allowsHitTesting(false)
                .transition(.opacity)
            }
        }
        .overlay(alignment: .top) {
            // The almanac runs the width of the view: a reading strip tight
            // against the top edge, columns side by side, scrolling
            // horizontally where the screen is narrower than the day is
            // interesting. Vertical space is the monument's, not the
            // chrome's — the strip spends as little of it as legibility
            // allows. The toggle keeps its corner, so the strip stops short.
            if showingAlmanac, stripDrawerOpen {
                HengeGlass {
                    almanac
                        // Same construction as the control stack's tab: in
                        // the container, on the plate's edge, one material.
                        .overlay(alignment: .leading) {
                            drawerHandle(isOpen: true, edge: .leading,
                                         label: "Hide the almanac strip") {
                                stripDrawerOpen = false
                            }
                            .offset(x: drawerTabOverhang)
                        }
                }
                .padding(.top, 4)
                .padding(.leading, Henge.Space.panel)
                // The toggle rail's width plus a margin either side
                // — the strip stops where the rail begins.
                .padding(.trailing, Henge.Hit.control + Henge.Space.margin * 2)
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .overlay(alignment: .topLeading) {
            if showingAlmanac, !stripDrawerOpen {
                drawerHandle(isOpen: false, edge: .leading,
                             label: "Show the almanac strip") {
                    stripDrawerOpen = true
                }
                .offset(x: drawerTabTuck)
                .padding(.top, 8)
            }
        }
        .overlay(alignment: .topTrailing) {
            // The toggle rail is a drawer too, sliding toward its own edge —
            // rightward, because a drawer goes the way its wall faces.
            if railDrawerOpen {
                HengeGlass {
                    VStack(spacing: Henge.Space.tight) {
                        railHandle(isOpen: true)
                        almanacToggle
                        overlayToggle
                        markerToggle
                        torchToggle
                        weatherToggle
                        starLabelToggle
                        constellationToggle
                        zodiacToggle
                    }
                    .padding(.vertical, Henge.Space.tight)
                }
                .padding(Henge.Space.margin)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                railHandle(isOpen: false)
                    .padding(Henge.Space.margin)
                    .padding(.top, Henge.Space.tight)
            }
        }
        .foregroundStyle(Henge.stone)
        .tint(Henge.bronze)
        .task { await runClock() }
        .task {
            // The UI test's fixture (`BuildFlowUITests`): pin the rebuild
            // card open so the orientation inspection can read it at
            // leisure — the real card lives for about a second, long
            // enough to mislead a user and too short to screenshot
            // reliably. Re-asserted on a short loop because launch now
            // raises the stones through the same progress channel and
            // clears it on landing, which would un-pin a one-shot fixture.
            // Inert unless the harness asks for it by name.
            guard ProcessInfo.processInfo
                .environment["HENGE_UITEST_PIN_REBUILD_CARD"] != nil else {
                return
            }
            while !Task.isCancelled {
                model.rebuildProgress = 0.4
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
        .sheet(isPresented: $showingInfo) {
            InfoView()
                .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $showingTravel) {
            DateTravelView(initial: model.calendarDate) { date in
                model.time = JulianDay(date)
            }
            .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $showingLore) {
            // The coming station first, then the monument itself — so the panel
            // opens on whatever the user was just looking at.
            LoreView(notes: [model.stationNote] + Lore.monument)
                // The sheet is glass too, so the monument stays faintly
                // present behind the reading rather than being boxed out.
                .presentationBackground(.ultraThinMaterial)
        }
    }

    /// The width of a tab's visual capsule; the hit frame stays at the
    /// platform's 44-point floor around it.
    private static let drawerTabWidth: CGFloat = 14

    /// How far an open drawer's tab shifts so its capsule straddles the
    /// plate's leading edge — half on the glass, half in the margin. Inside
    /// the glass container that overlap merges the two shapes into one
    /// silhouette: a pull on the drawer's edge rather than a chip beside it.
    private var drawerTabOverhang: CGFloat {
        -(Henge.Hit.control - Self.drawerTabWidth) / 2 - Self.drawerTabWidth / 2
    }

    /// How far a *closed* tab shifts so its capsule sits flush against the
    /// screen edge, the way a closed drawer's tab should: touching the bezel,
    /// with the hit region running off it.
    private var drawerTabTuck: CGFloat {
        -(Henge.Hit.control - Self.drawerTabWidth) / 2
    }

    /// A drawer's handle: a slim capsule the eye reads as an edge-tab, with
    /// a hit region at the platform's 44-point floor — the visual may be
    /// fourteen points wide, but what it accepts must not be (the rail
    /// taught that lesson the same day this shipped). One builder for every
    /// panel, so the chevron grammar cannot drift: it always points the way
    /// the panel will go. Compact chevrons, because that is the system's own
    /// grabber glyph and the eye already knows what it means.
    private func drawerHandle(isOpen: Bool, edge: HorizontalEdge,
                              label: String,
                              toggle: @escaping () -> Void) -> some View {
        Button {
            withAnimation(Henge.settle(reduceMotion)) { toggle() }
        } label: {
            Image(systemName: (edge == .leading) == isOpen
                  ? "chevron.compact.left" : "chevron.compact.right")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: Self.drawerTabWidth, height: 56)
                .hengeControl()
                .opacity(Henge.Ink.dim)
                .frame(width: Henge.Hit.control, height: 64)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Henge.stone)
        .accessibilityLabel(label)
        .accessibilityHint("Slides the panel away to its edge; the handle "
                           + "stays to bring it back")
    }

    /// The rail's handle is one of its own pills — the first in the column,
    /// dressed exactly like the toggles below it. Collapsing leaves the pill
    /// where it stood and opening unfurls the toggles beneath it, so the
    /// handle never moves: a handle that stays put is a handle you can find
    /// again without looking.
    private func railHandle(isOpen: Bool) -> some View {
        Button {
            withAnimation(Henge.settle(reduceMotion)) { railDrawerOpen.toggle() }
        } label: {
            Image(systemName: isOpen
                  ? "chevron.compact.right" : "chevron.compact.left")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 36, height: 32)
                .hengeControl()
                .opacity(Henge.Ink.dim)
                .frame(width: Henge.Hit.control, height: Henge.Hit.controlHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Henge.stone)
        .accessibilityLabel(isOpen ? "Hide the mode toggles" : "Show the mode toggles")
        .accessibilityHint("Slides the toggle rail away to the right edge; "
                           + "the handle stays to bring it back")
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
                withAnimation(Henge.settle(reduceMotion)) {
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
                    withAnimation(Henge.settle(reduceMotion)) {
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
                    .hengeControl(isSelected: model.station == station)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(station.rawValue)
                .accessibilityAddTraits(model.station == station ? [.isSelected] : [])
            }

            // *When* you stand there rides beside *where*: whole monument
            // or today's ruin. It lived on the toggle rail once, but it is
            // a place-state like the stations, and the rail had grown past
            // what the sky leaves it room for.
            Rectangle()
                .fill(Henge.stone.opacity(Henge.Ink.hairline))
                .frame(width: 1, height: 34)
            monumentToggle
        }
        .padding(.horizontal, 6)
        .hengePanel()
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
        VStack(spacing: Henge.Space.panel) {
            DayBar(model: model)
            timeControls
        }
        .padding(Henge.Space.panel)
        .hengePanel()
    }

    private var timeControls: some View {
        // One row on a wide window, two on a phone: the row overflowed a
        // compact width and SwiftUI compressed the rate labels into
        // one-letter-per-line ribbons. ViewThatFits keeps both layouts
        // honest instead of letting either squeeze.
        ViewThatFits(in: .horizontal) {
            timeControlRow(split: false)
            timeControlRow(split: true)
        }
    }

    @ViewBuilder
    private func timeControlRow(split: Bool) -> some View {
        if split {
            VStack(alignment: .leading, spacing: Henge.Space.element) {
                HStack(spacing: Henge.Space.element) { playAndRates }
                HStack(spacing: Henge.Space.element) { jumpAndLore }
            }
        } else {
            HStack(spacing: Henge.Space.element) {
                playAndRates
                Spacer(minLength: 0)
                jumpAndLore
            }
        }
    }

    @ViewBuilder
    private var playAndRates: some View {
            // The play button is the row's one verb, and it was the row's
            // most cramped control. Full hit floor, and a clear gap before
            // the rates so a thumb aiming at "run" cannot land on "1×".
            Button {
                model.isPlaying.toggle()
            } label: {
                Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                    .frame(width: Henge.Hit.control, height: Henge.Hit.controlHeight)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .hengeControl()
            .accessibilityLabel(model.isPlaying ? "Pause time" : "Run time forward")
            .padding(.trailing, Henge.Space.element)

            ForEach(Self.rates, id: \.label) { rate in
                let allowed = !reduceMotion || rate.value <= 100
                Button(rate.label) { model.rate = rate.value }
                    .font(Henge.figure(.caption2))
                    .fixedSize()
                    .padding(.horizontal, 9).padding(.vertical, 7)
                    .hengeControl(isSelected: abs(model.rate - rate.value) < 0.5)
                    .buttonStyle(.plain)
                    .disabled(!allowed)
                    .opacity(allowed ? 1 : 0.35)
                    .accessibilityLabel("\(rate.label) per second")
                    .accessibilityHint(allowed ? "" : "Unavailable while Reduce Motion is on")
            }
    }

    @ViewBuilder
    private var jumpAndLore: some View {
            Button { model.jump(toDaysFromNow: -1) } label: {
                Image(systemName: "chevron.left").frame(width: 28, height: 30)
            }
            .buttonStyle(.plain).hengeControl()
            .accessibilityLabel("Back one day")

            Button("Now") { model.time = JulianDay(Date()) }
                .font(Henge.body(.caption))
                .fixedSize()
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

            Button { showingInfo = true } label: {
                Image(systemName: "info.circle").frame(width: 34, height: 30)
            }
            .buttonStyle(.plain).hengeControl()
            .accessibilityLabel("About and attributions")
            .accessibilityHint("What this app is, and the catalogues, "
                               + "surveys and algorithms it stands on")
    }

    // ── what is coming ──────────────────────────────────────────────────────

    /// The wheel of the year and the events on it, in one scrolling band.
    ///
    /// Scrolls rather than truncates: an eclipse season puts three events in a
    /// fortnight and a quiet stretch puts four in as many months, and flattening
    /// that to a fixed count would hide exactly the clustering that makes the
    /// sky legible.
    /// The year, as an instrument. What was two scrolling rows of chips is
    /// one bar: seasons as its colour, the wheel's days and the moons as
    /// lights along it, draggable like the day bar below it.
    private var events: some View {
        YearBar(model: model)
            .padding(.horizontal, Henge.Space.panel)
            .padding(.vertical, Henge.Space.element)
            .hengePanel()
    }

    // ── the almanac ─────────────────────────────────────────────────────────

    private var almanacToggle: some View {
        Button {
            withAnimation(Henge.quick(reduceMotion)) {
                showingAlmanac.toggle()
            }
        } label: {
            Image(systemName: showingAlmanac ? "text.justify" : "text.alignleft")
                .frame(width: 36, height: 32)
                .hengeControl()
                // The glass reads at thirty-six points; the finger gets
                // the full platform floor around it. Visual weight and
                // hit target are different budgets.
                .frame(width: Henge.Hit.control, height: Henge.Hit.controlHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Henge.stone)
        .accessibilityLabel(showingAlmanac ? "Hide the almanac" : "Show the almanac")
    }

    /// The reading strip. What was a tall corner panel is now columns across
    /// the top — when, sun, moon, sky, alignments, and the two switches —
    /// separated by hairlines, scrolling horizontally where the screen runs
    /// out before the columns do. Dynamic Type is served the same way as
    /// before: nothing has a fixed width, so a column grows and the strip
    /// simply scrolls sooner.
    /// The researched lines, drawn on the turf.
    private var overlayToggle: some View {
        Button {
            model.showsAlignmentOverlay.toggle()
        } label: {
            Image(systemName: "safari")
                .frame(width: 36, height: 32)
                .hengeControl(isSelected: model.showsAlignmentOverlay)
                // The glass reads at thirty-six points; the finger gets
                // the full platform floor around it. Visual weight and
                // hit target are different budgets.
                .frame(width: Henge.Hit.control, height: Henge.Hit.controlHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(model.showsAlignmentOverlay ? Henge.bronze : Henge.stone)
        .accessibilityLabel(model.showsAlignmentOverlay
                            ? "Hide the alignment lines" : "Show the alignment lines")
        .accessibilityHint("Cardinal directions, the solstice axis, the Avenue, "
                           + "and the Station Stone rectangle — the lore panel "
                           + "says which lines are established and which argued")
    }

    /// The badge that rides with the gold markers. Tier and source at the
    /// point of use — invariant 3, applied to a whole mode rather than a
    /// sentence.
    private var hypothesisBadge: some View {
        Label("Gold markers act out a modern hypothesis — Hoyle, 1966. Debated; see Lore.",
              systemImage: "record.circle")
            .font(Henge.body(.caption2))
            .foregroundStyle(Henge.bronze)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .hengePanel()
            .accessibilityHint("The Aubrey holes held cremated human remains; "
                               + "nothing excavated supports moving markers. "
                               + "The lore panel has the sources.")
    }

    /// The ceremony torch. Gated to the night by the engine, so lighting it
    /// at noon costs nothing and changes nothing.
    private var torchToggle: some View {
        Button {
            model.torchlight.toggle()
        } label: {
            Image(systemName: model.torchlight ? "flame.fill" : "flame")
                .frame(width: 36, height: 32)
                .hengeControl(isSelected: model.torchlight)
                // The glass reads at thirty-six points; the finger gets
                // the full platform floor around it. Visual weight and
                // hit target are different budgets.
                .frame(width: Henge.Hit.control, height: Henge.Hit.controlHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(model.torchlight ? Henge.bronze : Henge.stone)
        .accessibilityLabel(model.torchlight ? "Put out the torch" : "Light the torch")
        .accessibilityHint("A carried flame that lights the stones at night "
                           + "from the ground stations; it fades out in "
                           + "daylight and stays unlit from the air")
    }

    /// The sky's condition, cycled: clear, overcast, rain, frost. Dressing,
    /// not forecast — the sun's position stays the almanac's business.
    private var weatherToggle: some View {
        Button {
            let all = Weather.allCases
            let index = all.firstIndex(of: model.weather) ?? 0
            model.weather = all[(index + 1) % all.count]
        } label: {
            Image(systemName: weatherSymbol)
                .frame(width: 36, height: 32)
                .hengeControl(isSelected: model.weather != .clear)
                // The glass reads at thirty-six points; the finger gets
                // the full platform floor around it. Visual weight and
                // hit target are different budgets.
                .frame(width: Henge.Hit.control, height: Henge.Hit.controlHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(model.weather != .clear ? Henge.bronze : Henge.stone)
        .accessibilityLabel("Weather")
        .accessibilityValue(model.weather.rawValue)
        .accessibilityHint("Cycles the sky: clear, overcast, rain, frost. "
                           + "Dressing only — the sun keeps the almanac's truth")
    }

    private var weatherSymbol: String {
        switch model.weather {
        case .clear: "sun.max"
        case .overcast: "cloud"
        case .rain: "cloud.rain"
        case .frost: "snowflake"
        }
    }

    /// The twelve zodiac constellations, glyphed at their true places —
    /// and their true places is the point: precession has carried them a
    /// full sign from the astrological calendar, which this app is exactly
    /// the instrument to show.
    /// The hand-drawn constellation figures, joined star to star.
    private var constellationToggle: some View {
        Button {
            model.showsConstellationLines.toggle()
        } label: {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .frame(width: 36, height: 32)
                .hengeControl(isSelected: model.showsConstellationLines)
                .frame(width: Henge.Hit.control, height: Henge.Hit.controlHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(model.showsConstellationLines ? Henge.bronze : Henge.stone)
        .accessibilityLabel(model.showsConstellationLines
                            ? "Hide the constellation figures"
                            : "Show the constellation figures")
        .accessibilityHint("Faint lines joining the stars of twenty-nine "
                           + "classical constellations — figures drawn for "
                           + "this app, riding the precessing sky")
    }

    private var zodiacToggle: some View {
        Button {
            model.showsZodiac.toggle()
        } label: {
            Image(systemName: "sparkles")
                .frame(width: 36, height: 32)
                .hengeControl(isSelected: model.showsZodiac)
                .frame(width: Henge.Hit.control, height: Henge.Hit.controlHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(model.showsZodiac ? Henge.bronze : Henge.stone)
        .accessibilityLabel(model.showsZodiac
                            ? "Hide the zodiac" : "Show the zodiac")
        .accessibilityHint("The twelve constellations at their true places "
                           + "on the night sky — the star patterns, not the "
                           + "astrological signs they have drifted from")
    }

    /// As built, or as it stands: the completed Stage-2 monument of
    /// c. 2200 BC against today's ruin. Two labelled states, never blended
    /// — invariant 8. Promoted from the strip's buried tail to the rail
    /// after the switch quietly cost the owner half the circle: a control
    /// that can remove thirty stones should not be an easter egg.
    private var monumentToggle: some View {
        Button {
            model.monumentState = model.monumentState == .asItWas
                ? .asItStands : .asItWas
        } label: {
            Image(systemName: model.monumentState == .asItWas
                  ? "building.columns.fill" : "building.columns")
                .frame(width: 36, height: 32)
                .hengeControl(isSelected: model.monumentState == .asItWas)
                .frame(width: Henge.Hit.control, height: Henge.Hit.controlHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(model.monumentState == .asItWas ? Henge.bronze : Henge.stone)
        .accessibilityLabel(model.monumentState == .asItWas
                            ? "Showing the monument as built"
                            : "Showing the ruin as it stands")
        .accessibilityHint("Switches between the completed monument of about "
                           + "2200 BC and today's ruin — two surveyed states, "
                           + "never a blend")
    }

    /// Names on the named stars, from the IAU register.
    private var starLabelToggle: some View {
        Button {
            model.showsStarLabels.toggle()
        } label: {
            Image(systemName: "textformat")
                .frame(width: 36, height: 32)
                .hengeControl(isSelected: model.showsStarLabels)
                .frame(width: Henge.Hit.control, height: Henge.Hit.controlHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(model.showsStarLabels ? Henge.bronze : Henge.stone)
        .accessibilityLabel(model.showsStarLabels
                            ? "Hide the star names" : "Show the star names")
        .accessibilityHint("Names the brightest stars on the night sky — "
                           + "IAU proper names, only while their stars are up")
    }

    /// Hoyle's markers, standing gold in the Aubrey holes.
    private var markerToggle: some View {
        Button {
            model.showsLunarMarkers.toggle()
        } label: {
            Image(systemName: "record.circle")
                .frame(width: 36, height: 32)
                .hengeControl(isSelected: model.showsLunarMarkers)
                // The glass reads at thirty-six points; the finger gets
                // the full platform floor around it. Visual weight and
                // hit target are different budgets.
                .frame(width: Henge.Hit.control, height: Henge.Hit.controlHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(model.showsLunarMarkers ? Henge.bronze : Henge.stone)
        .accessibilityLabel(model.showsLunarMarkers
                            ? "Hide the eclipse markers" : "Show the eclipse markers")
        .accessibilityHint("Gold markers on the Aubrey ring at the real positions "
                           + "of the sun, moon and nodes — a modern hypothesis, "
                           + "shown as one")
    }

    private var almanac: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: Henge.Space.panel) {
                column {
                    Text(model.formattedDate)
                        .font(Henge.title(.subheadline))
                    // Local time first: it is the time at the monument, which
                    // is what anyone standing there wants. UT stays visible
                    // underneath because it is what the ephemeris is actually
                    // computed in.
                    Text(model.formattedLocalTime ?? model.formattedSolarTime)
                        .font(Henge.figure(.caption))
                    Text(model.formattedLocalTime == nil
                         ? "local apparent solar time" : model.formattedTime)
                        .font(Henge.figure(.caption2))
                        .opacity(Henge.Ink.faint)
                    // The door to anywhen: under the date, because the date
                    // is the thing it changes.
                    Button {
                        showingTravel = true
                    } label: {
                        Label("Travel", systemImage: "calendar")
                            .font(Henge.body(.caption2))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .hengeControl()
                    .padding(.top, 2)
                    .accessibilityHint("Set the sky to any date from 3000 BC "
                                       + "to AD 3000")
                }

                columnRule

                column {
                    row("Sundial", model.formattedSolarTime)
                    row("Sun over", model.viewpoint == .here
                        ? SkyModel.deviceSite.name : "Stonehenge")
                    row("Altitude", String(format: "%.3f°", model.sun.altitude.degrees))
                    row("Azimuth", String(format: "%.3f°", model.sun.azimuth.degrees))
                    if let sunrise = model.sunriseAzimuth {
                        row("Sunrise", String(format: "%.2f°", sunrise.degrees))
                    }
                }

                columnRule

                column {
                    HStack(spacing: 6) {
                        Image(systemName: model.moonPhase.symbolName)
                            .font(.system(size: 14))
                            .accessibilityHidden(true)
                        Text(model.moonPhase.name)
                            .font(Henge.body(.caption))
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Moon, \(model.moonPhase.name)")
                    row("Lit", String(format: "%.0f%%",
                                      model.moonPhase.illuminatedFraction * 100))
                    row("Altitude", String(format: "%.2f°", model.moon.altitude.degrees))
                    row("Swing", model.standstill)
                }

                columnRule

                column {
                    row("Pole star", model.poleStar)
                    row("Wind", model.windSpeed > 0
                        ? String(format: "%.1f m/s SW", model.windSpeed) : "still")
                    row("Aubrey", String(format: "%.1f holes to node",
                                         model.aubrey.sunToNode))
                    if model.isAubreyEclipseSeason {
                        row("", "eclipse season — hypothesis")
                    }
                }

                columnRule

                // Live alignment: how far off the line the sun is right now,
                // not whether today happens to be the right date.
                column {
                    ForEach(model.alignments, id: \.alignment) { entry in
                        HStack(spacing: 10) {
                            Text(entry.alignment.name)
                                .font(Henge.body(.caption))
                                .opacity(Henge.Ink.dim)
                            Text(String(format: "%.2f°", entry.deviation.degrees))
                                .font(Henge.figure(.caption))
                                .foregroundStyle(entry.isOn ? Henge.mistletoe : Henge.stone)
                        }
                    }
                }

                columnRule

                // The two viewpoint choices and the two states of the
                // monument, at the strip's far end: read far less often than
                // they were reached for when they sat in the main bar.
                column {
                    HStack(spacing: 6) {
                        ForEach(SkyModel.Viewpoint.allCases) { viewpoint in
                            Button(viewpoint.rawValue) { model.viewpoint = viewpoint }
                                .font(Henge.body(.caption2))
                                .padding(.horizontal, 8).padding(.vertical, 5)
                                .hengeControl(isSelected: model.viewpoint == viewpoint)
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.vertical, Henge.Space.tight)
            .padding(.trailing, Henge.Space.panel)
            // The drawer handle rides the strip's leading edge, shifted half
            // into the margin; the readout starts past its lane with clear
            // air — the first simulator screenshot showed the handle
            // sitting on the date.
            .padding(.leading, 24)
        }
        // A ScrollView is greedy in *both* axes, and the overlay proposes
        // the whole screen — without this the glass ran the full height of
        // the display, which is how the strip was found wearing the sky.
        // Fixed vertically, the strip is exactly as tall as its tallest
        // column: the five compact rows of the sun.
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hengePanel()
    }

    private func column(@ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Henge.Space.hair, content: content)
            // Ideal width, always: without this a compact screen compresses
            // the trailing column to a one-character ribbon of stacked
            // letters — seen on the first simulator screenshot — instead of
            // letting the strip scroll.
            .fixedSize(horizontal: true, vertical: false)
    }

    private var columnRule: some View {
        Rectangle()
            .fill(Henge.stone.opacity(Henge.Ink.hairline))
            .frame(width: 1)
            .frame(minHeight: 40)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(Henge.body(.caption))
                .opacity(Henge.Ink.dim)
            Text(value)
                .font(Henge.figure(.caption))
                .monospacedDigit()
        }
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
