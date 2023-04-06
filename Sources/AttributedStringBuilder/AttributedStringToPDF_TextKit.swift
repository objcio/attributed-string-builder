import Cocoa

/*
 
 From Marcin Krzyzanowski:
 
 the algo is "greedy" approach: procees pages from the beginning to end of the book and create/update page sizes based on what's found on current page. First, set page footer and header, then add annotations if any. Page header/footer is static size, but annotations area size is dynamic. For each page try to layout all three headers sections + text body section. If the number of annotations (for the current page) before and after adding annotations/headers is different, that means header/footers caused cut the page earlier → text with annotation will be now on the following (next) page → update annotations footer for the current page while keep the text body size. Then proceed to next page. It works because we process page by page while adjusting the page "end index".

 */

import Cocoa

struct MyHeading {
    var pageNumber: Int
    var title: String
    var level: Int
    var bounds: CGRect
}

struct NamedPart {
    var pageNumber: Int
    var name: String
    var bounds: CGRect
}

struct MyLink {
    var pageNumber: Int
    var name: String
    var bounds: CGRect
}


public struct PageInfo {
    public var pageNumber: Int
    public var chapterTitle: String
}

extension NSAttributedString {
//    public func pdf(size: CGSize = .a4, inset: CGSize = .init(width: .pointsPerInch, height: .pointsPerInch)) -> Data {
    public func fancyPDF(
        pageSize: CGSize = .a4,
        pageMargin: CGSize = .init(width: .pointsPerInch, height: .pointsPerInch),
        header: Accessory? = nil,
        footer: Accessory? = nil,
        annotationsPadding: NSEdgeInsets = .init()
    ) -> Data {
        let r = PDFRenderer(pageSize: pageSize,
                            pageMargin: pageMargin,
                            string: self,
                            header: header,
                            footer: footer,
                            annotationsPadding: annotationsPadding)
        return r.render()
    }
}

public struct Accessory {
    public var string: (PageInfo) -> NSAttributedString
    public var padding: NSEdgeInsets

    public init(string: @escaping (PageInfo) -> NSAttributedString, padding: NSEdgeInsets) {
        self.string = string
        self.padding = padding
    }
}

public struct Annotation: Hashable {
    public let characterRange: NSRange
    public let string: NSAttributedString

    public init(characterRange: NSRange, string: NSAttributedString) {
        self.characterRange = characterRange
        self.string = string
    }
}


// From: https://stackoverflow.com/questions/58483933/create-pdf-with-multiple-pages
class PDFRenderer {


    private struct Page {
        let container: NSTextContainer
        let annotations: AccessoryInfo?
        let header: AccessoryInfo?
        let footer: AccessoryInfo?
    }

    private struct AccessoryInfo {
        // keep reference
        private let storage: NSTextStorage
        private let manager: NSLayoutManager

        var containers: [NSTextContainer] {
            manager.textContainers
        }

        var containersHeight: CGFloat {
            containers.map(\.size.height).reduce(0, +)
        }

        init(manager: NSLayoutManager) {
            self.storage = manager.textStorage!
            self.manager = manager
        }
    }

    private var pageSize: CGSize
    private var pageMargin: CGSize
    private var header: Accessory?
    private var footer: Accessory?
    private var annotationsPadding: NSEdgeInsets

    private var pageRect: CGRect
    private var frameRect: CGRect

    private var bookLayoutManager: NSLayoutManager
    private var bookTextStorage: NSTextStorage

    private var pages: [Page] = []
    private(set) var headings: [MyHeading] = []
    private(set) var namedParts: [NamedPart] = []
    private(set) var links: [MyLink] = []

    public init(
        pageSize: CGSize,
        pageMargin: CGSize,
        string: NSAttributedString,
        header: Accessory? = nil,
        footer: Accessory? = nil,
        annotationsPadding: NSEdgeInsets = .init()
    ) {
        self.pageSize = pageSize
        self.pageMargin = pageMargin
        self.header = header
        self.footer = footer
        self.annotationsPadding = annotationsPadding
        self.pageRect = CGRect(origin: .zero, size: pageSize)
        self.frameRect = pageRect.insetBy(dx: pageMargin.width * 2, dy: pageMargin.height * 2)

        self.bookTextStorage = NSTextStorage(attributedString: string)
        self.bookLayoutManager = NSLayoutManager()
        bookLayoutManager.usesFontLeading = true
        bookLayoutManager.allowsNonContiguousLayout = true
        bookTextStorage.addLayoutManager(bookLayoutManager)
    }


    public func render() -> Data {
        var rect = pageRect
        let mutableData = NSMutableData()
        let consumer = CGDataConsumer(data: mutableData)!
        let context = CGContext(consumer: consumer, mediaBox: &rect, nil)!
        _render(context: context)
        return mutableData as Data
    }

    public func render(url: URL) {
        var rect = pageRect
        let context = CGContext(url as CFURL, mediaBox: &rect, nil)!
        _render(context: context)
    }

    private func _resetLayoutManager() {
        for i in 0..<bookLayoutManager.textContainers.count {
            bookLayoutManager.removeTextContainer(at: i)
        }
    }

    private func _layoutPages() {
        _resetLayoutManager()

        var pages: [Page] = []

        // return true until containers consume all glyphs
        func addMode() -> Bool {
            guard let lastPage = pages.last else { return true }
            let containerGlyphRange = bookLayoutManager.glyphRange(for: lastPage.container)
            return NSMaxRange(containerGlyphRange) < bookLayoutManager.numberOfGlyphs
        }

        while addMode() {

            func accessoryInfo(accessory: Accessory?) -> AccessoryInfo {
                let storage = NSTextStorage(attributedString: accessory?.string(.init(pageNumber: 0, chapterTitle: "Test")) ?? NSAttributedString())
                let layoutManager = NSLayoutManager()
                layoutManager.usesFontLeading = bookLayoutManager.usesFontLeading
                layoutManager.allowsNonContiguousLayout = bookLayoutManager.allowsNonContiguousLayout
                storage.addLayoutManager(layoutManager)

                layoutManager.addTextContainer(
                    NSTextContainer(size: CGSize(
                        width: frameRect.size.width - (accessory?.padding.horizontal ?? 0),
                        height: boundingRect(of: storage, maxWidth: frameRect.size.width).height + (accessory?.padding.vertical ?? 0))
                    )
                )

                return AccessoryInfo(manager: layoutManager)
            }

            func annotationsAccessoryInfo(pageContentContainer: NSTextContainer) -> AccessoryInfo {
                // Combine annotations and static footer
                let pageLayoutManager = pageContentContainer.layoutManager!
                let storage = NSTextStorage()
                let layoutManager = NSLayoutManager()
                layoutManager.usesFontLeading = bookLayoutManager.usesFontLeading
                layoutManager.allowsNonContiguousLayout = bookLayoutManager.allowsNonContiguousLayout
                storage.addLayoutManager(layoutManager)

                let characterRange = pageLayoutManager.characterRange(forGlyphRange: pageLayoutManager.glyphRange(for: pageContentContainer), actualGlyphRange: nil)
                let annotations = bookTextStorage.annotations(in: characterRange)
                if !annotations.isEmpty {
                    for (offset, element) in annotations.map(\.string).enumerated() {
                        storage.append(element)
                        if offset < annotations.count - 1 {
                            storage.append(NSAttributedString(string: "\n"))
                        }
                    }

                    // Add annotations container
                    layoutManager.addTextContainer(
                        NSTextContainer(size: CGSize(
                            width: frameRect.size.width - annotationsPadding.horizontal,
                            height: boundingRect(of: storage, maxWidth: frameRect.size.width).height + annotationsPadding.vertical)
                        )
                    )
                }

                return AccessoryInfo(manager: layoutManager)
            }

            let pageContentContainer = NSTextContainer(size: frameRect.size)
            bookLayoutManager.addTextContainer(pageContentContainer)
            let pageLayoutManager = pageContentContainer.layoutManager!

            let pageAnnotationsBefore = bookTextStorage.annotations(in: pageLayoutManager.characterRange(forGlyphRange: pageLayoutManager.glyphRange(for: pageContentContainer), actualGlyphRange: nil))

            // Add header container
            let pageHeaderInfo = accessoryInfo(accessory: header)
            // Add annotations if any
            var annotationsInfo = annotationsAccessoryInfo(pageContentContainer: pageContentContainer)
            // Add footer container
            var pageFooterInfo = accessoryInfo(accessory: footer)

            // adjust current page contentContainer height and re-layout
            pageContentContainer.size = CGSize(
                width: max(1, pageContentContainer.size.width),
                height: max(1, pageContentContainer.size.height
                        - annotationsInfo.containersHeight
                        - pageHeaderInfo.containersHeight
                        - pageFooterInfo.containersHeight)
            )

            // if pageAnnotationsBefore != pageAnnotationsAfter
            //  keep the pageContentContainer size and use pageAnnotationsAfter
            //  recalculate annotationsInfo and pageFooterInfo
            let pageAnnotationsAfter = bookTextStorage.annotations(in: pageLayoutManager.characterRange(forGlyphRange: pageLayoutManager.glyphRange(for: pageContentContainer), actualGlyphRange: nil))
            if pageAnnotationsAfter.count != pageAnnotationsBefore.count {
                annotationsInfo = annotationsAccessoryInfo(pageContentContainer: pageContentContainer)
                pageFooterInfo = accessoryInfo(accessory: footer)
            }

            pages.append(
                Page(
                    container: pageContentContainer,
                    annotations: annotationsInfo,
                    header: pageHeaderInfo,
                    footer: pageFooterInfo
                )
            )
        }

        self.pages = pages
    }

    private func _render(context: CGContext) {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)

        defer {
            NSGraphicsContext.restoreGraphicsState()
        }

        _layoutPages()

        // Print containers
        for (pageNo, page) in pages.enumerated() {
            var x = pageRect
            context.beginPage(mediaBox: &x)
            defer { context.endPage() }

            context.translateBy(x: 0, y: pageRect.height)
            context.concatenate(.init(scaleX: 1, y: -1))

            let range = bookLayoutManager.glyphRange(for: page.container)
            let location = range.location + range.length/2
            let attributes = bookTextStorage.attributes(at: location, effectiveRange: nil)
            if let pageBackground = attributes[.pageBackground] as? NSColor {
                context.saveGState()
                context.setFillColor(pageBackground.cgColor)
                context.fill(pageRect)
                context.restoreGState()
            }

            // Draw header and content top bottom
            do {
                var origin = frameRect.origin

                // Draw header
                if let header = self.header, let headerInfoContainers = page.header?.containers {
                    origin.y += header.padding.top
                    origin = _draw(containers: headerInfoContainers, startAt: origin)
                    origin.y -= header.padding.top
                }

                let pageTop = origin.y

                // Draw content
                bookLayoutManager.drawBackground(forGlyphRange: range, at: origin)
                bookLayoutManager.drawGlyphs(forGlyphRange: range, at: origin)
                origin.y += page.container.size.height

                // Compute the local position within the page for the range
                // TODO: this isn't 100% correct yet
                func computeBounds(range: NSRange) -> CGRect {
                    var rect = bookLayoutManager.boundingRect(forGlyphRange: range, in: page.container)
                    rect.origin.y = pageTop + (page.container.size.height-rect.origin.y+rect.height) // flip coordinates
                    rect.origin.x += origin.x
                    return rect
                }

                let headings: [(value: HeadingInfo, range: NSRange)] = bookTextStorage.values(for: .heading, in: range)
                self.headings.append(contentsOf: headings.map { h in
                    return MyHeading(pageNumber: pageNo, title: h.value.text, level: h.value.level, bounds: computeBounds(range: h.range))
                })

                let namedParts: [(value: String, range: NSRange)] = bookTextStorage.values(for: .internalName, in: range)
                self.namedParts.append(contentsOf: namedParts.map { part in
                    NamedPart(pageNumber: pageNo, name: part.value, bounds: computeBounds(range: part.range))
                })

                let links: [(value: String, range: NSRange)] = bookTextStorage.values(for: .internalLink, in: range)
                self.links.append(contentsOf: links.map { part in
                    MyLink(pageNumber: pageNo, name: part.value, bounds: computeBounds(range: part.range))
                })

                // Draw Annotations
                if let annotationContainers = page.annotations?.containers {
                    origin.y += annotationsPadding.top
                    origin = _draw(containers: annotationContainers, startAt: origin)
                    origin.y -= annotationsPadding.top
                }

                // Draw Footer
                if let footer = self.footer, let footerInfoContainers = page.footer?.containers {
                    origin.y += footer.padding.top
                    origin = _draw(containers: footerInfoContainers, startAt: origin)
                    origin.y -= footer.padding.top
                }
            }
        }
        context.closePDF()
    }

    private func _draw(containers: [NSTextContainer], startAt origin: CGPoint) -> CGPoint {
        var origin = origin
        for container in containers where container.layoutManager != nil {
            let manager = container.layoutManager!
            let range = manager.glyphRange(for: container)
            manager.drawBackground(forGlyphRange: range, at: origin)
            manager.drawGlyphs(forGlyphRange: range, at: origin)
            origin.y += container.size.height
        }
        return origin
    }

}

/*
extension NSAttributedString {

    public func pdf(
        pageSize: CGSize = .a4,
        pageMargin: CGSize = .init(width: 10 * CGFloat.pointsPerMM, height: 10 * CGFloat.pointsPerMM),
        header headerString: NSAttributedString? = nil,
        headerPadding: NSEdgeInsets = .init(),
        footer footerString: NSAttributedString? = nil,
        footerPadding: NSEdgeInsets = .init(),
        annotationsPadding: NSEdgeInsets = .init()
    ) -> Data {
        PDFRenderer(
            pageSize: pageSize,
            pageMargin: pageMargin,
            string: self,
            header: headerString.map {
                PDFRenderer.Accessory(string: $0, padding: headerPadding)
            },
            footer: footerString.map {
                PDFRenderer.Accessory(string: $0, padding: footerPadding)
            },
            annotationsPadding: annotationsPadding
        ).render()
    }

}
 */



private extension NSAttributedString {

    func values<Value>(type: Value.Type = Value.self, for key: NSAttributedString.Key, in range: NSRange? = nil) -> [(value: Value, range: NSRange)] {
        var values: [(Value, NSRange)] = []
        enumerateAttribute(key, in: range ?? NSRange(location: 0, length: length)) { value, range, stop in
            guard let v = value as? Value else {
                return
            }

            values.append((v, range))
        }
        return values
    }

    func annotations(in range: NSRange? = nil) -> [Annotation] {
        var annotations: [Annotation] = []
        enumerateAttribute(.annotation, in: range ?? NSRange(location: 0, length: length)) { value, range, stop in
            guard let annotationString = value as? NSAttributedString else {
                return
            }

            annotations.append(
                Annotation(
                    characterRange: range,
                    string: annotationString
                )
            )
        }
        return annotations
    }

}

private func boundingRect(of attributedString: NSAttributedString, maxWidth: CGFloat, lineFragmentPadding: CGFloat? = nil) -> CGSize {
    let textStorage = NSTextStorage(attributedString: attributedString)
    let container = NSTextContainer(size: NSSize(width: maxWidth, height: .greatestFiniteMagnitude))
    let layoutManager = NSLayoutManager()
    layoutManager.addTextContainer(container)
    layoutManager.usesFontLeading = true
    layoutManager.allowsNonContiguousLayout = true
    textStorage.addLayoutManager(layoutManager)
    if let lineFragmentPadding = lineFragmentPadding {
        container.lineFragmentPadding = lineFragmentPadding
    }
    _ = layoutManager.glyphRange(for: container)
    return layoutManager.boundingRect(forGlyphRange: layoutManager.glyphRange(for: container), in: container).size
}

private extension NSEdgeInsets {
    var horizontal: CGFloat {
        left + right
    }

    var vertical: CGFloat {
        top + bottom
    }
}