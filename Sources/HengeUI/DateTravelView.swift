import SwiftUI
import HengeAstro

/// Set the sky to any date the model can honestly draw.
///
/// The range is the arithmetic's, not ambition's: 3000 BC to AD 3000, well
/// inside the truncation budgets of every series aboard (VSOP87 and the
/// star machinery are provisioned for five millennia either side of J2000;
/// the precession model's drift at the edges is minutes of arc, and stated
/// where it is used). Dates before 1582 October 15 are Julian-calendar
/// dates, as they were for the people who lived them — `CalendarDate`
/// handles the reform, and BC years ride as astronomical years underneath
/// (2500 BC is year −2499), which is why the leap rule below asks the same
/// convention.
struct DateTravelView: View {

    let initial: CalendarDate
    let onGo: (CalendarDate) -> Void
    @Environment(\.dismiss) private var dismiss

    enum Era: String, CaseIterable, Identifiable {
        case bc = "BC"
        case ad = "AD"
        var id: String { rawValue }
    }

    @State private var era: Era
    /// Displayed year, always positive; the era supplies the sign.
    @State private var year: Int
    @State private var month: Int
    @State private var day: Int
    @State private var hour: Int

    init(initial: CalendarDate, onGo: @escaping (CalendarDate) -> Void) {
        self.initial = initial
        self.onGo = onGo
        let astronomical = initial.year
        _era = State(initialValue: astronomical > 0 ? .ad : .bc)
        _year = State(initialValue: astronomical > 0 ? astronomical : 1 - astronomical)
        _month = State(initialValue: min(max(initial.month, 1), 12))
        _day = State(initialValue: min(max(Int(initial.day), 1), 31))
        _hour = State(initialValue: Int((initial.day - floor(initial.day)) * 24))
    }

    private static let monthNames = ["January", "February", "March", "April",
                                     "May", "June", "July", "August",
                                     "September", "October", "November",
                                     "December"]

    /// Astronomical year for the chosen era and displayed year.
    private var astronomicalYear: Int {
        era == .ad ? year : 1 - year
    }

    /// Days in the chosen month, under the calendar in force at that date:
    /// Julian leap years every fourth year before the reform, Gregorian
    /// century rules after. Both against the astronomical year, where the
    /// divisibility tests are valid straight through the BC range.
    private var daysInMonth: Int {
        let lengths = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        guard month == 2 else { return lengths[month - 1] }
        let y = astronomicalYear
        let gregorian = CalendarDate(year: y, month: month, day: 1).isGregorian
        let leap = gregorian
            ? (y % 4 == 0 && (y % 100 != 0 || y % 400 == 0))
            : y % 4 == 0
        return leap ? 29 : 28
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Henge.Space.margin) {
            Text("Travel")
                .font(Henge.title(.title3))
            Text("Anywhen from 3000 BC to AD 3000 — the span the arithmetic "
                 + "is provisioned for. Dates before October 1582 are "
                 + "Julian-calendar dates, as they were for the people who "
                 + "lived them.")
                .font(Henge.body(.caption))
                .opacity(Henge.Ink.dim)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Henge.Space.element) {
                Picker("Era", selection: $era) {
                    ForEach(Era.allCases) { Text($0.rawValue).tag($0) }
                }
                .frame(maxWidth: 80)
                Picker("Year", selection: $year) {
                    ForEach(1...3000, id: \.self) { Text(String($0)).tag($0) }
                }
                Picker("Month", selection: $month) {
                    ForEach(1...12, id: \.self) {
                        Text(Self.monthNames[$0 - 1]).tag($0)
                    }
                }
                Picker("Day", selection: $day) {
                    ForEach(1...daysInMonth, id: \.self) { Text(String($0)).tag($0) }
                }
                .frame(maxWidth: 80)
                Picker("Hour", selection: $hour) {
                    ForEach(0..<24, id: \.self) {
                        Text(String(format: "%02d:00", $0)).tag($0)
                    }
                }
                .frame(maxWidth: 100)
            }
            #if os(iOS)
            .pickerStyle(.wheel)
            .frame(height: 130)
            #endif

            // The two dates everyone actually wants.
            HStack(spacing: Henge.Space.tight) {
                Button("The sarsens rise — 2500 BC") {
                    era = .bc; year = 2500; month = 7; day = 1; hour = 4
                }
                .font(Henge.body(.caption2))
                .padding(.horizontal, 9).padding(.vertical, 6)
                .hengeControl()
                .buttonStyle(.plain)

                Button("Today") {
                    let now = JulianDay(Date()).calendarDate
                    era = now.year > 0 ? .ad : .bc
                    year = now.year > 0 ? now.year : 1 - now.year
                    month = now.month
                    day = Int(now.day)
                    hour = Int((now.day - floor(now.day)) * 24)
                }
                .font(Henge.body(.caption2))
                .padding(.horizontal, 9).padding(.vertical, 6)
                .hengeControl()
                .buttonStyle(.plain)
            }

            Button {
                onGo(CalendarDate(year: astronomicalYear, month: month,
                                  day: min(day, daysInMonth), hour: hour))
                dismiss()
            } label: {
                Text("Go there")
                    .font(Henge.body(.callout))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .hengeControl(isSelected: true)
        }
        .padding(Henge.Space.margin + 6)
        .foregroundStyle(Henge.stone)
        .tint(Henge.bronze)
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
            .accessibilityLabel("Close without travelling")
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium, .large])
    }
}
