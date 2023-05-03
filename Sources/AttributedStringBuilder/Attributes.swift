//
//  Attributes.swift
//
//
//  Created by Juul Spee on 08/07/2022.

import AppKit

/// Attributes for `NSAttributedString`, wrapped in a struct for convenience.
public struct Attributes {
    public init(
        family: String = "Helvetica",
        size: CGFloat = 14,
        bold: Bool = false,
        italic: Bool = false,
        textColor: NSColor = .textColor,
        backgroundColor: NSColor? = nil,
        kern: CGFloat = 0,
        firstlineHeadIndent: CGFloat = 0,
        headIndent: CGFloat = 0,
        tabStops: [NSTextTab] = (1..<10).map {
            NSTextTab(textAlignment: .left,
                      location: CGFloat($0) * 2 * 16)            
        },
        alignment: NSTextAlignment = .left,
        lineHeightMultiple: CGFloat = 1.3,
        minimumLineHeight: CGFloat? = nil,
        maximumLineHeight: CGFloat? = nil,
        paragraphSpacing: CGFloat = 14,
        paragraphSpacingBefore: CGFloat = 0,
        link: URL? = nil,
        cursor: NSCursor? = nil,
        underlineColor: NSColor? = nil,
        underlineStyle: NSUnderlineStyle? = nil,
        suppressHeader: Bool = false) {
        self.family = family
        self.size = size
        self.bold = bold
        self.italic = italic
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.kern = kern
        self.firstlineHeadIndent = firstlineHeadIndent
        self.headIndent = headIndent
        self.tabStops = tabStops
        self.alignment = alignment
        self.lineHeightMultiple = lineHeightMultiple
        self.minimumLineHeight = minimumLineHeight
        self.maximumLineHeight = maximumLineHeight
        self.paragraphSpacing = paragraphSpacing
        self.paragraphSpacingBefore = paragraphSpacingBefore
        self.link = link
        self.cursor = cursor
        self.underlineColor = underlineColor
        self.underlineStyle = underlineStyle
        self.suppressHeader = suppressHeader
    }

    public var family: String
    public var size: CGFloat
    public var bold: Bool = false
    public var italic: Bool = false
    public var textColor: NSColor = .textColor
    public var backgroundColor: NSColor? = nil
    public var kern: CGFloat = 0
    public var firstlineHeadIndent: CGFloat = 0
    public var headIndent: CGFloat = 0
    public var tabStops: [NSTextTab] = (1..<10).map { NSTextTab(textAlignment: .left, location: CGFloat($0) * 2 * 16) }
    public var alignment: NSTextAlignment = .left
    public var lineHeightMultiple: CGFloat = 1.3
    public var minimumLineHeight: CGFloat? = nil
    public var maximumLineHeight: CGFloat? = nil
    public var paragraphSpacing: CGFloat = 0
    public var paragraphSpacingBefore: CGFloat = 0
    public var link: URL? = nil
    public var cursor: NSCursor? = nil
    public var underlineColor: NSColor?
    public var underlineStyle: NSUnderlineStyle?
//    public var suppressHeading: Bool?
    public var customAttributes: [String: Any] = [:]
}

extension Attributes {
    public mutating func setIndent(_ value: CGFloat) {
        firstlineHeadIndent = value
        headIndent = value
    }

    public var computedFont: NSFont {
        font
    }

    fileprivate var font: NSFont {
        var fontDescriptor = NSFontDescriptor(name: family, size: size)

        var traits = NSFontDescriptor.SymbolicTraits()
        if bold { traits.formUnion(.bold) }
        if italic { traits.formUnion(.italic )}
        if !traits.isEmpty { fontDescriptor = fontDescriptor.withSymbolicTraits(traits) }
        let font = NSFont(descriptor: fontDescriptor, size: size)!
        return font
    }

    fileprivate var paragraphStyle: NSParagraphStyle {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.firstLineHeadIndent = firstlineHeadIndent
        paragraphStyle.headIndent = headIndent
        paragraphStyle.tabStops = tabStops
        paragraphStyle.alignment = alignment
        paragraphStyle.lineHeightMultiple = lineHeightMultiple
        paragraphStyle.minimumLineHeight = minimumLineHeight ?? 0
        paragraphStyle.maximumLineHeight = maximumLineHeight ?? 0 // 0 is the default
        paragraphStyle.paragraphSpacing = paragraphSpacing
        paragraphStyle.paragraphSpacingBefore = paragraphSpacingBefore
        return paragraphStyle
    }

    /// Outputs a dictionary of the attributes that can be passed into an attributed string.
    public var atts: [NSAttributedString.Key:Any] {
        var result: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .kern: kern,
            .paragraphStyle: paragraphStyle,
        ]
        if let bg = backgroundColor {
            result[.backgroundColor] = bg
        }
        if let url = link {
            result[.link] = url
        }
        if let cursor {
            result[.cursor] = cursor
        }
        if let underlineColor {
            result[.underlineColor] = underlineColor
        }
        if let underlineStyle {
            result[.underlineStyle] = underlineStyle.rawValue
        }
        result[.suppressHeader] = suppressHeader
        for (key, value) in customAttributes {
            result[NSAttributedString.Key(key)] = value
        }
        return result
    }
}

extension NSAttributedString {
    public convenience init(string: String, attributes: Attributes) {
        self.init(string: string, attributes: attributes.atts)
    }
}
