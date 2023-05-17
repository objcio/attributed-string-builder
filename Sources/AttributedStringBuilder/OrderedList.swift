//

import Foundation

// This uses the Markdown stylesheet
public struct NumberedList<Content: AttributedStringConvertible>: AttributedStringConvertible {
    public var startIndex = 1
    public var children: Content

    public init(startIndex: Int = 1, @AttributedStringBuilder children: () -> Content) {
        self.startIndex = startIndex
        self.children = children()
    }

    public func attributedString(context: inout Context) -> [NSAttributedString] {
        let oldEnv = context.environment
        defer {
            context.environment = oldEnv
        }
        var attributes: Attributes {
            get { context.environment.attributes }
            set { context.environment.attributes = newValue }
        }

        let stylesheet = context.environment.markdownStylesheet

        attributes.headIndent += attributes.tabStops[1].location
        let renderedChildren = children.attributedString(context: &context)

        let result = NSMutableAttributedString()

        for (item, number) in zip(renderedChildren, startIndex...) {
            // Append list item prefix
            var prefixAttributes = attributes
            stylesheet.orderedListItemPrefix(attributes: &prefixAttributes)
            let prefix = stylesheet.orderedListItemPrefix(number: number)

            if number == renderedChildren.count {
                // Restore spacing for last list item
                attributes.paragraphSpacing = oldEnv.attributes.paragraphSpacing
                prefixAttributes.paragraphSpacing = oldEnv.attributes.paragraphSpacing
            }

            result.append(NSAttributedString(string: "\t", attributes: attributes))
            result.append(NSAttributedString(string: prefix, attributes: prefixAttributes))
            result.append(NSAttributedString(string: "\t", attributes: attributes))

            result.append(item)

            if number < renderedChildren.count {
                result.append(.init(string: "\n", attributes: attributes))
            }
        }

        return [result]
    }
}
