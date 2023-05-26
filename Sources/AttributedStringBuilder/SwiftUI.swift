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

extension View {
    func snapshot(proposal: ProposedViewSize) -> NSImage? {
        let controller = NSHostingController(rootView: self.frame(width: proposal.width, height: proposal.height))
        let targetSize = controller.view.intrinsicContentSize
        let contentRect = NSRect(origin: .zero, size: targetSize)

        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = controller.view

        guard
            let bitmapRep = controller.view.bitmapImageRepForCachingDisplay(in: contentRect)
        else { return nil }

        controller.view.cacheDisplay(in: contentRect, to: bitmapRep)
        let image = NSImage(size: bitmapRep.size)
        image.addRepresentation(bitmapRep)
        return image
    }
}

struct DefaultEmbedProposal: EnvironmentKey {
    static let defaultValue: ProposedViewSize = .unspecified
}

extension EnvironmentValues {
    public var defaultProposal: ProposedViewSize {
        get { self[DefaultEmbedProposal.self] }
        set { self[DefaultEmbedProposal.self] = newValue }
    }
}

public struct Embed<V: View>: AttributedStringConvertible {
    public init(proposal: ProposedViewSize? = nil, scale: CGFloat = 1, bitmap: Bool = false, @ViewBuilder view: () -> V) {
        self.proposal = proposal
        self.view = view()
        self.scale = scale
        self.bitmap = bitmap
    }

    var scale: CGFloat
    var proposal: ProposedViewSize?
    var bitmap: Bool
    var view: V

    @MainActor
    public func attributedString(context: inout Context) -> [NSAttributedString] {
        let proposal = self.proposal ?? context.environment.defaultProposal
        if bitmap {
            let i = view.snapshot(proposal: proposal)!
            i.size.width *= scale
            i.size.height *= scale
            return i.attributedString(context: &context)
        } else {
            let renderer = ImageRenderer(content: view
                .font(SwiftUI.Font(context.environment.attributes.computedFont)))
            renderer.proposedSize = proposal
            let _ = renderer.nsImage! // this is necessary to get the correct size in the .render closure, even for pdf
            let data = NSMutableData()
            renderer.render { size, renderer in
                var mediaBox = CGRect(origin: .zero, size: size)
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
}


