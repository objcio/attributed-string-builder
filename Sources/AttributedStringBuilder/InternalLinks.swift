import Cocoa

extension NSAttributedString.Key {
    static let internalName: Self = .init(rawValue: "io.objc.internalName")
    static let internalLink: Self = .init(rawValue: "io.objc.internalLink")
}

extension AttributedStringConvertible {
    public func internalName<N: RawRepresentable>(name: N) -> some AttributedStringConvertible where N.RawValue == String {
        self.modify {
            $0.customAttributes[NSAttributedString.Key.internalName.rawValue] = name.rawValue
        }
    }

    public func internalLink<N: RawRepresentable>(name: N) -> some AttributedStringConvertible where N.RawValue == String {
        self.modify {
            $0.customAttributes[NSAttributedString.Key.internalLink.rawValue] = name.rawValue
        }
    }
}
