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
            Text(model.formattedTime)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)

            Divider().frame(width: 190).padding(.vertical, 6)

            row("Sun altitude", String(format: "%.3f°", model.sun.altitude.degrees))
            row("Sun azimuth", String(format: "%.3f°", model.sun.azimuth.degrees))
            if let sunrise = model.sunriseAzimuth {
                row("Sunrise bearing", String(format: "%.2f°", sunrise.degrees))
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
        .frame(width: 210)
    }

    // ── time and camera ─────────────────────────────────────────────────────

    private var controls: some View {
        VStack(spacing: 14) {
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
