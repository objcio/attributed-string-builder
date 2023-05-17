//

import Foundation

enum Piece {
    case raw(String)
    case component(any AttributedStringConvertible)
}

// This is a string-like type that allows for interpolation of custom segments that conform to AttributedStringConvertible.
public struct MarkdownString: ExpressibleByStringInterpolation {
    var pieces: [Piece] = []

    public init(stringLiteral value: String) {
        pieces = [.raw(value)]
    }

    public init(stringInterpolation: Interpolation) {
        pieces = stringInterpolation.pieces
    }

    public struct Interpolation: StringInterpolationProtocol {
        var pieces: [Piece] = []
        public init(literalCapacity: Int, interpolationCount: Int) {
        }

        public init(stringLiteral value: StringLiteralType) {
            pieces = [.raw(value)]
        }

        mutating public func appendLiteral(_ s: String) {
            pieces.append(.raw(s))
        }

        mutating public func appendInterpolation<S: AttributedStringConvertible>(_ value: S) {
            pieces.append(.component(value))
        }
    }
}

