import Cocoa
import SwiftUI
import OSLog

/*
 
 From Marcin Krzyzanowski:
 
 the algo is "greedy" approach: procees pages from the beginning to end of the book and create/update page sizes based on what's found on current page. First, set page footer and header, then add annotations if any. Page header/footer is static size, but annotations area size is dynamic. For each page try to layout all three headers sections + text body section. If the number of annotations (for the current page) before and after adding annotations/headers is different, that means header/footers caused cut the page earlier → text with annotation will be now on the following (next) page → update annotations footer for the current page while keep the text body size. Then proceed to next page. It works because we process page by page while adjusting the page "end index".

 */

public struct MyHeading {
    public var pageNumber: Int
    public var title: String
    public var level: Int
    public var bounds: CGRect
}

public struct NamedPart {
    public var pageNumber: Int
    public var name: String
    public var bounds: CGRect
}

public struct MyLink {
    public var pageNumber: Int
    public var name: String
    public var bounds: CGRect
}


public struct PageInfo {
    public var pageNumber: Int
    public var chapterTitle: String
}

public struct PDFResult {
    public var data: Data
    public var headings: [MyHeading]
    public var namedParts: [NamedPart]
    public var links: [MyLink]
}

extension NSAttributedString {
    @MainActor
    public func fancyPDF(
        pageSize: CGSize = .a4,
        pageMargin: @escaping (_ pageNumber: Int) -> NSEdgeInsets = { _ in NSEdgeInsets(top: .pointsPerInch/2, left: .pointsPerInch/2, bottom: .pointsPerInch/2, right: .pointsPerInch/2)},
        header: ((Int) -> Accessory)? = nil,
        footer: Accessory? = nil,
        annotationsPadding: NSEdgeInsets = .init(),
        highlightWarnings: Bool = false
    ) -> PDFResult {
        let r = PDFRenderer(pageSize: pageSize,
                            pageMargin: pageMargin,
                            string: self,
                            header: header,
                            footer: footer,
                            annotationsPadding: annotationsPadding,
                            highlightWarnings: highlightWarnings
        )

        let data = r.render()
        return PDFResult(data: data, headings: r.headings, namedParts: r.namedParts, links: r.links)
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

// From: https://stackoverflow.com/questions/58483933/create-pdf-with-multiple-pages
@MainActor
class PDFRenderer {


    private struct Page {
        let container: NSTextContainer? // nil is an empty page
        let annotations: AccessoryInfo?
        let header: AccessoryInfo?
        let footer: AccessoryInfo?
        let frameRect: CGRect
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
    private var pageMargin: (_ pageNumber: Int) -> NSEdgeInsets
    private var header: ((Int) -> Accessory)?
    private var footer: Accessory?
    private var annotationsPadding: NSEdgeInsets
    private var highlightWarnings: Bool

    private var pageRect: CGRect

    private var bookLayoutManager: NSLayoutManager
    private var bookTextStorage: NSTextStorage

    private var pages: [Page] = []
    private(set) var headings: [MyHeading] = []
    private(set) var namedParts: [NamedPart] = []
    private(set) var links: [MyLink] = []

    public init(
        pageSize: CGSize,
        pageMargin: @escaping (_ pageNumber: Int) -> NSEdgeInsets,
        string: NSAttributedString,
        header: ((Int) -> Accessory)? = nil,
        footer: Accessory? = nil,
        annotationsPadding: NSEdgeInsets = .init(),
        highlightWarnings: Bool = false
    ) {
        self.pageSize = pageSize
        self.pageMargin = pageMargin
        self.header = header
        self.footer = footer
        self.annotationsPadding = annotationsPadding
        self.pageRect = CGRect(origin: .zero, size: pageSize)
        self.highlightWarnings = highlightWarnings

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
        var chapterTitle: String?

        // return true until containers consume all glyphs
        func addMode() -> Bool {
            guard let lastPage = pages.last(where: { $0.container != nil }) else { return true }
            let containerGlyphRange = bookLayoutManager.glyphRange(for: lastPage.container!)
            return NSMaxRange(containerGlyphRange) < bookLayoutManager.numberOfGlyphs
        }

        while addMode() {

            func computeFrameRect(margins: NSEdgeInsets) -> CGRect {
                var copy = pageRect
                copy.origin.x += margins.left
                copy.size.width -= margins.left + margins.right
                copy.origin.y += margins.top
                copy.size.height -= margins.top + margins.bottom
                return copy
            }

            let margins = pageMargin(pages.count)
            var frameRect = computeFrameRect(margins: margins)


            func accessoryInfo(accessory: Accessory?) -> AccessoryInfo {
                let storage = NSTextStorage(attributedString: accessory?.string(.init(pageNumber: pages.count + 1, chapterTitle: chapterTitle ?? "")) ?? NSAttributedString())
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
                    for (offset, element) in annotations.map(\.0).enumerated() {
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

            let pageGlyphRange = pageLayoutManager.glyphRange(for: pageContentContainer)
            let pageCharacterRange = pageLayoutManager.characterRange(forGlyphRange: pageGlyphRange, actualGlyphRange: nil)

            let spreadBreak = bookTextStorage.values(type: Bool.self, for: .spreadBreak, in: pageCharacterRange).first?.value ?? false
            if spreadBreak && pages.count.isMultiple(of: 2) {
                pages.append(Page(container: nil, annotations: nil, header: nil, footer: nil, frameRect: frameRect))
            }

            if let customMargins = bookTextStorage.values(type: NSEdgeInsets.self, for: .pageMargin, in: pageCharacterRange).first {
                frameRect = computeFrameRect(margins: customMargins.value)
                pageContentContainer.containerSize = frameRect.size
            }

            let headings = bookTextStorage.values(type: HeadingInfo.self, for: .heading, in: pageCharacterRange)
            if let info = headings.first(where: { $0.value.level == 1 }) {
                chapterTitle = info.value.text
            }

            let suppressHeadings = bookTextStorage.values(type: Bool.self, for: .suppressHeader, in: pageCharacterRange).map { $0.value }.allSatisfy { $0 }

            let pageAnnotationsBefore = bookTextStorage.annotations(in: pageCharacterRange)

            // Add header container
            let pageHeaderInfo = accessoryInfo(accessory: header?(pages.count))
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
                if pageAnnotationsAfter.count != pageAnnotationsBefore.count {
                    logger.warning("Annotations have changed multiple times on page \(pages.count)")
                }
            }

            pages.append(
                Page(
                    container: pageContentContainer,
                    annotations: annotationsInfo,
                    header: suppressHeadings ? nil : pageHeaderInfo,
                    footer: pageFooterInfo,
                    frameRect: frameRect
                )
            )
        }

        self.pages = pages
    }

    let logger = Logger()

    private func addWidowAndOrphanWarnings() {
        let range = bookTextStorage.string.startIndex..<bookTextStorage.string.endIndex
        bookTextStorage.string.enumerateSubstrings(in: range, options: .byParagraphs) { [unowned self] substring, substringRange, enclosingRange, stop in
            var trimmed = substringRange
            bookTextStorage.string.trim(&trimmed)
            let nsRange = NSRange(trimmed, in: bookTextStorage.string)
            let pageRanges = bookLayoutManager.glyphPageRanges(for: nsRange)
            guard pageRanges.count > 1 else { return }

            for range in [pageRanges.first!, pageRanges.last!] {
                if bookLayoutManager.lineFragmentRects(for: range).count == 1 {
                    let charRange = bookLayoutManager.characterRange(forGlyphRange: range, actualGlyphRange: nil)
//                    print((bookTextStorage.string as NSString).substring(with: charRange).utf8)
                    bookTextStorage.addAttribute(.backgroundColor, value: NSColor.yellow, range: charRange)
                }
            }
        }
    }

    private func _render(context: CGContext) {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)

        defer {
            NSGraphicsContext.restoreGraphicsState()
        }

        _layoutPages()
        if highlightWarnings {
            addWidowAndOrphanWarnings()
        }

        // Print containers
        for (pageNo, page) in pages.enumerated() {
            var x = pageRect
            context.beginPage(mediaBox: &x)
            defer { context.endPage() }

            guard let container = page.container else { continue } // empty page

            context.translateBy(x: 0, y: pageRect.height)
            context.concatenate(.init(scaleX: 1, y: -1))

            let range = bookLayoutManager.glyphRange(for: container)
            let location = range.location + range.length/2
            if location < bookTextStorage.length {
                let attributes = bookTextStorage.attributes(at: location, effectiveRange: nil)
                if let pageBackground = attributes[.pageBackground] as? NSColor {
                    context.saveGState()
                    context.setFillColor(pageBackground.cgColor)
                    context.fill(pageRect)
                    context.restoreGState()
                }
                
                if let backgroundView = attributes[.pageBackgroundView] as? AnyView {
                    let renderer = ImageRenderer(content: backgroundView)
                    renderer.proposedSize = ProposedViewSize(pageRect.size)
                    context.concatenate(.init(scaleX: 1, y: -1))
                    context.translateBy(x: 0, y: -pageRect.height)
                    renderer.render { size, renderer in
                        renderer(context)
                    }
                    // This manually restores the context, because saveGState/restoreGState didn't work here
                    context.translateBy(x: 0, y: pageRect.height)
                    context.concatenate(.init(scaleX: 1, y: -1))
                }
            }

            // Draw header and content top bottom
            do {
                var origin = page.frameRect.origin

                // Draw header
                if let header = self.header?(pageNo), let headerInfoContainers = page.header?.containers {
                    origin.y += header.padding.top
                    origin = _draw(containers: headerInfoContainers, startAt: origin)
                    origin.y -= header.padding.top
                }

                // Compute the local position within the page for the range
                func computeBounds(range: NSRange) -> CGRect {
                    var rect = bookLayoutManager.boundingRect(forGlyphRange: range, in: container)
                    rect.origin.y += page.frameRect.minY
                    rect.origin.x += page.frameRect.minX
                    rect.origin.y = pageRect.height - rect.origin.y - rect.height
                    return rect
                }

                func drawSwiftUIBackgrounds() {

                    let backgroundViews: [(value: AnyView, range: NSRange)] = bookTextStorage.values(for: .backgroundView, in: range)
                    for (value, range) in backgroundViews {
                        let b = computeBounds(range: range)
                        let renderer = ImageRenderer(content: value)
                        renderer.proposedSize = .init(width: b.width, height: b.height)
                        renderer.render(rasterizationScale: 1) { size, render in
                            context.saveGState()
                            context.concatenate(.init(scaleX: 1, y: -1))
                            context.translateBy(x: 0, y: -pageRect.height)
                            context.translateBy(x: b.minX, y: b.minY)
                            render(context)
                            context.restoreGState()
                        }
                    }
                }

                // Draw content
                bookLayoutManager.drawBackground(forGlyphRange: range, at: origin)
                drawSwiftUIBackgrounds()
                bookLayoutManager.drawGlyphs(forGlyphRange: range, at: origin)
                origin.y += container.size.height

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

    func annotations(in range: NSRange? = nil) -> [(NSAttributedString, NSRange)] {
        let result = values(type: NSAttributedString.self, for: .annotation, in: range)
        return result
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
