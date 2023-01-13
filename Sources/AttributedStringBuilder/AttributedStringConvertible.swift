import Foundation

public protocol AttributedStringConvertible {
    func attributedString(environment: Environment) async -> [NSAttributedString]
}

public struct Environment {
    public init(attributes: Attributes = Attributes()) {
        self.attributes = attributes
    }

    public var attributes = Attributes()
}

extension String: AttributedStringConvertible {
    public func attributedString(environment: Environment) -> [NSAttributedString] {
        [.init(string: self, attributes: environment.attributes.atts)]
    }
}

extension AttributedString: AttributedStringConvertible {
    public func attributedString(environment: Environment) -> [NSAttributedString] {
        [.init(self)]
    }
}

extension NSAttributedString: AttributedStringConvertible {
    public func attributedString(environment: Environment) -> [NSAttributedString] {
        [self]
    }
}

extension Array: AttributedStringConvertible where Element == AttributedStringConvertible {
    public func attributedString(environment: Environment) async -> [NSAttributedString] {
        var result: [NSAttributedString] = []
        for el in self {
            result.append(contentsOf: await el.attributedString(environment: environment))
        }
        return result
    }
}


