import AttributedStringBuilder
import XCTest

struct Test: EnvironmentKey {
    static let defaultValue: String = "Test"
}

extension Environment {
    var test: String {
        get { self[Test.self] }
        set { self[Test.self] = newValue }
    }
}

class EnvironmentTests: XCTestCase {
    func testDefaultValue() async throws {
        @AttributedStringBuilder var str: some AttributedStringConvertible {
            EnvironmentReader(\.test) { envValue in
                envValue
            }
        }
        let result = await str.run(environment: .init())
        XCTAssertEqual(result.string, "Test")

        let result2 = await str.environment(\.test, value: "Hello").run(environment: .init())
        XCTAssertEqual(result2.string, "Hello")
    }
}
