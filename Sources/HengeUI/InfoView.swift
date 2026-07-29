import SwiftUI

/// What this app is, and whose shoulders it stands on.
///
/// The attributions are not garnish: Hipparcos ships under "free with
/// attribution", and several public-domain sources are credited because a
/// claim about where the sun rises should say what it was measured
/// against. This view is the user-facing face of SECURITY.md's provenance
/// registry — the two must move together.
struct InfoView: View {

    @Environment(\.dismiss) private var dismiss

    private struct Credit: Identifiable {
        let id: String
        let what: String
        let source: String
    }

    private static let data: [Credit] = [
        Credit(id: "hipparcos",
               what: "The stars — 8,870 naked-eye positions, magnitudes, "
                   + "colours and proper motions",
               source: "ESA, 1997: The Hipparcos and Tycho Catalogues "
                   + "(ESA SP-1200), via CDS I/239. Free with attribution."),
        Credit(id: "names",
               what: "The stars' names",
               source: "IAU Working Group on Star Names, Catalog of Star "
                   + "Names (IAU-CSN)."),
        Credit(id: "vsop",
               what: "The planets — Mercury to Saturn",
               source: "Bretagnon & Francou, VSOP87 (A&A 202, 309, 1988), "
                   + "via CDS VI/81."),
        Credit(id: "moon",
               what: "The Moon's face",
               source: "NASA Goddard Scientific Visualization Studio, CGI "
                   + "Moon Kit — Lunar Reconnaissance Orbiter data. Public "
                   + "domain."),
        Credit(id: "terrain",
               what: "Salisbury Plain — the ground the shadows fall on",
               source: "NASA/USGS SRTM 1 arc-second elevation. Public domain."),
        Credit(id: "algorithms",
               what: "The sun, moon and calendar arithmetic",
               source: "Jean Meeus, Astronomical Algorithms (2nd ed.); "
                   + "ΔT from Espenak & Meeus, NASA/TP-2006-214141."),
        Credit(id: "sky",
               what: "The daylight sky",
               source: "Preetham, Shirley & Smits, \"A Practical Analytic "
                   + "Model for Daylight\" (1999)."),
        Credit(id: "textures",
               what: "Stone and turf detail",
               source: "ambientCG (Rock030, Grass004), CC0 — no attribution "
                   + "required, credited anyway."),
        Credit(id: "survey",
               what: "The monument's dimensions and the archaeology",
               source: "Surveyed figures after Petrie's numbering; tiers and "
                   + "citations appear beside every claim in the Lore panel.")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Henge.Space.margin) {
                Text("Henge")
                    .font(Henge.title(.title2))
                Text("A photoreal Stonehenge that is also a working "
                     + "astronomical calendar. Everything the picture claims "
                     + "— where the sun rises, what the moon is doing, which "
                     + "star holds the pole — is computed, tested against "
                     + "published values, and drawn from the same arithmetic "
                     + "the readout prints.")
                    .font(Henge.body(.callout))
                    .fixedSize(horizontal: false, vertical: true)

                Text("Standing on")
                    .font(Henge.title(.headline))
                    .padding(.top, Henge.Space.tight)

                ForEach(Self.data) { credit in
                    VStack(alignment: .leading, spacing: Henge.Space.hair) {
                        Text(credit.what)
                            .font(Henge.body(.callout))
                        Text(credit.source)
                            .font(Henge.body(.caption))
                            .opacity(Henge.Ink.dim)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Text("River.io — data stays on the device; this app makes "
                     + "no network calls at all.")
                    .font(Henge.body(.caption))
                    .opacity(Henge.Ink.faint)
                    .padding(.top, Henge.Space.tight)
            }
            .padding(20)
        }
        .foregroundStyle(Henge.stone)
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .hengeControl()
                    .frame(width: Henge.Hit.control, height: Henge.Hit.control)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(Henge.Space.tight)
            .accessibilityLabel("Close")
        }
        .presentationDragIndicator(.visible)
    }
}
