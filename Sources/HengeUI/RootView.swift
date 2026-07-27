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

    public init() {}

    public var body: some View {
        ZStack(alignment: .bottom) {
            HengeSceneView(model: model)
                .ignoresSafeArea()

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
            HStack(spacing: 14) {
                Button {
                    model.isPlaying.toggle()
                } label: {
                    Label(model.isPlaying ? "Pause" : "Play",
                          systemImage: model.isPlaying ? "pause.fill" : "play.fill")
                }
                .accessibilityLabel(model.isPlaying ? "Pause time" : "Run time forward")

                Button("Now") { model.time = JulianDay(Date()) }

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

            labelled("Bearing", String(format: "%.0f°", model.cameraAzimuth)) {
                Slider(value: $model.cameraAzimuth, in: 0...360)
            }

            labelled("Height", String(format: "%.0f°", model.cameraElevation)) {
                Slider(value: $model.cameraElevation, in: -2...80)
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
