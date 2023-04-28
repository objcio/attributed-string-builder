import AttributedStringBuilder
import XCTest

@MainActor
class MarkdownTests: XCTestCase {
    func testSimpleList() async {
        var context = Context(environment: .init())
        let markdown = """
        - One
        - Two
        - Three
        """
        let attrStr = markdown.markdown().run(context: &context)
        let expectation = """
        \t•\tOne
        \t•\tTwo
        \t•\tThree
        """
        XCTAssertEqual(attrStr.string, expectation)
    }

    func testOrderedList() async {
        var context = Context(environment: .init())
        let markdown = """
        1. One
        1. Two
        1. Three
        """
        let attrStr = markdown.markdown().run(context: &context)
        let expectation = """
        \t1.\tOne
        \t2.\tTwo
        \t3.\tThree
        """
        XCTAssertEqual(attrStr.string, expectation)
    }

    func testIndentedList() {
        var context = Context(environment: .init())
        let markdown = Markdown("""
        - One
        - Two
          - Three
          - Four
        - Five
        """)
        let attrStr = markdown.run(context: &context)
        let expectation = """
        \t•\tOne
        \t•\tTwo
        \t•\tThree
        \t•\tFour
        \t•\tFive
        """
        XCTAssertEqual(attrStr.string, expectation)

//        let str = "<ul><li>Two<ul><li>Three</li><li>Four</li></ul><li></ul>"
//        print(NSAttributedString(html: str.data(using: .utf8)!, documentAttributes: nil)?.string)
    }
}
