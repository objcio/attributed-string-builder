import Markdown
import AppKit

public struct DefaultStylesheet: Stylesheet { }

extension Stylesheet where Self == DefaultStylesheet {
    static public var `default`: Self {
        DefaultStylesheet()
    }
}

struct AttributedStringWalker: MarkupWalker {
    var attributes: Attributes
    let stylesheet: Stylesheet
    var makeURL: ((ListItem) -> URL?)?

    var attributedString = NSMutableAttributedString()

    mutating func visitDocument(_ document: Document) -> () {
        for block in document.blockChildren {
            if !attributedString.string.isEmpty {
                attributedString.append(NSAttributedString(string: "\n", attributes: attributes))
            }
            visit(block)
        }
    }

    func visitText(_ text: Text) -> () {
        attributedString.append(NSAttributedString(string: text.string, attributes: attributes))
    }

    func visitLineBreak(_ lineBreak: LineBreak) -> () {
        attributedString.append(NSAttributedString(string: "\n", attributes: attributes))
    }

    func visitSoftBreak(_ softBreak: SoftBreak) -> () {
        return
    }

    func visitInlineCode(_ inlineCode: InlineCode) -> () {
        var attributes = attributes
        stylesheet.inlineCode(attributes: &attributes)
        attributedString.append(NSAttributedString(string: inlineCode.code, attributes: attributes))
    }

    func visitCodeBlock(_ codeBlock: CodeBlock) -> () {
        var attributes = attributes
        stylesheet.codeBlock(attributes: &attributes)
        attributedString.append(NSAttributedString(string: codeBlock.code.trimmingCharacters(in: .whitespacesAndNewlines), attributes: attributes))
    }

    func visitInlineHTML(_ inlineHTML: InlineHTML) -> () {
        fatalError()
    }

    func visitHTMLBlock(_ html: HTMLBlock) -> () {
        fatalError()
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) -> () {
        let original = attributes
        defer { attributes = original }

        stylesheet.emphasis(attributes: &attributes)

        for child in emphasis.children {
            visit(child)
        }
    }

    mutating func visitStrong(_ strong: Strong) -> () {
        let original = attributes
        defer { attributes = original }

        stylesheet.strong(attributes: &attributes)

        for child in strong.children {
            visit(child)
        }
    }

    func visitCustomBlock(_ customBlock: CustomBlock) -> () {
        fatalError()
    }

    func visitCustomInline(_ customInline: CustomInline) -> () {
        fatalError()
    }

    mutating func visitLink(_ link: Link) -> () {
        let original = attributes
        defer { attributes = original }

        stylesheet.link(attributes: &attributes)
        attributes.link = link.destination.flatMap(URL.init(string:))

        for child in link.children {
            visit(child)
        }
    }

    mutating func visitHeading(_ heading: Heading) -> () {
        let original = attributes
        defer { attributes = original }
        stylesheet.heading(level: heading.level, attributes: &attributes)
        for child in heading.children {
            visit(child)
        }
    }

    mutating func visitOrderedList(_ orderedList: OrderedList) -> () {
        visit(list: orderedList)
    }

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> () {
        visit(list: unorderedList)
    }

    mutating private func visit(list: ListItemContainer) {
        let original = attributes
        defer { attributes = original }

        let isOrdered = list is OrderedList

        attributes.tabStops[0] = NSTextTab(textAlignment: .right, location: attributes.tabStops[0].location)
        attributes.tabStops[1] = NSTextTab(textAlignment: .left, location: attributes.tabStops[0].location + 10)
        attributes.headIndent += attributes.tabStops[1].location
        attributes.paragraphSpacing = 0 // Remove spacing between list items

        for (item, number) in zip(list.listItems, 1...) {
            // Append list item prefix
            let prefix: String
            var prefixAttributes = attributes
            
            switch (item.checkbox, isOrdered) {
            case (let checkbox?, _):
                switch checkbox {
                case .checked:
                    prefix = stylesheet.checkboxCheckedPrefix
                    stylesheet.checkboxCheckedPrefix(attributes: &prefixAttributes)
                case .unchecked:
                    prefix = stylesheet.checkboxUncheckedPrefix
                    stylesheet.checkboxUncheckedPrefix(attributes: &prefixAttributes)
                }
                if let url = makeURL?(item) {
                    prefixAttributes.link = url
                }
            case (_, true):
                prefix = stylesheet.orderedListItemPrefix(number: number)
                stylesheet.orderedListItemPrefix(attributes: &prefixAttributes)
            case (_, false):
                prefix = stylesheet.unorderedListItemPrefix
                stylesheet.unorderedListItemPrefix(attributes: &prefixAttributes)
            }
            
            if number == list.childCount {
                // Restore spacing for last list item
                attributes.paragraphSpacing = original.paragraphSpacing
                prefixAttributes.paragraphSpacing = original.paragraphSpacing
            }
            
            attributedString.append(NSAttributedString(string: "\t\(prefix)\t", attributes: prefixAttributes))

            // Visit list item contents
            visit(item)

            if number < list.childCount {
                attributedString.append(NSAttributedString(string: "\n", attributes: attributes))
            }
        }
    }

    mutating func visitListItem(_ listItem: ListItem) -> () {
        let original = attributes
        defer { attributes = original }

        stylesheet.listItem(attributes: &attributes, checkbox: listItem.checkbox?.bool)

        for child in listItem.children {
            visit(child)
        }
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> () {
        let original = attributes
        defer { attributes = original }
        stylesheet.blockQuote(attributes: &attributes)
        for child in blockQuote.children {
            visit(child)
        }
    }

    func visitThematicBreak(_ thematicBreak: ThematicBreak) -> () {
        // TODO we could consider making this stylable, but ideally the stylesheet doesn't know about NSAttributedString?
        let thematicBreak = NSAttributedString(string: "\n\r\u{00A0} \u{0009} \u{00A0}\n\n", attributes: [.strikethroughStyle: NSUnderlineStyle.single.rawValue, .strikethroughColor: NSColor.gray])
        attributedString.append(thematicBreak)

    }
}

extension Checkbox {
    var bool: Bool {
        get {
            self == .checked
        }
        set {
            self = newValue ? .checked : .unchecked
        }
    }
}

fileprivate struct Markdown: AttributedStringConvertible {
    var document: Document
    var stylesheet: any Stylesheet
    var makeURL: ((ListItem) -> URL?)?

    func attributedString(environment: EnvironmentValues) -> [NSAttributedString] {
        var walker = AttributedStringWalker(attributes: environment.attributes, stylesheet: stylesheet, makeURL: makeURL)
        walker.visit(document)
        return [walker.attributedString]
    }
}

extension Markdown {
    init(string: String, stylesheet: any Stylesheet) {
        self.document = Document(parsing: string)
        self.stylesheet = stylesheet
        self.makeURL = nil
    }
}

extension String {
    public func markdown(stylesheet: any Stylesheet = .default) -> some AttributedStringConvertible {
        Markdown(string: self, stylesheet: stylesheet)
    }
}

extension Document {
    public func markdown(stylesheet: any Stylesheet = .default, makeURL: ((ListItem) -> URL?)? = nil) -> some AttributedStringConvertible {
        Markdown(document: self, stylesheet: stylesheet, makeURL: makeURL)
    }
}
