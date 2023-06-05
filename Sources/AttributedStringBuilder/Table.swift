//
//  File.swift
//
//
//  Created by Chris Eidhof on 15.07.22.
//

import Foundation
import Cocoa

// TODO would be nice to have a builder here as well

@MainActor
public struct Table: AttributedStringConvertible {
    public init(contentWidth: Width = .percentage(100), rows: [TableRow]) {
        self.rows = rows
        self.contentWidth = contentWidth
    }

    public var rows: [TableRow]
    public var contentWidth: Width

    public func attributedString(context: inout Context) -> [NSAttributedString] {
        guard !rows.isEmpty else { return [] }
        let result = NSMutableAttributedString()
        let table = NSTextTable()
        table.setContentWidth(contentWidth.value, type: contentWidth.type)
        table.numberOfColumns = rows[0].cells.count
        for (rowIx, row) in rows.enumerated() {
            assert(row.cells.count == table.numberOfColumns)
            row.render(row: rowIx, table: table, context: &context, result: result)
        }
        result.replaceCharacters(in: NSRange(location: result.length-1, length: 1), with: "")
        return [result]
    }
}

@MainActor
public struct TableRow {
    public init(cells: [TableCell]) {
        self.cells = cells
    }

    public var cells: [TableCell]

    func render(row: Int, table: NSTextTable, context: inout Context, result: NSMutableAttributedString) {
        for (column, cell) in cells.enumerated() {
            let block = NSTextTableBlock(table: table, startingRow: row, rowSpan: 1, startingColumn: column, columnSpan: 1)
            if let w = cell.width {
                block.setContentWidth(w.value, type: w.type)
            }
            cell.render(block: block, context: &context, result: result)
        }
    }
}

@MainActor
public struct TableCell {
    public init(
        width: Table.Width? = nil,
        height: Table.Width? = nil,
        borderColor: NSColor = .black,
        borderWidth: WidthValue = 0,
        padding: WidthValue = 0,
        margin: WidthValue = 0,
        alignment: NSTextAlignment = .left,
        verticalAlignment: NSTextBlock.VerticalAlignment = .topAlignment,
        contents: AttributedStringConvertible) {
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.padding = padding
        self.margin = margin
        self.contents = contents
        self.width = width
        self.height = height
        self.alignment = alignment
        self.verticalAlignment = verticalAlignment
    }

    public var borderColor: NSColor = .black
    public var borderWidth: WidthValue = 0
    public var padding: WidthValue = 0
    public var margin: WidthValue = 0
    public var contents: AttributedStringConvertible
    public var width: Table.Width?
    public var height: Table.Width? = nil
    public var alignment: NSTextAlignment = .left
    public var verticalAlignment: NSTextBlock.VerticalAlignment

    @MainActor
    func render(block: NSTextTableBlock, context: inout Context, result: NSMutableAttributedString) {
        block.setBorderColor(borderColor)
        for (edge, value) in borderWidth.allEdges {
            block.setWidth(value.value, type: value.type, for: .border, edge: edge)
        }
        for (edge, value) in padding.allEdges {
            block.setWidth(value.value, type: value.type, for: .padding, edge: edge)
        }
        for (edge, value) in margin.allEdges {
            block.setWidth(value.value, type: value.type, for: .margin, edge: edge)
        }
        if let h = height {
            block.setValue(h.value, type: h.type, for: .height)
        }
        block.verticalAlignment = verticalAlignment

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.textBlocks = [block]

        let contentsA = NSMutableAttributedString(attributedString: contents.joined().run(context: &context))

        // Copy some style attributes from the cell contents if possible
        if let style = contentsA.attributes(at: 0, effectiveRange: nil)[.paragraphStyle] as? NSParagraphStyle {
            paragraph.lineHeightMultiple = style.lineHeightMultiple
            paragraph.minimumLineHeight = style.minimumLineHeight
            paragraph.maximumLineHeight = style.maximumLineHeight
        }

        contentsA.mutableString.append("\n") // This is necessary to be recognized as a cell!
        let range = NSRange(location: 0, length: contentsA.string.count)
        contentsA.addAttribute(NSAttributedString.Key.paragraphStyle, value: paragraph, range: range)
        result.append(contentsA)
    }

}

extension Table {
    public enum Width: Hashable, Codable {
        case absolute(CGFloat)
        case percentage(CGFloat)

        var value: CGFloat {
            switch self {
            case .absolute(let x): return x
            case .percentage(let x): return x
            }
        }

        var type: NSTextBlock.ValueType {
            switch self {
            case .percentage: return .percentageValueType
            case .absolute: return .absoluteValueType
            }
        }


    }
}

public struct WidthValue: ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral, Hashable, Codable {
    public init(integerLiteral value: Int) {
        self.init(floatLiteral: .init(value))
    }

    public init(floatLiteral value: Double) {
        self.init(top: value, right: value, bottom: value, left: value)
    }

    public init(top: CGFloat = 0, right: CGFloat = 0, bottom: CGFloat = 0, left: CGFloat = 0) {
        self.top = .absolute(top)
        self.right = .absolute(right)
        self.bottom = .absolute(bottom)
        self.left = .absolute(left)
    }

    public init(top: Table.Width = .absolute(0), right: Table.Width = .absolute(0), bottom: Table.Width = .absolute(0), left: Table.Width = .absolute(0)) {
        self.top = top
        self.right = right
        self.bottom = bottom
        self.left = left
    }

    public var top, right, bottom, left: Table.Width // todo should these be Width?

    var allEdges: [NSRectEdge: Table.Width] {
        [.minY: top, .maxY: bottom, .minX: left, .maxX: right]
    }

}
