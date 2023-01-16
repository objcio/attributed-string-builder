import Cocoa

extension NSImage: AttributedStringConvertible {
    public func attributedString(environment: EnvironmentValues) -> [NSAttributedString] {
        let attachment = NSTextAttachment()
        attachment.image = self
        return [
            .init(attachment: attachment)
        ]
    }
}
