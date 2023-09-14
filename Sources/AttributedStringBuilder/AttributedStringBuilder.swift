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

    public static func buildEither<L, R>(first component: L) -> Either<L, R> {
        Either.l(component)
    }

    public static func buildEither<L, R>(second component: R) -> Either<L, R> {
        Either.r(component)
    }
}

public enum Either<A, B> {
    case l(A)
    case r(B)
}

extension Either: AttributedStringConvertible where A: AttributedStringConvertible, B: AttributedStringConvertible {
    public func attributedString(context: inout Context) -> [NSAttributedString] {
        switch self {
        case let .l(l): return l.attributedString(context: &context)
        case let .r(r): return r.attributedString(context: &context)
        }
    }
}

extension AttributedStringConvertible {
    @MainActor
    public func run(context: inout Context) -> NSAttributedString {
        Joined(separator: "", content: {
                self
        }).single(context: &context)       
    }
}

