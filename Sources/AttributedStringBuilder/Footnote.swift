import Foundation

struct FootnoteCounter: StateKey {
    static var initialValue = 1
}

extension StateValues {
    public var footnoteCounter: Int {
        get { self[FootnoteCounter.self] }
        set { self[FootnoteCounter.self] = newValue }
    }
}

public struct Footnote<Contents: AttributedStringConvertible>: AttributedStringConvertible {
    public init(@AttributedStringBuilder contents: () -> Contents) {
        self.contents = contents()
    }

    var contents: Contents

    public func attributedString(context: inout Context) -> [NSAttributedString] {
        defer { context.state.footnoteCounter += 1 }
        let counter = "\(context.state.footnoteCounter)"
        let stylesheet = context.environment.markdownStylesheet
        let annotation = Joined(separator: " ") {
            "\(counter)\t"
            contents
        }
        .modify {
            stylesheet.footnote(attributes: &$0)
            $0.headIndent = $0.tabStops[0].location
        }
        .joined()
        let c = context
        let result = "\(counter)"
            .superscript()
            .modify { attrs in
                var copiedContext = c
                stylesheet.footnote(attributes: &attrs)
                attrs.annotation = annotation.run(context: &copiedContext)
            }
        return result.attributedString(context: &context)
    }
}
