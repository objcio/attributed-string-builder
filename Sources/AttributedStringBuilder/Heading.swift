//

import Foundation

extension NSAttributedString.Key {
    static public let heading: Self = .init("io.objc.heading")
}

public struct HeadingInfo: Codable, Hashable {
    public init(text: String, level: Int) {
        self.text = text
        self.level = level
    }

    public var text: String
    public var level: Int
}

extension Attributes {
    mutating func heading(title: String, level: Int) {
        customAttributes[NSAttributedString.Key.heading.rawValue] = HeadingInfo(text: title, level: level)
    }
}
