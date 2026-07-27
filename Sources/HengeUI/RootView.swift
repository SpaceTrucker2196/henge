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
        .frame(width: 210)
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

            HStack(spacing: 14) {
                Button {
                    model.isPlaying.toggle()
                } label: {
                    Label(model.isPlaying ? "Pause" : "Play",
                          systemImage: model.isPlaying ? "pause.fill" : "play.fill")
                }
                .accessibilityLabel(model.isPlaying ? "Pause time" : "Run time forward")

                Button("Now") { model.time = JulianDay(Date()) }
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
                ), in: 0...5)
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
            model.advance(byRealSeconds: elapsed)
        }
    }
}
