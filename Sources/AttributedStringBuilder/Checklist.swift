//
//  Checklist.swift
//  Workshop Instructor
//
//  Created by Juul Spee on 20/01/2023.
//

import Foundation
import Markdown
import SwiftUI

public struct CheckboxItem: Equatable, Identifiable {
    public struct ID: Equatable, Hashable {
        let _hashValue: Int
        
        init(_ sourceLocation: SourceRange) {
            self._hashValue = sourceLocation.hashValue
        }
    }
    
    public let id: ID
    var isChecked: Bool
    
    init?(_ listItem: ListItem) {
        guard let checkbox = listItem.checkbox,
              let id = Self.id(for: listItem)
        else {
            return nil
        }
        self.id = id
        self.isChecked = checkbox == .checked
    }
    
    public func isIdentical(to other: ListItem) -> Bool {
        self.id == Self.id(for: other)
    }
    
    static private func id(for listItem: ListItem) -> ID? {
        // Take child because its reported source location is stable
        let node = listItem.childCount > 0 ? listItem.child(at: 0)! : listItem
        return node.range.map { ID($0) }
    }
    
    public func toggleURL(scheme: String, endpoint: String = "toggle") -> URL? {
        URL(string: "\(scheme):\(endpoint)/\(id._hashValue)/\(!isChecked)")
    }
}

public final class CheckboxModel: ObservableObject {
    public static let shared = CheckboxModel()
    
    private init() { }
    
    @Published public var checkboxItems: [CheckboxItem] = []
    
    public func set(isChecked: Bool, id: Int) {
        guard let index = checkboxItems.firstIndex(where: { $0.id._hashValue == id })
        else {
            return
        }
        checkboxItems[index].isChecked = isChecked
    }
    
    public func rewrite(document: Document) -> Document {
        var walker = ChecklistWalker(checkboxItems: checkboxItems)
        let updated = walker.visit(document) as! Document
        self.checkboxItems = walker.checkboxItems
        return updated
    }
}

struct ChecklistWalker: MarkupRewriter {
    var checkboxItems: [CheckboxItem]
    
    mutating func visitListItem(_ listItem: ListItem) -> Markup? {
        if let checkboxItem = checkboxItems.first(where: { $0.isIdentical(to: listItem) }) {
            /// Item found in the model; update its checkbox and return the rewritten item.
            var copy = listItem
            copy.checkbox = checkboxItem.isChecked ? .checked : .unchecked
            return copy
        }
        
        /// Store the new list item if it contains a checkbox.
        if let checkboxItem = CheckboxItem(listItem) {
            checkboxItems.append(checkboxItem)
        }
        return listItem
    }
}
