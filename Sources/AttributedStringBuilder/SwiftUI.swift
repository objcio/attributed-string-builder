import Cocoa
import SwiftUI

extension AttributedStringConvertible {
    public func background<Content: View>(@ViewBuilder content: () -> Content) -> some AttributedStringConvertible {
        let c = content()
        return modify(perform: {
            $0.backgroundView = AnyView(c.font(Font($0.computedFont)))
        })
    }
}

public struct Embed<V: View>: AttributedStringConvertible {
    public init(proposal: ProposedViewSize = .unspecified, scale: CGFloat = 0.5, @ViewBuilder view: () -> V) {
        self.proposal = proposal
        self.view = view()
        self.scale = scale
    }

    var scale: CGFloat
    var proposal: ProposedViewSize = .unspecified
    @ViewBuilder var view: V


    @MainActor
    public var size: CGSize {
        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = proposal
        return renderer.nsImage!.size
    }

    @MainActor
    public func attributedString(context: inout Context) -> [NSAttributedString] {
        let renderer = ImageRenderer(content: view
            .font(SwiftUI.Font(context.environment.attributes.computedFont)))
        renderer.proposedSize = proposal
        let resultSize = renderer.nsImage!.size
        let data = NSMutableData()
        renderer.render { size, renderer in
            var mediaBox = CGRect(origin: .zero, size: resultSize)
            guard let consumer = CGDataConsumer(data: data),
                  let pdfContext =  CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
            else {
                return
            }
            pdfContext.beginPDFPage(nil)
            pdfContext.translateBy(x: mediaBox.size.width / 2 - size.width / 2,
                                   y: mediaBox.size.height / 2 - size.height / 2)
            renderer(pdfContext)
            pdfContext.endPDFPage()
            pdfContext.closePDF()
        }
        let i = NSImage(data: data as Data)!
        i.size.width *= scale
        i.size.height *= scale
        return i.attributedString(context: &context)
    }
}


