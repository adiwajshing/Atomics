import XCTest
@testable import Atomics

final class AtomicsTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(Atomics().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
