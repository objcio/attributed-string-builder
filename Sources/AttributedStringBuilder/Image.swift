import Cocoa

extension NSImage: AttributedStringConvertible {
    public func attributedString(context: inout Context) -> [NSAttributedString] {
        let attachment = NSTextAttachment()
        attachment.image = self
        return [
            .init(attachment: attachment)
        ]
    }
}
