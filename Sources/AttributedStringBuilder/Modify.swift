import AppKit

struct Modify: AttributedStringConvertible {
    var modify: (inout Attributes) -> ()
    var contents: AttributedStringConvertible

    func attributedString(environment: EnvironmentValues) async -> [NSAttributedString] {
        var copy = environment
        modify(&copy.attributes)
        return await contents.attributedString(environment: copy)
    }
}

extension AttributedStringConvertible {
    public func modify(perform: @escaping (inout Attributes) -> () ) -> some AttributedStringConvertible {
        Modify(modify: perform, contents: self)
    }
    public func bold() -> some AttributedStringConvertible {
        modify { $0.bold = true }
    }

    public func textColor(_ color: NSColor) -> some AttributedStringConvertible {
        modify { $0.textColor = color }
    }
}


