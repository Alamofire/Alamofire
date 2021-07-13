//
//  URLEncodedFormEncoder.swift
//
//  Copyright (c) 2019 Alamofire Software Foundation (http://alamofire.org/)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation

/// An object that encodes instances into URL-encoded query strings.
///
/// There is no published specification for how to encode collection types. By default, the convention of appending
/// `[]` to the key for array values (`foo[]=1&foo[]=2`), and appending the key surrounded by square brackets for
/// nested dictionary values (`foo[bar]=baz`) is used. Optionally, `ArrayEncoding` can be used to omit the
/// square brackets appended to array keys.
///
/// `BoolEncoding` can be used to configure how `Bool` values are encoded. The default behavior is to encode
/// `true` as 1 and `false` as 0.
///
/// `DateEncoding` can be used to configure how `Date` values are encoded. By default, the `.deferredToDate`
/// strategy is used, which formats dates from their structure.
///
/// `SpaceEncoding` can be used to configure how spaces are encoded. Modern encodings use percent replacement (`%20`),
/// while older encodings may expect spaces to be replaced with `+`.
///
/// This type is largely based on Vapor's [`url-encoded-form`](https://github.com/vapor/url-encoded-form) project.
public final class URLEncodedFormEncoder {
    /// Encoding to use for `Array` values.
    public enum ArrayEncoding {
        /// An empty set of square brackets ("[]") are appended to the key for every value. This is the default encoding.
        case brackets
        /// No brackets are appended to the key and the key is encoded as is.
        case noBrackets

        /// Encodes the key according to the encoding.
        ///
        /// - Parameter key: The `key` to encode.
        /// - Returns:       The encoded key.
        func encode(_ key: String) -> String {
            switch self {
            case .brackets: return "\(key)[]"
            case .noBrackets: return key
            }
        }
    }

    /// Encoding to use for `Bool` values.
    public enum BoolEncoding {
        /// Encodes `true` as `1`, `false` as `0`.
        case numeric
        /// Encodes `true` as "true", `false` as "false". This is the default encoding.
        case literal

        /// Encodes the given `Bool` as a `String`.
        ///
        /// - Parameter value: The `Bool` to encode.
        ///
        /// - Returns:         The encoded `String`.
        func encode(_ value: Bool) -> String {
            switch self {
            case .numeric: return value ? "1" : "0"
            case .literal: return value ? "true" : "false"
            }
        }
    }

    /// Encoding to use for `Data` values.
    public enum DataEncoding {
        /// Defers encoding to the `Data` type.
        case deferredToData
        /// Encodes `Data` as a Base64-encoded string. This is the default encoding.
        case base64
        /// Encode the `Data` as a custom value encoded by the given closure.
        case custom((Data) throws -> String)

        /// Encodes `Data` according to the encoding.
        ///
        /// - Parameter data: The `Data` to encode.
        ///
        /// - Returns:        The encoded `String`, or `nil` if the `Data` should be encoded according to its
        ///                   `Encodable` implementation.
        func encode(_ data: Data) throws -> String? {
            switch self {
            case .deferredToData: return nil
            case .base64: return data.base64EncodedString()
            case let .custom(encoding): return try encoding(data)
            }
        }
    }

    /// Encoding to use for `Date` values.
    public enum DateEncoding {
        /// ISO8601 and RFC3339 formatter.
        private static let iso8601Formatter: ISO8601DateFormatter = {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = .withInternetDateTime
            return formatter
        }()

        /// Defers encoding to the `Date` type. This is the default encoding.
        case deferredToDate
        /// Encodes `Date`s as seconds since midnight UTC on January 1, 1970.
        case secondsSince1970
        /// Encodes `Date`s as milliseconds since midnight UTC on January 1, 1970.
        case millisecondsSince1970
        /// Encodes `Date`s according to the ISO8601 and RFC3339 standards.
        case iso8601
        /// Encodes `Date`s using the given `DateFormatter`.
        case formatted(DateFormatter)
        /// Encodes `Date`s using the given closure.
        case custom((Date) throws -> String)

        /// Encodes the date according to the encoding.
        ///
        /// - Parameter date: The `Date` to encode.
        ///
        /// - Returns:        The encoded `String`, or `nil` if the `Date` should be encoded according to its
        ///                   `Encodable` implementation.
        func encode(_ date: Date) throws -> String? {
            switch self {
            case .deferredToDate:
                return nil
            case .secondsSince1970:
                return String(date.timeIntervalSince1970)
            case .millisecondsSince1970:
                return String(date.timeIntervalSince1970 * 1000.0)
            case .iso8601:
                return DateEncoding.iso8601Formatter.string(from: date)
            case let .formatted(formatter):
                return formatter.string(from: date)
            case let .custom(closure):
                return try closure(date)
            }
        }
    }

    /// Encoding to use for keys.
    ///
    /// This type is derived from [`JSONEncoder`'s `KeyEncodingStrategy`](https://github.com/apple/swift/blob/6aa313b8dd5f05135f7f878eccc1db6f9fbe34ff/stdlib/public/Darwin/Foundation/JSONEncoder.swift#L128)
    /// and [`XMLEncoder`s `KeyEncodingStrategy`](https://github.com/MaxDesiatov/XMLCoder/blob/master/Sources/XMLCoder/Encoder/XMLEncoder.swift#L102).
    public enum KeyEncoding {
        /// Use the keys specified by each type. This is the default encoding.
        case useDefaultKeys
        /// Convert from "camelCaseKeys" to "snake_case_keys" before writing a key.
        ///
        /// Capital characters are determined by testing membership in
        /// `CharacterSet.uppercaseLetters` and `CharacterSet.lowercaseLetters`
        /// (Unicode General Categories Lu and Lt).
        /// The conversion to lower case uses `Locale.system`, also known as
        /// the ICU "root" locale. This means the result is consistent
        /// regardless of the current user's locale and language preferences.
        ///
        /// Converting from camel case to snake case:
        /// 1. Splits words at the boundary of lower-case to upper-case
        /// 2. Inserts `_` between words
        /// 3. Lowercases the entire string
        /// 4. Preserves starting and ending `_`.
        ///
        /// For example, `oneTwoThree` becomes `one_two_three`. `_oneTwoThree_` becomes `_one_two_three_`.
        ///
        /// - Note: Using a key encoding strategy has a nominal performance cost, as each string key has to be converted.
        case convertToSnakeCase
        /// Same as convertToSnakeCase, but using `-` instead of `_`.
        /// For example `oneTwoThree` becomes `one-two-three`.
        case convertToKebabCase
        /// Capitalize the first letter only.
        /// For example `oneTwoThree` becomes  `OneTwoThree`.
        case capitalized
        /// Uppercase all letters.
        /// For example `oneTwoThree` becomes  `ONETWOTHREE`.
        case uppercased
        /// Lowercase all letters.
        /// For example `oneTwoThree` becomes  `onetwothree`.
        case lowercased
        /// A custom encoding using the provided closure.
        case custom((String) -> String)

        func encode(_ key: String) -> String {
            switch self {
            case .useDefaultKeys: return key
            case .convertToSnakeCase: return convertToSnakeCase(key)
            case .convertToKebabCase: return convertToKebabCase(key)
            case .capitalized: return String(key.prefix(1).uppercased() + key.dropFirst())
            case .uppercased: return key.uppercased()
            case .lowercased: return key.lowercased()
            case let .custom(encoding): return encoding(key)
            }
        }

        private func convertToSnakeCase(_ key: String) -> String {
            convert(key, usingSeparator: "_")
        }

        private func convertToKebabCase(_ key: String) -> String {
            convert(key, usingSeparator: "-")
        }

        private func convert(_ key: String, usingSeparator separator: String) -> String {
            guard !key.isEmpty else { return key }

            var words: [Range<String.Index>] = []
            // The general idea of this algorithm is to split words on
            // transition from lower to upper case, then on transition of >1
            // upper case characters to lowercase
            //
            // myProperty -> my_property
            // myURLProperty -> my_url_property
            //
            // It is assumed, per Swift naming conventions, that the first character of the key is lowercase.
            var wordStart = key.startIndex
            var searchRange = key.index(after: wordStart)..<key.endIndex

            // Find next uppercase character
            while let upperCaseRange = key.rangeOfCharacter(from: CharacterSet.uppercaseLetters, options: [], range: searchRange) {
                let untilUpperCase = wordStart..<upperCaseRange.lowerBound
                words.append(untilUpperCase)

                // Find next lowercase character
                searchRange = upperCaseRange.lowerBound..<searchRange.upperBound
                guard let lowerCaseRange = key.rangeOfCharacter(from: CharacterSet.lowercaseLetters, options: [], range: searchRange) else {
                    // There are no more lower case letters. Just end here.
                    wordStart = searchRange.lowerBound
                    break
                }

                // Is the next lowercase letter more than 1 after the uppercase?
                // If so, we encountered a group of uppercase letters that we
                // should treat as its own word
                let nextCharacterAfterCapital = key.index(after: upperCaseRange.lowerBound)
                if lowerCaseRange.lowerBound == nextCharacterAfterCapital {
                    // The next character after capital is a lower case character and therefore not a word boundary.
                    // Continue searching for the next upper case for the boundary.
                    wordStart = upperCaseRange.lowerBound
                } else {
                    // There was a range of >1 capital letters. Turn those into a word, stopping at the capital before the lower case character.
                    let beforeLowerIndex = key.index(before: lowerCaseRange.lowerBound)
                    words.append(upperCaseRange.lowerBound..<beforeLowerIndex)

                    // Next word starts at the capital before the lowercase we just found
                    wordStart = beforeLowerIndex
                }
                searchRange = lowerCaseRange.upperBound..<searchRange.upperBound
            }
            words.append(wordStart..<searchRange.upperBound)
            let result = words.map { range in
                key[range].lowercased()
            }.joined(separator: separator)

            return result
        }
    }

    /// Encoding to use for spaces.
    public enum SpaceEncoding {
        /// Encodes spaces according to normal percent escaping rules (%20).
        case percentEscaped
        /// Encodes spaces as `+`,
        case plusReplaced

        /// Encodes the string according to the encoding.
        ///
        /// - Parameter string: The `String` to encode.
        ///
        /// - Returns:          The encoded `String`.
        func encode(_ string: String) -> String {
            switch self {
            case .percentEscaped: return string.replacingOccurrences(of: " ", with: "%20")
            case .plusReplaced: return string.replacingOccurrences(of: " ", with: "+")
            }
        }
    }

    /// `URLEncodedFormEncoder` error.
    public enum Error: Swift.Error {
        /// An invalid root object was created by the encoder. Only keyed values are valid.
        case invalidRootObject(String)

        var localizedDescription: String {
            switch self {
            case let .invalidRootObject(object):
                return "URLEncodedFormEncoder requires keyed root object. Received \(object) instead."
            }
        }
    }

    /// Whether or not to sort the encoded key value pairs.
    ///
    /// - Note: This setting ensures a consistent ordering for all encodings of the same parameters. When set to `false`,
    ///         encoded `Dictionary` values may have a different encoded order each time they're encoded due to
    ///       ` Dictionary`'s random storage order, but `Encodable` types will maintain their encoded order.
    public let alphabetizeKeyValuePairs: Bool
    /// The `ArrayEncoding` to use.
    public let arrayEncoding: ArrayEncoding
    /// The `BoolEncoding` to use.
    public let boolEncoding: BoolEncoding
    /// THe `DataEncoding` to use.
    public let dataEncoding: DataEncoding
    /// The `DateEncoding` to use.
    public let dateEncoding: DateEncoding
    /// The `KeyEncoding` to use.
    public let keyEncoding: KeyEncoding
    /// The `SpaceEncoding` to use.
    public let spaceEncoding: SpaceEncoding
    /// The `CharacterSet` of allowed (non-escaped) characters.
    public var allowedCharacters: CharacterSet

    /// Creates an instance from the supplied parameters.
    ///
    /// - Parameters:
    ///   - alphabetizeKeyValuePairs: Whether or not to sort the encoded key value pairs. `true` by default.
    ///   - arrayEncoding:            The `ArrayEncoding` to use. `.brackets` by default.
    ///   - boolEncoding:             The `BoolEncoding` to use. `.numeric` by default.
    ///   - dataEncoding:             The `DataEncoding` to use. `.base64` by default.
    ///   - dateEncoding:             The `DateEncoding` to use. `.deferredToDate` by default.
    ///   - keyEncoding:              The `KeyEncoding` to use. `.useDefaultKeys` by default.
    ///   - spaceEncoding:            The `SpaceEncoding` to use. `.percentEscaped` by default.
    ///   - allowedCharacters:        The `CharacterSet` of allowed (non-escaped) characters. `.afURLQueryAllowed` by
    ///                               default.
    public init(alphabetizeKeyValuePairs: Bool = true,
                arrayEncoding: ArrayEncoding = .brackets,
                boolEncoding: BoolEncoding = .numeric,
                dataEncoding: DataEncoding = .base64,
                dateEncoding: DateEncoding = .deferredToDate,
                keyEncoding: KeyEncoding = .useDefaultKeys,
                spaceEncoding: SpaceEncoding = .percentEscaped,
                allowedCharacters: CharacterSet = .afURLQueryAllowed) {
        self.alphabetizeKeyValuePairs = alphabetizeKeyValuePairs
        self.arrayEncoding = arrayEncoding
        self.boolEncoding = boolEncoding
        self.dataEncoding = dataEncoding
        self.dateEncoding = dateEncoding
        self.keyEncoding = keyEncoding
        self.spaceEncoding = spaceEncoding
        self.allowedCharacters = allowedCharacters
    }

    func encode(_ value: Encodable) throws -> URLEncodedFormComponent {
        let context = URLEncodedFormContext(.object([]))
        let encoder = _URLEncodedFormEncoder(context: context,
                                             boolEncoding: boolEncoding,
                                             dataEncoding: dataEncoding,
                                             dateEncoding: dateEncoding)
        try value.encode(to: encoder)

        return context.component
    }

    /// Encodes the `value` as a URL form encoded `String`.
    ///
    /// - Parameter value: The `Encodable` value.`
    ///
    /// - Returns:         The encoded `String`.
    /// - Throws:          An `Error` or `EncodingError` instance if encoding fails.
    public func encode(_ value: Encodable) throws -> String {
        let component: URLEncodedFormComponent = try encode(value)

        guard case let .object(object) = component else {
            throw Error.invalidRootObject("\(component)")
        }

        let serializer = URLEncodedFormSerializer(alphabetizeKeyValuePairs: alphabetizeKeyValuePairs,
                                                  arrayEncoding: arrayEncoding,
                                                  keyEncoding: keyEncoding,
                                                  spaceEncoding: spaceEncoding,
                                                  allowedCharacters: allowedCharacters)
        let query = serializer.serialize(object)

        return query
    }

    /// Encodes the value as `Data`. This is performed by first creating an encoded `String` and then returning the
    /// `.utf8` data.
    ///
    /// - Parameter value: The `Encodable` value.
    ///
    /// - Returns:         The encoded `Data`.
    ///
    /// - Throws:          An `Error` or `EncodingError` instance if encoding fails.
    public func encode(_ value: Encodable) throws -> Data {
        let string: String = try encode(value)

        return Data(string.utf8)
    }
}

final class _URLEncodedFormEncoder {
    var codingPath: [CodingKey]
    // Returns an empty dictionary, as this encoder doesn't support userInfo.
    var userInfo: [CodingUserInfoKey: Any] { [:] }

    let context: URLEncodedFormContext

    private let boolEncoding: URLEncodedFormEncoder.BoolEncoding
    private let dataEncoding: URLEncodedFormEncoder.DataEncoding
    private let dateEncoding: URLEncodedFormEncoder.DateEncoding

    init(context: URLEncodedFormContext,
         codingPath: [CodingKey] = [],
         boolEncoding: URLEncodedFormEncoder.BoolEncoding,
         dataEncoding: URLEncodedFormEncoder.DataEncoding,
         dateEncoding: URLEncodedFormEncoder.DateEncoding) {
        self.context = context
        self.codingPath = codingPath
        self.boolEncoding = boolEncoding
        self.dataEncoding = dataEncoding
        self.dateEncoding = dateEncoding
    }
}

extension _URLEncodedFormEncoder: Encoder {
    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey {
        let container = _URLEncodedFormEncoder.KeyedContainer<Key>(context: context,
                                                                   codingPath: codingPath,
                                                                   boolEncoding: boolEncoding,
                                                                   dataEncoding: dataEncoding,
                                                                   dateEncoding: dateEncoding)
        return KeyedEncodingContainer(container)
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        _URLEncodedFormEncoder.UnkeyedContainer(context: context,
                                                codingPath: codingPath,
                                                boolEncoding: boolEncoding,
                                                dataEncoding: dataEncoding,
                                                dateEncoding: dateEncoding)
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        _URLEncodedFormEncoder.SingleValueContainer(context: context,
                                                    codingPath: codingPath,
                                                    boolEncoding: boolEncoding,
                                                    dataEncoding: dataEncoding,
                                                    dateEncoding: dateEncoding)
    }
}

final class URLEncodedFormContext {
    var component: URLEncodedFormComponent

    init(_ component: URLEncodedFormComponent) {
        self.component = component
    }
}

enum URLEncodedFormComponent {
    typealias Object = [(key: String, value: URLEncodedFormComponent)]

    case string(String)
    case array([URLEncodedFormComponent])
    case object(Object)

    /// Converts self to an `[URLEncodedFormData]` or returns `nil` if not convertible.
    var array: [URLEncodedFormComponent]? {
        switch self {
        case let .array(array): return array
        default: return nil
        }
    }

    /// Converts self to an `Object` or returns `nil` if not convertible.
    var object: Object? {
        switch self {
        case let .object(object): return object
        default: return nil
        }
    }

    /// Sets self to the supplied value at a given path.
    ///
    ///     data.set(to: "hello", at: ["path", "to", "value"])
    ///
    /// - parameters:
    ///     - value: Value of `Self` to set at the supplied path.
    ///     - path: `CodingKey` path to update with the supplied value.
    public mutating func set(to value: URLEncodedFormComponent, at path: [CodingKey]) {
        set(&self, to: value, at: path)
    }

    /// Recursive backing method to `set(to:at:)`.
    private func set(_ context: inout URLEncodedFormComponent, to value: URLEncodedFormComponent, at path: [CodingKey]) {
        guard !path.isEmpty else {
            context = value
            return
        }

        let end = path[0]
        var child: URLEncodedFormComponent
        switch path.count {
        case 1:
            child = value
        case 2...:
            if let index = end.intValue {
                let array = context.array ?? []
                if array.count > index {
                    child = array[index]
                } else {
                    child = .array([])
                }
                set(&child, to: value, at: Array(path[1...]))
            } else {
                child = context.object?.first { $0.key == end.stringValue }?.value ?? .object(.init())
                set(&child, to: value, at: Array(path[1...]))
            }
        default: fatalError("Unreachable")
        }

        if let index = end.intValue {
            if var array = context.array {
                if array.count > index {
                    array[index] = child
                } else {
                    array.append(child)
                }
                context = .array(array)
            } else {
                context = .array([child])
            }
        } else {
            if var object = context.object {
                if let index = object.firstIndex(where: { $0.key == end.stringValue }) {
                    object[index] = (key: end.stringValue, value: child)
                } else {
                    object.append((key: end.stringValue, value: child))
                }
                context = .object(object)
            } else {
                context = .object([(key: end.stringValue, value: child)])
            }
        }
    }
}

struct AnyCodingKey: CodingKey, Hashable {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = "\(intValue)"
        self.intValue = intValue
    }

    init<Key>(_ base: Key) where Key: CodingKey {
        if let intValue = base.intValue {
            self.init(intValue: intValue)!
        } else {
            self.init(stringValue: base.stringValue)!
        }
    }
}

extension _URLEncodedFormEncoder {
    final class KeyedContainer<Key> where Key: CodingKey {
        var codingPath: [CodingKey]

        private let context: URLEncodedFormContext
        private let boolEncoding: URLEncodedFormEncoder.BoolEncoding
        private let dataEncoding: URLEncodedFormEncoder.DataEncoding
        private let dateEncoding: URLEncodedFormEncoder.DateEncoding

        init(context: URLEncodedFormContext,
             codingPath: [CodingKey],
             boolEncoding: URLEncodedFormEncoder.BoolEncoding,
             dataEncoding: URLEncodedFormEncoder.DataEncoding,
             dateEncoding: URLEncodedFormEncoder.DateEncoding) {
            self.context = context
            self.codingPath = codingPath
            self.boolEncoding = boolEncoding
            self.dataEncoding = dataEncoding
            self.dateEncoding = dateEncoding
        }

        private func nestedCodingPath(for key: CodingKey) -> [CodingKey] {
            codingPath + [key]
        }
    }
}

extension _URLEncodedFormEncoder.KeyedContainer: KeyedEncodingContainerProtocol {
    func encodeNil(forKey key: Key) throws {
        let context = EncodingError.Context(codingPath: codingPath,
                                            debugDescription: "URLEncodedFormEncoder cannot encode nil values.")
        throw EncodingError.invalidValue("\(key): nil", context)
    }

    func encode<T>(_ value: T, forKey key: Key) throws where T: Encodable {
        var container = nestedSingleValueEncoder(for: key)
        try container.encode(value)
    }

    func nestedSingleValueEncoder(for key: Key) -> SingleValueEncodingContainer {
        let container = _URLEncodedFormEncoder.SingleValueContainer(context: context,
                                                                    codingPath: nestedCodingPath(for: key),
                                                                    boolEncoding: boolEncoding,
                                                                    dataEncoding: dataEncoding,
                                                                    dateEncoding: dateEncoding)

        return container
    }

    func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        let container = _URLEncodedFormEncoder.UnkeyedContainer(context: context,
                                                                codingPath: nestedCodingPath(for: key),
                                                                boolEncoding: boolEncoding,
                                                                dataEncoding: dataEncoding,
                                                                dateEncoding: dateEncoding)

        return container
    }

    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
        let container = _URLEncodedFormEncoder.KeyedContainer<NestedKey>(context: context,
                                                                         codingPath: nestedCodingPath(for: key),
                                                                         boolEncoding: boolEncoding,
                                                                         dataEncoding: dataEncoding,
                                                                         dateEncoding: dateEncoding)

        return KeyedEncodingContainer(container)
    }

    func superEncoder() -> Encoder {
        _URLEncodedFormEncoder(context: context,
                               codingPath: codingPath,
                               boolEncoding: boolEncoding,
                               dataEncoding: dataEncoding,
                               dateEncoding: dateEncoding)
    }

    func superEncoder(forKey key: Key) -> Encoder {
        _URLEncodedFormEncoder(context: context,
                               codingPath: nestedCodingPath(for: key),
                               boolEncoding: boolEncoding,
                               dataEncoding: dataEncoding,
                               dateEncoding: dateEncoding)
    }
}

extension _URLEncodedFormEncoder {
    final class SingleValueContainer {
        var codingPath: [CodingKey]

        private var canEncodeNewValue = true

        private let context: URLEncodedFormContext
        private let boolEncoding: URLEncodedFormEncoder.BoolEncoding
        private let dataEncoding: URLEncodedFormEncoder.DataEncoding
        private let dateEncoding: URLEncodedFormEncoder.DateEncoding

        init(context: URLEncodedFormContext,
             codingPath: [CodingKey],
             boolEncoding: URLEncodedFormEncoder.BoolEncoding,
             dataEncoding: URLEncodedFormEncoder.DataEncoding,
             dateEncoding: URLEncodedFormEncoder.DateEncoding) {
            self.context = context
            self.codingPath = codingPath
            self.boolEncoding = boolEncoding
            self.dataEncoding = dataEncoding
            self.dateEncoding = dateEncoding
        }

        private func checkCanEncode(value: Any?) throws {
            guard canEncodeNewValue else {
                let context = EncodingError.Context(codingPath: codingPath,
                                                    debugDescription: "Attempt to encode value through single value container when previously value already encoded.")
                throw EncodingError.invalidValue(value as Any, context)
            }
        }
    }
}

extension _URLEncodedFormEncoder.SingleValueContainer: SingleValueEncodingContainer {
    func encodeNil() throws {
        try checkCanEncode(value: nil)
        defer { canEncodeNewValue = false }

        let context = EncodingError.Context(codingPath: codingPath,
                                            debugDescription: "URLEncodedFormEncoder cannot encode nil values.")
        throw EncodingError.invalidValue("nil", context)
    }

    func encode(_ value: Bool) throws {
        try encode(value, as: String(boolEncoding.encode(value)))
    }

    func encode(_ value: String) throws {
        try encode(value, as: value)
    }

    func encode(_ value: Double) throws {
        try encode(value, as: String(value))
    }

    func encode(_ value: Float) throws {
        try encode(value, as: String(value))
    }

    func encode(_ value: Int) throws {
        try encode(value, as: String(value))
    }

    func encode(_ value: Int8) throws {
        try encode(value, as: String(value))
    }

    func encode(_ value: Int16) throws {
        try encode(value, as: String(value))
    }

    func encode(_ value: Int32) throws {
        try encode(value, as: String(value))
    }

    func encode(_ value: Int64) throws {
        try encode(value, as: String(value))
    }

    func encode(_ value: UInt) throws {
        try encode(value, as: String(value))
    }

    func encode(_ value: UInt8) throws {
        try encode(value, as: String(value))
    }

    func encode(_ value: UInt16) throws {
        try encode(value, as: String(value))
    }

    func encode(_ value: UInt32) throws {
        try encode(value, as: String(value))
    }

    func encode(_ value: UInt64) throws {
        try encode(value, as: String(value))
    }

    private func encode<T>(_ value: T, as string: String) throws where T: Encodable {
        try checkCanEncode(value: value)
        defer { canEncodeNewValue = false }

        context.component.set(to: .string(string), at: codingPath)
    }

    func encode<T>(_ value: T) throws where T: Encodable {
        switch value {
        case let date as Date:
            guard let string = try dateEncoding.encode(date) else {
                try attemptToEncode(value)
                return
            }

            try encode(value, as: string)
        case let data as Data:
            guard let string = try dataEncoding.encode(data) else {
                try attemptToEncode(value)
                return
            }

            try encode(value, as: string)
        case let decimal as Decimal:
            // Decimal's `Encodable` implementation returns an object, not a single value, so override it.
            try encode(value, as: String(describing: decimal))
        default:
            try attemptToEncode(value)
        }
    }

    private func attemptToEncode<T>(_ value: T) throws where T: Encodable {
        try checkCanEncode(value: value)
        defer { canEncodeNewValue = false }

        let encoder = _URLEncodedFormEncoder(context: context,
                                             codingPath: codingPath,
                                             boolEncoding: boolEncoding,
                                             dataEncoding: dataEncoding,
                                             dateEncoding: dateEncoding)
        try value.encode(to: encoder)
    }
}

extension _URLEncodedFormEncoder {
    final class UnkeyedContainer {
        var codingPath: [CodingKey]

        var count = 0
        var nestedCodingPath: [CodingKey] {
            codingPath + [AnyCodingKey(intValue: count)!]
        }

        private let context: URLEncodedFormContext
        private let boolEncoding: URLEncodedFormEncoder.BoolEncoding
        private let dataEncoding: URLEncodedFormEncoder.DataEncoding
        private let dateEncoding: URLEncodedFormEncoder.DateEncoding

        init(context: URLEncodedFormContext,
             codingPath: [CodingKey],
             boolEncoding: URLEncodedFormEncoder.BoolEncoding,
             dataEncoding: URLEncodedFormEncoder.DataEncoding,
             dateEncoding: URLEncodedFormEncoder.DateEncoding) {
            self.context = context
            self.codingPath = codingPath
            self.boolEncoding = boolEncoding
            self.dataEncoding = dataEncoding
            self.dateEncoding = dateEncoding
        }
    }
}

extension _URLEncodedFormEncoder.UnkeyedContainer: UnkeyedEncodingContainer {
    func encodeNil() throws {
        let context = EncodingError.Context(codingPath: codingPath,
                                            debugDescription: "URLEncodedFormEncoder cannot encode nil values.")
        throw EncodingError.invalidValue("nil", context)
    }

    func encode<T>(_ value: T) throws where T: Encodable {
        var container = nestedSingleValueContainer()
        try container.encode(value)
    }

    func nestedSingleValueContainer() -> SingleValueEncodingContainer {
        defer { count += 1 }

        return _URLEncodedFormEncoder.SingleValueContainer(context: context,
                                                           codingPath: nestedCodingPath,
                                                           boolEncoding: boolEncoding,
                                                           dataEncoding: dataEncoding,
                                                           dateEncoding: dateEncoding)
    }

    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
        defer { count += 1 }
        let container = _URLEncodedFormEncoder.KeyedContainer<NestedKey>(context: context,
                                                                         codingPath: nestedCodingPath,
                                                                         boolEncoding: boolEncoding,
                                                                         dataEncoding: dataEncoding,
                                                                         dateEncoding: dateEncoding)

        return KeyedEncodingContainer(container)
    }

    func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        defer { count += 1 }

        return _URLEncodedFormEncoder.UnkeyedContainer(context: context,
                                                       codingPath: nestedCodingPath,
                                                       boolEncoding: boolEncoding,
                                                       dataEncoding: dataEncoding,
                                                       dateEncoding: dateEncoding)
    }

    func superEncoder() -> Encoder {
        defer { count += 1 }

        return _URLEncodedFormEncoder(context: context,
                                      codingPath: codingPath,
                                      boolEncoding: boolEncoding,
                                      dataEncoding: dataEncoding,
                                      dateEncoding: dateEncoding)
    }
}

final class URLEncodedFormSerializer {
    private let alphabetizeKeyValuePairs: Bool
    private let arrayEncoding: URLEncodedFormEncoder.ArrayEncoding
    private let keyEncoding: URLEncodedFormEncoder.KeyEncoding
    private let spaceEncoding: URLEncodedFormEncoder.SpaceEncoding
    private let allowedCharacters: CharacterSet

    init(alphabetizeKeyValuePairs: Bool,
         arrayEncoding: URLEncodedFormEncoder.ArrayEncoding,
         keyEncoding: URLEncodedFormEncoder.KeyEncoding,
         spaceEncoding: URLEncodedFormEncoder.SpaceEncoding,
         allowedCharacters: CharacterSet) {
        self.alphabetizeKeyValuePairs = alphabetizeKeyValuePairs
        self.arrayEncoding = arrayEncoding
        self.keyEncoding = keyEncoding
        self.spaceEncoding = spaceEncoding
        self.allowedCharacters = allowedCharacters
    }

    func serialize(_ object: URLEncodedFormComponent.Object) -> String {
        var output: [String] = []
        for (key, component) in object {
            let value = serialize(component, forKey: key)
            output.append(value)
        }
        output = alphabetizeKeyValuePairs ? output.sorted() : output

        return output.joinedWithAmpersands()
    }

    func serialize(_ component: URLEncodedFormComponent, forKey key: String) -> String {
        switch component {
        case let .string(string): return "\(escape(keyEncoding.encode(key)))=\(escape(string))"
        case let .array(array): return serialize(array, forKey: key)
        case let .object(object): return serialize(object, forKey: key)
        }
    }

    func serialize(_ object: URLEncodedFormComponent.Object, forKey key: String) -> String {
        var segments: [String] = object.map { subKey, value in
            let keyPath = "[\(subKey)]"
            return serialize(value, forKey: key + keyPath)
        }
        segments = alphabetizeKeyValuePairs ? segments.sorted() : segments

        return segments.joinedWithAmpersands()
    }

    func serialize(_ array: [URLEncodedFormComponent], forKey key: String) -> String {
        var segments: [String] = array.map { component in
            let keyPath = arrayEncoding.encode(key)
            return serialize(component, forKey: keyPath)
        }
        segments = alphabetizeKeyValuePairs ? segments.sorted() : segments

        return segments.joinedWithAmpersands()
    }

    func escape(_ query: String) -> String {
        var allowedCharactersWithSpace = allowedCharacters
        allowedCharactersWithSpace.insert(charactersIn: " ")
        let escapedQuery = query.addingPercentEncoding(withAllowedCharacters: allowedCharactersWithSpace) ?? query
        let spaceEncodedQuery = spaceEncoding.encode(escapedQuery)

        return spaceEncodedQuery
    }
}

extension Array where Element == String {
    func joinedWithAmpersands() -> String {
        joined(separator: "&")
    }
}

extension CharacterSet {
    /// Creates a CharacterSet from RFC 3986 allowed characters.
    ///
    /// RFC 3986 states that the following characters are "reserved" characters.
    ///
    /// - General Delimiters: ":", "#", "[", "]", "@", "?", "/"
    /// - Sub-Delimiters: "!", "$", "&", "'", "(", ")", "*", "+", ",", ";", "="
    ///
    /// In RFC 3986 - Section 3.4, it states that the "?" and "/" characters should not be escaped to allow
    /// query strings to include a URL. Therefore, all "reserved" characters with the exception of "?" and "/"
    /// should be percent-escaped in the query string.
    public static let afURLQueryAllowed: CharacterSet = {
        let generalDelimitersToEncode = ":#[]@" // does not include "?" or "/" due to RFC 3986 - Section 3.4
        let subDelimitersToEncode = "!$&'()*+,;="
        let encodableDelimiters = CharacterSet(charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)")

        return CharacterSet.urlQueryAllowed.subtracting(encodableDelimiters)
    }()
}
