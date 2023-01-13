import Foundation
import Cocoa

extension CGFloat {
    public static var pointsPerInch: CGFloat { 72 }
    public static var pointsPerMM: CGFloat { pointsPerInch / 25.4 }
}

extension CGSize {
    static public let a4 = CGSize(width: 8.25 * .pointsPerInch, height: 11.75 * .pointsPerInch)
}

extension NSAttributedString {
    public func pdf(size: CGSize = .a4, inset: CGSize = .init(width: .pointsPerInch, height: .pointsPerInch)) -> Data {

        let storage = NSTextStorage(attributedString: self)
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)

        let data = NSMutableData()
        let consumer = CGDataConsumer(data: data)!
        var pageRect = CGRect(origin: .zero, size: size)
        let contentRect = pageRect.insetBy(dx: inset.width, dy: inset.height)
        let context = CGContext(consumer: consumer, mediaBox: &pageRect, nil)!

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)

        var needsMoreContainers = true
        while needsMoreContainers {
            let container = NSTextContainer(size: contentRect.size)
            layoutManager.addTextContainer(container)
            let range = layoutManager.glyphRange(for: container)
            needsMoreContainers = range.location + range.length < layoutManager.numberOfGlyphs

            context.beginPDFPage(nil)
            context.translateBy(x: 0, y: pageRect.height)
            context.scaleBy(x: 1, y: -1)
            layoutManager.drawBackground(forGlyphRange: range, at: contentRect.origin)
            layoutManager.drawGlyphs(forGlyphRange: range, at: contentRect.origin)
            context.endPDFPage()
        }
        context.closePDF()
        return data as Data
    }
}
