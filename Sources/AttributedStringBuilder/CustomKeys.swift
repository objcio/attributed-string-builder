import Foundation

extension NSAttributedString.Key {
    // Set this key to make an entire PDF page filled with this color as the background color
    static public let pageBackground = NSAttributedString.Key("pageBackground")
    static public let annotation = NSAttributedString.Key("48611742167f11ed861d0242ac120002")
    static public let pageMargin = NSAttributedString.Key("io.objc.pageMargin")
}

extension Attributes {
    var annotation: NSAttributedString {
        get {
            customAttributes[NSAttributedString.Key.annotation.rawValue] as! NSAttributedString
        }
        set {
            customAttributes[NSAttributedString.Key.annotation.rawValue] = newValue
        }
    }

    public var pageMargin: NSEdgeInsets? {
        get {
            customAttributes[NSAttributedString.Key.pageMargin.rawValue] as? NSEdgeInsets
        }
        set {
            customAttributes[NSAttributedString.Key.pageMargin.rawValue] = newValue
        }
    }
}
