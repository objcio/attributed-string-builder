import Foundation

public struct EnvironmentValues {
    public init(attributes: Attributes = Attributes()) {
        self.attributes = attributes
    }

    public var attributes = Attributes()

    var userDefined: [ObjectIdentifier:Any] = [:]

    public subscript<Key: EnvironmentKey>(key: Key.Type = Key.self) -> Key.Value {
        get {
            userDefined[ObjectIdentifier(key)] as? Key.Value ?? Key.defaultValue
        }
        set {
            userDefined[ObjectIdentifier(key)] = newValue
        }
    }
}

public protocol EnvironmentKey {
    associatedtype Value
    static var defaultValue: Value { get }
}

public struct EnvironmentReader<Part, Content>: AttributedStringConvertible where Content: AttributedStringConvertible {
    public init(_ keyPath: KeyPath<EnvironmentValues, Part>, @AttributedStringBuilder content: @escaping (Part) -> Content) {
        self.keyPath = keyPath
        self.content = content
    }

    var keyPath: KeyPath<EnvironmentValues, Part>
    var content: (Part) -> Content

    public func attributedString(context: inout Context) -> [NSAttributedString] {
        content(context.environment[keyPath: keyPath]).attributedString(context: &context)
    }
}

fileprivate struct EnvironmentModifier<Part, Content>: AttributedStringConvertible where Content: AttributedStringConvertible {
    var keyPath: WritableKeyPath<EnvironmentValues, Part>
    var modify: (inout Part) -> ()
    var content: Content

    public func attributedString(context: inout Context) -> [NSAttributedString] {
        let oldEnv = context.environment
        defer { context.environment = oldEnv }
        modify(&context.environment[keyPath: keyPath])
        return content.attributedString(context: &context)
    }
}

extension AttributedStringConvertible {
    public func environment<Value>(_ keyPath: WritableKeyPath<EnvironmentValues, Value>, value: Value) -> some AttributedStringConvertible {
        EnvironmentModifier(keyPath: keyPath, modify: { $0 = value }, content: self)
    }
}
