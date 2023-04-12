import AttributedStringBuilder
import XCTest

class MarkdownTests: XCTestCase {
    func testSimpleList() async {
        let markdown = """
        - One
        - Two
        - Three
        """
        let attrStr = await markdown.markdown().run(environment: .init())
        let expectation = """
        \t•\tOne
        \t•\tTwo
        \t•\tThree
        """
        XCTAssertEqual(attrStr.string, expectation)
    }

    func testOrderedList() async {
        let markdown = """
        1. One
        1. Two
        1. Three
        """
        let attrStr = await markdown.markdown().run(environment: .init())
        let expectation = """
        \t1.\tOne
        \t2.\tTwo
        \t3.\tThree
        """
        XCTAssertEqual(attrStr.string, expectation)
    }

    func testIndentedList() async {
        let markdown = Markdown("""
        - One
        - Two
          - Three
          - Four
        - Five
        """)
        let attrStr = await markdown.run(environment: .init())
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
