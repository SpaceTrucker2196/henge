import SwiftUI
import HengeAstro

/// Where we are in the day, as a bar you can drag.
///
/// The whole local day, midnight to midnight, coloured by where the sun is:
/// night, then the three twilights, then day. It answers at a glance the
/// question the almanac answers in numbers — how far off is dawn — and it
/// doubles as the scrub control, because a bar showing the shape of the day is
/// the obvious thing to drag when you want a different hour of it.
///
/// The bands are drawn from *sampled* sun altitude rather than from solved
/// twilight boundaries. Solving means six root-finds that can each fail: inside
/// the polar circles the sun may never cross a threshold, and this app runs
/// anywhere across five millennia. Sampling is unconditional — it draws a
/// correct bar for a Wiltshire equinox and for a polar summer without a special
/// case for either, and a wrong bar for neither.
public struct DayBar: View {

    @Bindable var model: SkyModel

    /// Standard twilight thresholds, in degrees of solar altitude.
    ///
    /// −0.833 is sunrise proper: the sun's upper limb touching a sea horizon,
    /// which is the refraction-and-semidiameter figure the whole almanac uses.
    /// The rest are the conventional definitions.
    static let bands: [(above: Double, colour: Color)] = [
        (-0.833, Color(red: 0.98, green: 0.90, blue: 0.66)),   // day
        (-6,     Color(red: 0.86, green: 0.60, blue: 0.38)),   // civil twilight
        (-12,    Color(red: 0.42, green: 0.36, blue: 0.48)),   // nautical
        (-18,    Color(red: 0.17, green: 0.18, blue: 0.30)),   // astronomical
        (-90,    Color(red: 0.06, green: 0.07, blue: 0.13))    // night
    ]

    static func colour(forAltitude altitude: Double) -> Color {
        for band in bands where altitude > band.above { return band.colour }
        return bands[bands.count - 1].colour
    }

    public init(model: SkyModel) {
        self.model = model
    }

    public var body: some View {
        let profile = model.dayProfile()
        let fraction = model.fractionOfDay

        VStack(spacing: 5) {
            GeometryReader { geometry in
                let width = geometry.size.width

                ZStack(alignment: .leading) {
                    // The day itself.
                    HStack(spacing: 0) {
                        ForEach(profile.indices, id: \.self) { i in
                            Self.colour(forAltitude: profile[i])
                        }
                    }
                    .clipShape(Capsule())

                    // Midnight, noon and the quarters, as hairlines. Enough to
                    // read the bar as a clock without labelling every hour.
                    ForEach([0.25, 0.5, 0.75], id: \.self) { mark in
                        Rectangle()
                            .fill(Henge.stone.opacity(mark == 0.5 ? 0.45 : 0.22))
                            .frame(width: 1)
                            .offset(x: width * mark)
                    }

                    // Now.
                    Capsule()
                        .fill(Henge.bronze)
                        .frame(width: 3)
                        .overlay(
                            Circle()
                                .fill(Henge.bronze)
                                .frame(width: 11, height: 11)
                                .shadow(radius: 2)
                        )
                        .offset(x: max(0, min(width - 3, width * fraction - 1.5)))
                }
                .contentShape(Rectangle())
                .gesture(
                    // minimumDistance 0 so a tap jumps as well as a drag
                    // scrubbing — the bar is a position, and touching a
                    // position should go there.
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard width > 0 else { return }
                            model.isPlaying = false
                            model.scrub(toFractionOfDay: value.location.x / width)
                        }
                )
            }
            .frame(height: 22)

            HStack {
                Text("00").font(Henge.figure(.caption2)).opacity(0.5)
                Spacer()
                Text("06").font(Henge.figure(.caption2)).opacity(0.4)
                Spacer()
                Text("12").font(Henge.figure(.caption2)).opacity(0.5)
                Spacer()
                Text("18").font(Henge.figure(.caption2)).opacity(0.4)
                Spacer()
                Text("24").font(Henge.figure(.caption2)).opacity(0.5)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("daybar.label", bundle: .module))
        .accessibilityValue(model.formattedLocalTime ?? model.formattedSolarTime)
        .accessibilityHint(Text("daybar.hint", bundle: .module))
        .accessibilityAdjustableAction { direction in
            // A tenth of an hour a step: fine enough to walk a sunrise through,
            // coarse enough to cross a night without a hundred gestures.
            let step = (1.0 / 24) * 0.1
            switch direction {
            case .increment: model.scrub(toFractionOfDay: model.fractionOfDay + step)
            case .decrement: model.scrub(toFractionOfDay: model.fractionOfDay - step)
            @unknown default: break
            }
        }
    }
}
