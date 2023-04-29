import Foundation

public struct StateValues {
    public init() {
    }

    var userDefined: [ObjectIdentifier:Any] = [:]

    public subscript<Key: StateKey>(key: Key.Type = Key.self) -> Key.Value {
        get {
            userDefined[ObjectIdentifier(key)] as? Key.Value ?? Key.initialValue
        }
        set {
            userDefined[ObjectIdentifier(key)] = newValue
        }
    }
}

public protocol StateKey {
    associatedtype Value
    static var initialValue: Value { get }
}
