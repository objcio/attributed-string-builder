import AppKit

struct Modify: AttributedStringConvertible {
    var modify: (inout Attributes) -> ()
    var contents: AttributedStringConvertible

    func attributedString(environment: EnvironmentValues) -> [NSAttributedString] {
        var copy = environment
        modify(&copy.attributes)
        return contents.attributedString(environment: copy)
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


