import Foundation

/// A moment, as astronomers count them: days since -4712 January 1 at noon.
///
/// The calendar switch matters here in a way it does not in ordinary software.
/// Henge reaches back to 3000 BC, so dates before 1582 October 15 are Julian
/// calendar dates — the proleptic Gregorian calendar would silently displace
/// the monument's own era by ten days and more.
public struct JulianDay: Sendable, Hashable, Comparable, CustomStringConvertible {

    public let value: Double

    public init(_ value: Double) { self.value = value }

    /// J2000.0 — the standard epoch, 2000 January 1.5 TT.
    public static let j2000 = JulianDay(2451545.0)

    /// Julian centuries from J2000. The argument every Meeus series takes.
    public var julianCenturies: Double { (value - 2451545.0) / 36525.0 }

    /// Julian millennia from J2000, for the VSOP87 series.
    public var julianMillennia: Double { (value - 2451545.0) / 365250.0 }

    public var description: String { String(format: "JD %.5f", value) }
    public static func < (a: JulianDay, b: JulianDay) -> Bool { a.value < b.value }
    public static func + (jd: JulianDay, days: Double) -> JulianDay { JulianDay(jd.value + days) }
    public static func - (jd: JulianDay, days: Double) -> JulianDay { JulianDay(jd.value - days) }
    public static func - (a: JulianDay, b: JulianDay) -> Double { a.value - b.value }
}

/// A calendar date with fractional day, in whichever calendar was in force.
public struct CalendarDate: Sendable, Hashable {

    public var year: Int
    public var month: Int
    /// Day of month, fractional — 1.5 is noon on the 1st.
    public var day: Double

    public init(year: Int, month: Int, day: Double) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init(year: Int, month: Int, day: Int,
                hour: Int = 0, minute: Int = 0, second: Double = 0) {
        self.year = year
        self.month = month
        self.day = Double(day)
            + Double(hour) / 24.0
            + Double(minute) / 1440.0
            + second / 86400.0
    }

    /// The Gregorian reform: 1582 October 4 (Julian) was followed by
    /// 1582 October 15 (Gregorian). Everything on or after that instant is
    /// Gregorian; everything before it is Julian.
    public var isGregorian: Bool {
        if year > 1582 { return true }
        if year < 1582 { return false }
        if month > 10 { return true }
        if month < 10 { return false }
        return day >= 15
    }
}

public extension JulianDay {

    /// Meeus, *Astronomical Algorithms*, ch. 7.
    ///
    /// Note the `floor` rather than integer division: for negative years —
    /// which is most of the monument's history — truncation toward zero is
    /// wrong and would land the date a day out.
    init(_ date: CalendarDate) {
        var y = Double(date.year)
        var m = Double(date.month)
        if m <= 2 {
            y -= 1
            m += 12
        }
        let b: Double
        if date.isGregorian {
            let a = floor(y / 100.0)
            b = 2 - a + floor(a / 4.0)
        } else {
            b = 0
        }
        self.init(floor(365.25 * (y + 4716))
                  + floor(30.6001 * (m + 1))
                  + date.day + b - 1524.5)
    }

    init(year: Int, month: Int, day: Int,
         hour: Int = 0, minute: Int = 0, second: Double = 0) {
        self.init(CalendarDate(year: year, month: month, day: day,
                               hour: hour, minute: minute, second: second))
    }

    /// The inverse (Meeus ch. 7). Returns the date in the calendar that was in
    /// force at that moment.
    var calendarDate: CalendarDate {
        let jdShifted = value + 0.5
        let z = floor(jdShifted)
        let f = jdShifted - z

        var a = z
        if z >= 2299161 {
            let alpha = floor((z - 1867216.25) / 36524.25)
            a = z + 1 + alpha - floor(alpha / 4.0)
        }
        let b = a + 1524
        let c = floor((b - 122.1) / 365.25)
        let d = floor(365.25 * c)
        let e = floor((b - d) / 30.6001)

        let day = b - d - floor(30.6001 * e) + f
        let month = e < 14 ? e - 1 : e - 13
        let year = month > 2 ? c - 4716 : c - 4715

        return CalendarDate(year: Int(year), month: Int(month), day: day)
    }

    /// Day of the week, 0 = Sunday.
    var weekday: Int {
        Int((floor(value + 1.5)).truncatingRemainder(dividingBy: 7))
    }
}

/// Terrestrial Time minus Universal Time, in seconds.
///
/// Earth's rotation is not a clock. Over the monument's lifetime ΔT runs to
/// tens of thousands of seconds — half a day by 3000 BC — so ignoring it would
/// put the solstice sunrise in the wrong part of the sky entirely.
///
/// Polynomials from Espenak & Meeus, *Five Millennium Canon of Solar Eclipses*
/// (NASA/TP–2006–214141), which is the standard fit across exactly the span
/// Henge needs.
public enum DeltaT {

    /// - Parameter year: decimal year, e.g. 2026.5 for mid-2026.
    public static func seconds(decimalYear year: Double) -> Double {
        switch year {
        case ..<(-500):
            let u = (year - 1820) / 100
            return -20 + 32 * u * u

        case (-500)..<500:
            let u = year / 100
            return poly(u, [10583.6, -1014.41, 33.78311, -5.952053,
                            -0.1798452, 0.022174192, 0.0090316521])

        case 500..<1600:
            let u = (year - 1000) / 100
            return poly(u, [1574.2, -556.01, 71.23472, 0.319781,
                            -0.8503463, -0.005050998, 0.0083572073])

        case 1600..<1700:
            let t = year - 1600
            return poly(t, [120, -0.9808, -0.01532, 1.0 / 7129.0])

        case 1700..<1800:
            let t = year - 1700
            return poly(t, [8.83, 0.1603, -0.0059285, 0.00013336, -1.0 / 1174000.0])

        case 1800..<1860:
            let t = year - 1800
            return poly(t, [13.72, -0.332447, 0.0068612, 0.0041116, -0.00037436,
                            0.0000121272, -0.0000001699, 0.000000000875])

        case 1860..<1900:
            let t = year - 1860
            return poly(t, [7.62, 0.5737, -0.251754, 0.01680668,
                            -0.0004473624, 1.0 / 233174.0])

        case 1900..<1920:
            let t = year - 1900
            return poly(t, [-2.79, 1.494119, -0.0598939, 0.0061966, -0.000197])

        case 1920..<1941:
            let t = year - 1920
            return poly(t, [21.20, 0.84493, -0.076100, 0.0020936])

        case 1941..<1961:
            let t = year - 1950
            return poly(t, [29.07, 0.407, -1.0 / 233.0, 1.0 / 2547.0])

        case 1961..<1986:
            let t = year - 1975
            return poly(t, [45.45, 1.067, -1.0 / 260.0, -1.0 / 718.0])

        case 1986..<2005:
            let t = year - 2000
            return poly(t, [63.86, 0.3345, -0.060374, 0.0017275,
                            0.000651814, 0.00002373599])

        case 2005..<2050:
            let t = year - 2000
            return poly(t, [62.92, 0.32217, 0.005589])

        case 2050..<2150:
            let u = (year - 1820) / 100
            return -20 + 32 * u * u - 0.5628 * (2150 - year)

        default:
            let u = (year - 1820) / 100
            return -20 + 32 * u * u
        }
    }

    public static func seconds(at jd: JulianDay) -> Double {
        seconds(decimalYear: jd.decimalYear)
    }

    private static func poly(_ x: Double, _ coefficients: [Double]) -> Double {
        // Horner, evaluated from the top down.
        coefficients.reversed().reduce(0) { $0 * x + $1 }
    }
}

public extension JulianDay {

    /// Decimal year, adequate for ΔT's own precision.
    var decimalYear: Double {
        let d = calendarDate
        return Double(d.year) + (Double(d.month) - 0.5) / 12.0
    }

    /// Universal Time → Terrestrial Time. Ephemerides are computed in TT; the
    /// clock on the wall reads UT.
    var terrestrialTime: JulianDay {
        JulianDay(value + DeltaT.seconds(at: self) / 86400.0)
    }

    /// Terrestrial Time → Universal Time.
    ///
    /// ΔT is defined on UT, so inverting it is iterative. Two passes is ample:
    /// ΔT changes by seconds per year, and the first correction is already
    /// accurate to well under a second.
    var universalTime: JulianDay {
        var ut = JulianDay(value - DeltaT.seconds(at: self) / 86400.0)
        for _ in 0..<2 {
            ut = JulianDay(value - DeltaT.seconds(at: ut) / 86400.0)
        }
        return ut
    }
}
