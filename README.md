# AttributedString Builder

A simple way to build up attributed strings using result builders from a variety of sources. Based on the episodes from [Swift Talk](https://talk.objc.io/episodes/S01E337-attributed-string-builder-part-1). Here are the things you can embed:

- Plain strings
- Markdown
- Images
- SwiftUI Views
- Table support
- PDF export

Here's an example showing plain strings, Markdown and SwiftUI views:

```swift
@AttributedStringBuilder
var example: some AttributedStringConvertible {
    "Hello, World!"
        .bold()
        .modify { $0.backgroundColor = .yellow }
    """
    This is some markdown with **strong** `code` text. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Maecenas tempus, tortor eu maximus gravida, ante diam fermentum magna, in gravida ex tellus ac purus.

    - One
    - Two
    - Three

    > A blockquote.
    """.markdown()
    Embed {
        HStack {
            Image(systemName: "hand.wave")
                .font(.largeTitle)
            Text("Hello from SwiftUI")
            Color.red.frame(width: 100, height: 50)
        }
    }
```

You can then turn this example into a multi-page PDF like this:

```swift
let data = await example
    .joined(separator: "\n") // join the parts using newlines
    .run(environment: .init(attributes: sampleAttributes)) // turn into a single `NSAttributedString`
    .pdf() // render as PDF
try! data.write(to: .desktopDirectory.appending(component: "out.pdf"))
```

Here's [a larger sample](Sources/Tests/Tests.swift).

## Features

### Attributes

The [Attributes](Sources/AttributedStringBuilder/Attributes.swift) struct is a value type representing the attributes in an `NSAttributedString`. During the building of the attributed string, this is passed on through the environment.

### Strings

You can turn any string directly into an attributed string. The attributes from the environment are used to do this. You can also modify the environment in a way very similar to what SwiftUI does. For example, you can write `"Hello".bold()" to take the current attributes, make them bold, and then render the string `"Hello"` using these modified attributes.

### Markdown

You can take any Markdown string and render it into an attributed string as well. For most customization, you can pass in a custom [stylesheet](Sources/AttributedStringBuilder/MarkdownStylesheet.swift).

### Images

You can embed any `NSImage` into the attributed string, they're rendered as-is.

### SwiftUI Views

SwiftUI views can be embedded using the [Embed](Sources/AttributedStringBuilder/SwiftUI.swift) modifier. By default, it proposes `nil⨉nil` to the view, but this can be customized. SwiftUI views are rendered into a PDF context and are embedded as vector graphics.

### Tables

You can construct tables in attributed strings using the [Table](Sources/AttributedStringBuilder/Table.swift) support. This interface might still change (ideally, we'd use result builders for this as well).

### Environment

You can use the environment in a way similar to SwiftUI's Environment to pass values down the view tree.

## Swift Talk Episodes

- [Writing the Builder](https://talk.objc.io/episodes/S01E337-attributed-string-builder-part-1)
- [Joining Elements](https://talk.objc.io/episodes/S01E338-attributed-string-builder-part-2)
- [Syntax Highlighting](https://talk.objc.io/episodes/S01E339-attributed-string-builder-part-3)
- [Rendering SwiftUI Views](https://talk.objc.io/episodes/S01E340-attributed-string-builder-part-4)
- [Rendering Markdown](https://talk.objc.io/episodes/S01E341-attributed-string-builder-part-5)
- [Creating a PDF](https://talk.objc.io/episodes/S01E342-attributed-string-builder-part-6)
