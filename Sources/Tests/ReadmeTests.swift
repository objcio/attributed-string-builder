//

import Foundation
import AttributedStringBuilder

@AttributedStringBuilder var sample1: some AttributedStringConvertible {
    "Hello"
    "World".modify { $0.textColor = .red }
}

@AttributedStringBuilder var sample2: some AttributedStringConvertible {
    Markdown("""
    This is *Markdown* syntax.

    With \("inline".modify { $0.underlineStyle = .single }) nesting.
    """)
}
