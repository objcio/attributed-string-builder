import Cocoa

@resultBuilder
public
struct AttributedStringBuilder {
    public static func buildBlock(_ components: AttributedStringConvertible...) -> some AttributedStringConvertible {
        [components]
    }

    public static func buildOptional<C: AttributedStringConvertible>(_ component: C?) -> some AttributedStringConvertible {
        component.map { [$0] } ?? []
    }
}

extension AttributedStringConvertible {
    public func run(environment: EnvironmentValues) async -> NSAttributedString {
        await Joined(separator: "", content: {
                self
            }).single(environment: environment)       
    }
}

