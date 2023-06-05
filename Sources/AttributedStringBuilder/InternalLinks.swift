import Cocoa

extension NSAttributedString.Key {
    static let internalName: Self = .init(rawValue: "io.objc.internalName")
    static let internalLink: Self = .init(rawValue: "io.objc.internalLink")
}

extension AttributedStringConvertible {
    public func internalName<N: RawRepresentable>(name: N) -> some AttributedStringConvertible where N.RawValue == String {
        modify { $0.setInternalName(name: name) }
    }

    public func internalLink<N: RawRepresentable>(name: N) -> some AttributedStringConvertible where N.RawValue == String {
        self.modify {
            $0.setInternalLink(name: name)
        }
    }
}

extension Attributes {
    mutating public func setInternalName<N: RawRepresentable>(name: N) {
        customAttributes[NSAttributedString.Key.internalName.rawValue] = name.rawValue
    }

    mutating public func setInternalLink<N: RawRepresentable>(name: N) {
        customAttributes[NSAttributedString.Key.internalLink.rawValue] = name.rawValue
    }
}
