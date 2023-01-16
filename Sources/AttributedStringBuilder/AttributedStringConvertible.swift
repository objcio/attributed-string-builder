import Foundation

public protocol AttributedStringConvertible {
    func attributedString(environment: EnvironmentValues) async -> [NSAttributedString]
}



extension String: AttributedStringConvertible {
    public func attributedString(environment: EnvironmentValues) -> [NSAttributedString] {
        [.init(string: self, attributes: environment.attributes.atts)]
    }
}

extension AttributedString: AttributedStringConvertible {
    public func attributedString(environment: EnvironmentValues) -> [NSAttributedString] {
        [.init(self)]
    }
}

extension NSAttributedString: AttributedStringConvertible {
    public func attributedString(environment: EnvironmentValues) -> [NSAttributedString] {
        [self]
    }
}

extension Array: AttributedStringConvertible where Element == AttributedStringConvertible {
    public func attributedString(environment: EnvironmentValues) async -> [NSAttributedString] {
        var result: [NSAttributedString] = []
        for el in self {
            result.append(contentsOf: await el.attributedString(environment: environment))
        }
        return result
    }
}


