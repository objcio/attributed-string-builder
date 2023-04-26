import AppKit

struct Modify: AttributedStringConvertible {
    var modify: (inout Attributes) -> ()
    var contents: AttributedStringConvertible

    func attributedString(context: inout Context) -> [NSAttributedString] {
        let old = context.environment.attributes
        defer { context.environment.attributes = old }
        modify(&context.environment.attributes)
        return contents.attributedString(context: &context)
    }
}

extension AttributedStringConvertible {
    public func modify(perform: @escaping (inout Attributes) -> () ) -> some AttributedStringConvertible {
        Modify(modify: perform, contents: self)
    }

    public func bold() -> some AttributedStringConvertible {
        modify { $0.bold = true }
    }

    public func superscript() -> some AttributedStringConvertible {
        modify {
            $0.customAttributes[NSAttributedString.Key.superscript.rawValue] = true
        }
    }

    public func textColor(_ color: NSColor) -> some AttributedStringConvertible {
        modify { $0.textColor = color }
    }
}


