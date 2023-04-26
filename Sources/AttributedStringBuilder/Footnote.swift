import Foundation

public struct Footnote<Contents: AttributedStringConvertible>: AttributedStringConvertible {
    public init(@AttributedStringBuilder contents: () -> Contents) {
        self.contents = contents()
    }

    var contents: Contents

    public func attributedString(context: inout Context) -> [NSAttributedString] {
        let _ = print("TODO footnote support")
//        environment.footnoteCounter += 1
//        let counter = environment.footnoteCounter
        let counter = "1"
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
        let result = "\(counter)"
            .superscript()
//            .modify { attrs in
//                var copy = attrs
//                stylesheet.footnote(attributes: &copy)
//                copy.annotation = annotation
//            }
//            .attributedString(&environment)
        return result.attributedString(context: &context)
    }
}

//extension String {
//    public func footnote(@AttributedStringBuilder contents: () -> ToAttributedString) -> some ToAttributedString {
//        Footnote(title: self, contents: contents())
//    }
//}
