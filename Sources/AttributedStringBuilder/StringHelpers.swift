//

import Foundation

extension String {
    func trim(_ range: inout Range<String.Index>) {
        var lower = range.lowerBound
        var upper = index(before: range.upperBound)
        guard lower < upper else {
            return 
        }
        while self[lower].isWhitespace {
            formIndex(after: &lower)
        }

        guard lower < upper else {
            range = lower..<index(after: lower)
            return
        }
        while self[upper].isWhitespace, upper > lower {
            formIndex(before: &upper)
        }
        range = lower..<upper
    }
}
