import SwiftUI
import HengeAstro
import HengeGeometry

/// Where the app says things, and how it says them.
///
/// Every panel wears its tier and its sources. That is not a legal disclaimer
/// tucked in a settings screen — it is the design. Stonehenge attracts three
/// kinds of statement in the same confident voice, and separating them at the
/// point of reading is the one thing this app can offer that a guidebook
/// mostly does not.
///
/// The badge is deliberately not subtle and deliberately not alarming. A
/// "modern tradition" note is not a warning; Beltane is a real thing that real
/// people really do. It is simply not Neolithic, and the reader gets to know
/// which they are holding.
public struct LoreView: View {

    let notes: [LoreNote]
    @State private var expanded: Set<String> = []
    @Environment(\.dismiss) private var dismiss

    public init(notes: [LoreNote]) {
        self.notes = notes
    }

    public var body: some View {
        ScrollView {
            HengeGlass(spacing: 18) {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(notes) { note in
                        panel(note)
                    }
                }
            }
            .padding(20)
        }
        // An explicit way out. The sheet's swipe-to-dismiss still works,
        // but the reading fills the height and the scroll owns the drag —
        // on a phone the sheet was effectively a room with no door.
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
            .foregroundStyle(Henge.stone)
            .padding(Henge.Space.tight)
            .accessibilityLabel("Close the lore")
        }
        .presentationDragIndicator(.visible)
    }

    private func panel(_ note: LoreNote) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(note.title)
                    .font(Henge.title(.headline))
                Spacer(minLength: 8)
                badge(note.tier)
            }

            Text(note.body)
                .font(Henge.body(.callout))
                .fixedSize(horizontal: false, vertical: true)

            // Sources are one tap away rather than always open: they must be
            // present and reachable, but a wall of citations under every
            // paragraph turns the register from bardic into bibliographic.
            DisclosureGroup(
                isExpanded: Binding(
                    get: { expanded.contains(note.id) },
                    set: { isOpen in
                        if isOpen { expanded.insert(note.id) }
                        else { expanded.remove(note.id) }
                    }
                )
            ) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(note.citations.enumerated()), id: \.offset) { _, citation in
                        Text(citation.text)
                            .font(Henge.body(.caption))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 4)
            } label: {
                Text(note.citations.count == 1 ? "1 source" : "\(note.citations.count) sources")
                    .font(Henge.body(.caption))
            }
            .accessibilityHint("Show the sources for this note")
        }
        .padding(16)
        .hengePanel(cornerRadius: 14)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(note.title). \(note.tier.rawValue).")
    }

    private func badge(_ tier: LoreTier) -> some View {
        Text(tier.rawValue)
            .font(.system(.caption2, design: .serif).weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(colour(tier).opacity(0.22), in: Capsule())
            .overlay(Capsule().strokeBorder(colour(tier).opacity(0.5), lineWidth: 1))
            .accessibilityLabel("Tier: \(tier.rawValue)")
    }

    /// Tier colours drawn from the palette rather than from the system's
    /// traffic-light set. Orange-and-green reads as "warning" and "safe", which
    /// is the wrong idea entirely — a modern-tradition note is not a caution.
    private func colour(_ tier: LoreTier) -> Color {
        switch tier {
        case .established: Henge.mistletoe
        case .debated: Henge.bronze
        case .modernTradition: Color(red: 0.60, green: 0.58, blue: 0.70)
        }
    }
}
