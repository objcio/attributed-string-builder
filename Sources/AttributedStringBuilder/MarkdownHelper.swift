import Markdown
import AppKit

public struct DefaultStylesheet: Stylesheet { }

extension Stylesheet where Self == DefaultStylesheet {
    static public var `default`: Self {
        DefaultStylesheet()
    }
}

struct HighlightCode: EnvironmentKey {
    static var defaultValue: ((Code) -> any AttributedStringConvertible)? = nil
}

extension EnvironmentValues {
    public var highlightCode: ((Code) -> any AttributedStringConvertible)? {
        get {
            self[HighlightCode.self]
        }
        set {
            self[HighlightCode.self] = newValue
        }
    }
}

struct Rewriters: EnvironmentKey {
    static var defaultValue: [any MarkupRewriter] = []
}

extension EnvironmentValues {
    var rewriters: [any MarkupRewriter] {
        get { self[Rewriters.self] }
        set { self[Rewriters.self] = newValue }
    }
}

struct CustomLinkRewriter: EnvironmentKey {
    static var defaultValue: ((Link, NSAttributedString) -> any AttributedStringConvertible)? = nil
}

extension EnvironmentValues {
    @_spi(Internal) public var linkRewriter: ((Link, NSAttributedString) -> any AttributedStringConvertible)? {
        get { self[CustomLinkRewriter.self] }
        set { self[CustomLinkRewriter.self] = newValue }
    }
}

extension AttributedStringConvertible {
    public func rewriter(_ r: any MarkupRewriter) -> some AttributedStringConvertible {
        transformEnvironment(\.rewriters, transform: {
            $0.append(r)
        })
    }
}

public struct Code: Hashable, Codable {
    public init(language: String? = nil, code: String) {
        self.language = language
        self.code = code
    }

    public var language: String?
    public var code: String
}

@MainActor(unsafe)
struct AttributedStringWalker: MarkupWalker {
    var interpolationSegments: [any AttributedStringConvertible]
    var context: Context
    var attributes: Attributes {
        get { context.environment.attributes }
        set { context.environment.attributes = newValue }
    }

    let stylesheet: Stylesheet
    var listLevel = 0
    var headingPath: [String] = []
    var makeCheckboxURL: ((ListItem) -> URL?)?

    var highlightCode: ((Code) -> any AttributedStringConvertible)? {
        context.environment.highlightCode
    }

    var attributedStringStack: [NSMutableAttributedString] = [NSMutableAttributedString()]
    var attributedString: NSMutableAttributedString {
        get { attributedStringStack[attributedStringStack.endIndex-1] }
    }

    var customLinkVisitor: ((Link, NSAttributedString) -> any AttributedStringConvertible)?

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

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> () {
        var attributes = attributes
        let code = codeBlock.code.trimmingCharacters(in: .whitespacesAndNewlines)
        if let h = highlightCode {
            let result = h(Code(language: codeBlock.language, code: codeBlock.code)).attributedString(context: &context)
            for r in result {
                attributedString.append(r)
            }
        } else {
            stylesheet.codeBlock(attributes: &attributes)
            attributedString.append(NSAttributedString(string: code, attributes: attributes))
        }
    }

    func visitInlineHTML(_ inlineHTML: InlineHTML) -> () {
        fatalError()
    }

    func visitHTMLBlock(_ html: HTMLBlock) -> () {
        fatalError()
    }

    mutating func visitSymbolLink(_ symbolLink: SymbolLink) -> () {
        let prefixStr = "io.objc.interpolate."
        var remainder = symbolLink.destination ?? ""
        guard remainder.hasPrefix(prefixStr) else {
            attributedString.append(NSAttributedString(string: remainder, attributes: attributes))
            return
        }
        remainder.removeFirst(prefixStr.count)
        guard let i = Int(remainder) else {
            fatalError()
        }
        let component = interpolationSegments[i]
        attributedString.append(component.run(context: &context))
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

        stylesheet.link(attributes: &attributes, destination: link.destination ?? "")
        if let c = customLinkVisitor {
            attributedStringStack.append(NSMutableAttributedString())
        }
        for child in link.children {
            visit(child)
        }

        if let c = customLinkVisitor {
            let linkText = attributedStringStack.popLast()!
            attributes = original
            for part in c(link, linkText).attributedString(context: &context) {
                attributedString.append(part)
            }
        }
    }

    mutating func visitHeading(_ heading: Heading) -> () {
        let original = attributes
        defer { attributes = original }
        let l = heading.level-1
        if headingPath.count > l {
            headingPath.removeSubrange(l...)
        }
        if headingPath.count < l {
            headingPath.append(contentsOf: Array(repeating: "", count: l-headingPath.count))
        }
        headingPath.append(heading.plainText)
        stylesheet.headingLink(path: headingPath, attributes: &attributes)

        stylesheet.heading(level: heading.level, attributes: &attributes)
        attributes.heading(title: heading.plainText, level: heading.level)
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

        stylesheet.list(attributes: &attributes, level: listLevel)
        listLevel += 1
        defer { listLevel -= 1 }

        let isOrdered = list is OrderedList
        let startIndex = Int((list as? OrderedList)?.startIndex ?? 1)

        attributes.headIndent = attributes.tabStops[1].location

        for (item, number) in zip(list.listItems, startIndex...) {
            // Append list item prefix
            let prefix: String
            var prefixAttributes = attributes

            if let checkbox = item.checkbox {
                switch checkbox {
                case .checked:
                    prefix = stylesheet.checkboxCheckedPrefix
                    stylesheet.checkboxCheckedPrefix(attributes: &prefixAttributes)
                case .unchecked:
                    prefix = stylesheet.checkboxUncheckedPrefix
                    stylesheet.checkboxUncheckedPrefix(attributes: &prefixAttributes)
                }
                if let url = makeCheckboxURL?(item) {
                    prefixAttributes.link = url
                }
            } else {
                if isOrdered {
                    stylesheet.orderedListItemPrefix(attributes: &prefixAttributes)
                    prefix = stylesheet.orderedListItemPrefix(number: number)
                } else {
                    stylesheet.unorderedListItemPrefix(attributes: &prefixAttributes)
                    prefix = stylesheet.unorderedListItemPrefix
                }
            }
            
            if number == list.childCount {
                // Restore spacing for last list item
                attributes.paragraphSpacing = original.paragraphSpacing
                prefixAttributes.paragraphSpacing = original.paragraphSpacing
            }
            
            attributedString.append(NSAttributedString(string: "\t", attributes: attributes))
            attributedString.append(NSAttributedString(string: prefix, attributes: prefixAttributes))
            attributedString.append(NSAttributedString(string: "\t", attributes: attributes))

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

        var first = true
        for child in listItem.children {
            if !first {
                attributedString.append(NSAttributedString(string: "\n", attributes: attributes))
            }
            first = false
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

fileprivate struct MarkdownHelper: AttributedStringConvertible {
    var segments: [any AttributedStringConvertible]
    var document: Document
    var stylesheet: any Stylesheet
    var makeCheckboxURL: ((ListItem) -> URL?)?

    func attributedString(context: inout Context) -> [NSAttributedString] {
        var copy = document
        let rewriters = context.environment.rewriters
        copy.rewrite(rewriters)
        let linkRewriter = context.environment.linkRewriter
        var walker = AttributedStringWalker(interpolationSegments: segments, context: context, stylesheet: stylesheet, makeCheckboxURL: makeCheckboxURL, customLinkVisitor: linkRewriter)
        walker.visit(copy)
        context.state = walker.context.state
        return [walker.attributedString]
    }
}

public struct Markdown: AttributedStringConvertible {
    public var source: MarkdownString
    public init(_ source: MarkdownString) {
        self.source = source
    }

    public func attributedString(context: inout Context) -> [NSAttributedString] {
        EnvironmentReader(\.markdownStylesheet) { stylesheet in
            MarkdownHelper(string: source, stylesheet: stylesheet)
        }.attributedString(context: &context)
    }
}

extension Document {
    mutating func rewrite(_ rewriters: [any MarkupRewriter]) {
        for var r in rewriters.reversed() {
            guard let d = r.visit(self) as? Document else {
                fatalError()
            }
            self = d
        }
    }
}

extension MarkdownHelper {
    init(string: MarkdownString, stylesheet: any Stylesheet)  {
        var components: [any AttributedStringConvertible] = []
        let str = string.pieces.map {
            switch $0 {
            case .raw(let s): return s
            case .component(let c):
                defer { components.append(c) }
                return "``io.objc.interpolate.\(components.count)``"
            }
        }.joined(separator: "")
        self.segments = components
        self.document = Document(parsing: str, options: .parseSymbolLinks)
        self.stylesheet = stylesheet
        self.makeCheckboxURL = nil
    }

    init(verbatim: String, stylesheet: any Stylesheet) {
        self.segments = []
        self.document = Document(parsing: verbatim, options: .parseSymbolLinks)
        self.stylesheet = stylesheet
        self.makeCheckboxURL = nil
    }
}

struct MarkdownStylesheetKey: EnvironmentKey {
    static var defaultValue: any Stylesheet = .default
}

extension EnvironmentValues {
    public var markdownStylesheet: any Stylesheet {
        get { self[MarkdownStylesheetKey.self] }
        set { self[MarkdownStylesheetKey.self] = newValue }
    }
}

extension String {
    public func markdown(stylesheet: any Stylesheet = .default, highlightCode: ((Code) -> NSAttributedString)? = nil) -> some AttributedStringConvertible {
        MarkdownHelper(verbatim: self, stylesheet: stylesheet)
    }
}

extension Document {
    public func markdown(stylesheet: any Stylesheet = .default, makeCheckboxURL: ((ListItem) -> URL?)? = nil) -> some AttributedStringConvertible {
        MarkdownHelper(segments: [], document: self, stylesheet: stylesheet, makeCheckboxURL: makeCheckboxURL)
    }
}
