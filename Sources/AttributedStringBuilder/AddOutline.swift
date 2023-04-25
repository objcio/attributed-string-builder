//
//  File.swift
//  
//
//  Created by Chris Eidhof on 03.01.23.
//

import Foundation
import PDFKit
import Markdown

struct HeadingTree {
    var item: MyHeading
    var children: [HeadingTree]
}

extension Array where Element == MyHeading {
    func asTree() -> [HeadingTree] {
        var remainder = self[...]
        var result: [HeadingTree] = []
        while !remainder.isEmpty {
            guard let next = remainder.parse(currentLevel: 0) else {
                fatalError()
            }
            result.append(next)
        }
        return result
    }
}

extension ArraySlice where Element == MyHeading {
    mutating func parse(currentLevel: Int) -> HeadingTree? {
        guard let f = first else { return nil }
        guard f.level > currentLevel else { return nil }
        removeFirst()
        var result = HeadingTree(item: f, children: [])
        while let child = parse(currentLevel: f.level) {
            result.children.append(child)
        }
        return result
    }
}


extension PDFDocument {
    func buildOutline(child: HeadingTree) -> PDFOutline {
        let result = PDFOutline()
        result.label = child.item.title
        let page = page(at: child.item.pageNumber)!
        /* debug */
//        let annotation = PDFAnnotation(bounds: child.item.bounds, forType: .highlight, withProperties: [:])
//        page.addAnnotation(annotation)
        /* end debug */
        result.destination = PDFDestination(page: page, at: child.item.bounds.origin)
        for c in child.children.reversed() {
            result.insertChild(buildOutline(child: c), at: 0)
        }
        return result
    }


    public func addOutline(headings: [MyHeading]) {
        let child = PDFOutline()
        child.label = "Child"

        let tree = headings.asTree()
        for h in tree.reversed() {
            child.insertChild(buildOutline(child: h), at: 0)
        }
        
        let root = PDFOutline()
        root.label = "Root"
        root.insertChild(child, at: 0)
        self.outlineRoot = root
    }

    public func addLinks(namedParts: [NamedPart], links: [MyLink]) {
        for l in links {
            guard let dest = namedParts.first(where: { $0.name == l.name }) else {
                fatalError("No destination named: \(l.name)")
            }
            let sourcePage = page(at: l.pageNumber)!
            let page = page(at: dest.pageNumber)!
            let ann = PDFAnnotation(bounds: l.bounds, forType: .link, withProperties: [
                :
            ])
            let d = PDFDestination(page: page, at: dest.bounds.origin)
            ann.action = PDFActionGoTo(destination: d)
            sourcePage.addAnnotation(ann)
        }
    }
}
