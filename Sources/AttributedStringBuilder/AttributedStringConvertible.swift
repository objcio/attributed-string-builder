import Foundation

public struct Context {
    public init(environment: EnvironmentValues) {
        self.environment = environment
    }
    
    public var environment: EnvironmentValues
    public var state: StateValues = .init()
}

public protocol AttributedStringConvertible {
    @MainActor
    func attributedString(context: inout Context) -> [NSAttributedString]
}

public struct Group<Content>: AttributedStringConvertible where Content: AttributedStringConvertible {
    var content: Content

    public init(@AttributedStringBuilder content: () -> Content) {
        self.content = content()
    }

    @MainActor
    public func attributedString(context: inout Context) -> [NSAttributedString] {
        content.attributedString(context: &context)
    }
}

extension String: AttributedStringConvertible {
    public func attributedString(context: inout Context) -> [NSAttributedString] {
        [.init(string: self, attributes: context.environment.attributes.atts)]
    }
}

extension AttributedString: AttributedStringConvertible {
    public func attributedString(context: inout Context) -> [NSAttributedString] {
        [.init(self)]
    }
}

extension NSAttributedString: AttributedStringConvertible {
    public func attributedString(context: inout Context) -> [NSAttributedString] {
        [self]
    }
}

extension Array: AttributedStringConvertible where Element == AttributedStringConvertible {

    @MainActor
    public func attributedString(context: inout Context) -> [NSAttributedString] {
        var result: [NSAttributedString] = []
        for el in self {
            result.append(contentsOf: el.attributedString(context: &context))
        }
        return result
    }
}
