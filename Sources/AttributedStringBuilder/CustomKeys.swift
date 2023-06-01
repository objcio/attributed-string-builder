import Foundation
import SwiftUI

extension NSAttributedString.Key {
    // Set this key to make an entire PDF page filled with this color as the background color
    static public let pageBackground = NSAttributedString.Key("pageBackground")
    static public let annotation = NSAttributedString.Key("48611742167f11ed861d0242ac120002")
    static public let pageMargin = NSAttributedString.Key("io.objc.pageMargin")
    static public let pageBackgroundView = NSAttributedString.Key("io.objc.pageBackgroundView")
    static public let spreadBreak = NSAttributedString.Key("io.objc.spreadBreak")
    static public let suppressHeader = NSAttributedString.Key("io.objc.suppressHeader")
    static public let backgroundView = NSAttributedString.Key("io.objc.backgroundView")
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

    public var pageBackgroundView: AnyView? {
        get {
            customAttributes[NSAttributedString.Key.pageBackgroundView.rawValue] as? AnyView
        }
        set {
            customAttributes[NSAttributedString.Key.pageBackgroundView.rawValue] = newValue
        }
    }

    // For now, this doesn't work correctly across multiple lines, it takes the complete bounding box and draws the background behind there.
    var backgroundView: AnyView? {
        get {
            customAttributes[NSAttributedString.Key.backgroundView.rawValue] as? AnyView
        }
        set {
            customAttributes[NSAttributedString.Key.backgroundView.rawValue] = newValue
        }
    }

    public var spreadBreak: Bool {
        get {
            (customAttributes[NSAttributedString.Key.spreadBreak.rawValue] as? Bool) ?? false
        }
        set {
            customAttributes[NSAttributedString.Key.spreadBreak.rawValue] = newValue
        }
    }

    public var suppressHeader: Bool {
        get {
            (customAttributes[NSAttributedString.Key.suppressHeader.rawValue] as? Bool) ?? false
        }
        set {
            customAttributes[NSAttributedString.Key.suppressHeader.rawValue] = newValue
        }
    }
}
