//
//  File.swift
//  
//
//  Created by Florian Kugler on 25.04.23.
//

import Cocoa

extension NSLayoutManager {
    func lineFragmentRects(for glyphRange: NSRange) -> [CGRect] {
        var lineRange = NSRange()
        var location = glyphRange.location
        var result: [CGRect] = []
        while location < glyphRange.upperBound {
            let rect = lineFragmentRect(forGlyphAt: location, effectiveRange: &lineRange)
            result.append(rect)
            location = lineRange.upperBound
        }
        return result
    }

    func glyphPageRanges(for characterRange: NSRange) -> [NSRange] {
        var result: [NSRange] = []
        let glyphRange = glyphRange(forCharacterRange: characterRange, actualCharacterRange: nil)
        var location = glyphRange.location
        var effectiveRange = NSRange()
        while location < glyphRange.upperBound {
            if let _ = textContainer(forGlyphAt: location, effectiveRange: &effectiveRange) { // todo not sure if this should be an if-let
                result.append(effectiveRange.intersection(glyphRange)!)
                location = effectiveRange.upperBound
            } else {
                location = glyphRange.upperBound
            }
        }
        return result
    }
}
