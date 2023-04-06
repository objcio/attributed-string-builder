//
//  Stylesheet.swift
//
//
//  Created by Juul Spee on 08/07/2022.
//

import Foundation

/// A type that defines styles for various markdown elements by setting properties on a given `Attributes` value.
public protocol Stylesheet {
    func emphasis(attributes: inout Attributes)
    func strong(attributes: inout Attributes)
    func inlineCode(attributes: inout Attributes)
    func codeBlock(attributes: inout Attributes)
    func blockQuote(attributes: inout Attributes)
    func link(attributes: inout Attributes)
    func heading(level: Int, attributes: inout Attributes)
    func listItem(attributes: inout Attributes, checkbox: Bool?)
    func orderedListItemPrefix(number: Int) -> String
    func orderedListItemPrefix(attributes: inout Attributes)
    var unorderedListItemPrefix: String { get }
    func unorderedListItemPrefix(attributes: inout Attributes)
    var checkboxCheckedPrefix: String { get }
    func checkboxCheckedPrefix(attributes: inout Attributes)
    var checkboxUncheckedPrefix: String { get }
    func checkboxUncheckedPrefix(attributes: inout Attributes)
    func footnote(attributes: inout Attributes)
}

extension Stylesheet {
    public func emphasis(attributes: inout Attributes) {
        attributes.italic = true
    }

    public func strong(attributes: inout Attributes) {
        attributes.bold = true
    }

    public func link(attributes: inout Attributes) {
        attributes.textColor = .blue
    }

    public func blockQuote(attributes: inout Attributes) {
        attributes.italic = true
        attributes.firstlineHeadIndent = 20
        attributes.headIndent = 20
    }

    public func listItem(attributes: inout Attributes, checkbox: Bool?) {
        if checkbox == true {
            attributes.textColor = .secondaryLabelColor
        }
    }

    public func orderedListItemPrefix(number: Int) -> String {
        "\(number)."
    }

    public func orderedListItemPrefix(attributes: inout Attributes) { }

    public var unorderedListItemPrefix: String {
        "•"
    }

    public func unorderedListItemPrefix(attributes: inout Attributes) { }
    
    public var checkboxCheckedPrefix: String {
        "[x]" // TODO: fix NSTextView image clicks for "􀃳"
    }
    
    public func checkboxCheckedPrefix(attributes: inout Attributes) {
        attributes.textColor = .controlAccentColor
        attributes.cursor = .arrow
        attributes.family = "Monaco" // monospaced
    }
    
    public var checkboxUncheckedPrefix: String {
        "[ ]" // TODO: fix NSTextView image clicks for "􀂒"
    }
    
    public func checkboxUncheckedPrefix(attributes: inout Attributes) {
        attributes.textColor = .secondaryLabelColor
        attributes.cursor = .arrow
        attributes.family = "Monaco" // monospaced
    }

    public func footnote(attributes: inout Attributes) {
        attributes.size *= 0.8
    }

    public func inlineCode(attributes: inout Attributes) {
        attributes.family = "Monaco"
    }

    public func codeBlock(attributes: inout Attributes) {
        attributes.family = "Monaco"
        attributes.lineHeightMultiple = 1
    }

    public func heading(level: Int, attributes: inout Attributes) {
        attributes.bold = true
        switch level {
        case 1: attributes.size = 48
        case 2: attributes.size = 36
        case 3: attributes.size = 28
        default: ()
        }
    }
}
