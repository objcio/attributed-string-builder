import AttributedStringBuilder
import XCTest

struct Test: EnvironmentKey {
    static let defaultValue: String = "Test"
}

extension EnvironmentValues {
    var test: String {
        get { self[Test.self] }
        set { self[Test.self] = newValue }
    }
}

class EnvironmentTests: XCTestCase {
    @MainActor
    func testDefaultValue() throws {
        @AttributedStringBuilder var str: some AttributedStringConvertible {
            EnvironmentReader(\.test) { envValue in
                envValue
            }
        }
        var context = Context(environment: .init())
        let result = str.run(context: &context)
        XCTAssertEqual(result.string, "Test")

        context = Context(environment: .init())

        let result2 = str
            .environment(\.test, value: "Hello")
            .run(context: &context)
        XCTAssertEqual(result2.string, "Hello")
    }
}
