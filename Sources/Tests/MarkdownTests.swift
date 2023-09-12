@_spi(Internal) import AttributedStringBuilder
import XCTest
import Markdown

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
    
    func testRewriting() {
        var context = Context(environment: .init())
        let markdown = """
            Hello [World](https://www.objc.io)
            """
        let attrStr = markdown.markdown()
            .rewriter(MyRewriter())
            .run(context: &context)
        let expectation = """
            Hello xWorldy
            """
        XCTAssertEqual(attrStr.string, expectation)
    }

    func testLinkRewriting() {
        var context = Context(environment: .init())
        let markdown = """
            Hello [World](https://www.objc.io)
            """
        let attrStr = markdown.markdown()
            .environment(\.linkRewriter) { node, str in
                Group {
                    str
                    "Suffix"
                        .textColor(.red)
                }
            }
            .run(context: &context)
        let expectation = """
            Hello WorldSuffix
            """
        XCTAssertEqual(attrStr.string, expectation)
        let atts = attrStr.attributes(at: 13, effectiveRange: nil)
        XCTAssertEqual(atts[.foregroundColor] as? NSColor, NSColor.red)
    }
}

struct MyRewriter: MarkupRewriter {
    var count = 0
    func visitLink(_ link: Link) -> Markup? {
        let children = [Text("x")] + link.inlineChildren.compactMap { $0 as? RecurringInlineMarkup } + [Text("y")]
        return Link(destination: link.destination, children)
    }
}
