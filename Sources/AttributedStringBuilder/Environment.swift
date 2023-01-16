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

    public func attributedString(environment: EnvironmentValues) async -> [NSAttributedString] {
        await content(environment[keyPath: keyPath]).attributedString(environment: environment)
    }
}

fileprivate struct EnvironmentModifier<Part, Content>: AttributedStringConvertible where Content: AttributedStringConvertible {
    var keyPath: WritableKeyPath<EnvironmentValues, Part>
    var modify: (inout Part) -> ()
    var content: Content

    public func attributedString(environment: EnvironmentValues) async -> [NSAttributedString] {
        var copy = environment
        modify(&copy[keyPath: keyPath])
        return await content.attributedString(environment: copy)
    }
}

extension AttributedStringConvertible {
    public func environment<Value>(_ keyPath: WritableKeyPath<EnvironmentValues, Value>, value: Value) -> some AttributedStringConvertible {
        EnvironmentModifier(keyPath: keyPath, modify: { $0 = value }, content: self)
    }
}
