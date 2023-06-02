import Cocoa

extension NSImage: AttributedStringConvertible {
    public func attributedString(context: inout Context) -> [NSAttributedString] {
        let attachment = NSTextAttachment()
        attachment.image = self
        let str = NSMutableAttributedString(attachment: attachment)
        str.addAttributes(context.environment.attributes.attachmentAtts, range: NSRange(location: 0, length: str.length))
        return [
            str
        ]
    }
}
