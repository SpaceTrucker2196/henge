import XCTest
@testable import HengeCore

/// The oracle. `make test` runs this; green means the factory is operational.
///
/// These assertions cover the scaffold only. Every production order from here
/// lands its tests alongside its code — a bug fix ships with the test that
/// would have caught it (factory/dark-factory.md §3).
final class HengeCoreTests: XCTestCase {

    func testProductIdentityIsSet() {
        XCTAssertEqual(Henge.name, "Henge")
        XCTAssertGreaterThan(Henge.version, SemanticVersion(major: 0, minor: 0, patch: 0))
    }

    func testVersionParsesThreeComponents() {
        let v = SemanticVersion("1.4.2")
        XCTAssertEqual(v, SemanticVersion(major: 1, minor: 4, patch: 2))
        XCTAssertEqual(v?.description, "1.4.2")
    }

    func testVersionRejectsMalformedInput() {
        // A partial parse would let a wrong version ship silently, so anything
        // that is not exactly three non-negative integers must fail outright.
        for bad in ["1.4", "1.4.2.3", "", "1.x.2", "-1.0.0", "1..2", "v1.4.2"] {
            XCTAssertNil(SemanticVersion(bad), "expected nil for \(bad.debugDescription)")
        }
    }

    func testVersionOrdersByComponentSignificance() {
        XCTAssertLessThan(SemanticVersion("1.0.0")!, SemanticVersion("1.0.1")!)
        XCTAssertLessThan(SemanticVersion("1.0.9")!, SemanticVersion("1.1.0")!)
        XCTAssertLessThan(SemanticVersion("1.9.9")!, SemanticVersion("2.0.0")!)
        XCTAssertEqual(SemanticVersion("2.3.4")!, SemanticVersion("2.3.4")!)
    }

    func testVersionRoundTripsThroughItsStringForm() {
        let v = SemanticVersion(major: 12, minor: 0, patch: 340)
        XCTAssertEqual(SemanticVersion(v.description), v)
    }
}
