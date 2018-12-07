//
//  ParameterEncoder.swift
//
//  Copyright (c) 2014-2018 Alamofire Software Foundation (http://alamofire.org/)
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

/// A type that can encode any `Encodable` type into a `URLRequest`.
public protocol ParameterEncoder {
    /// Encode the provided `Encodable` parameters into `request`.
    ///
    /// - Parameters:
    ///   - parameters: The `Encodable` parameter value.
    ///   - request:    The `URLRequest` into which to encode the parameters.
    /// - Returns:      A `URLRequest` with the result of the encoding.
    /// - Throws:       An `Error` when encoding fails. For Alamofire provided encoders, this will be an instance of
    ///                 `AFError.parameterEncoderFailed` with an associated `ParameterEncoderFailureReason`.
    func encode<Parameters: Encodable>(_ parameters: Parameters?, into request: URLRequest) throws -> URLRequest
}

/// A `ParameterEncoder` that encodes types as JSON body data.
///
/// If no `Content-Type` header is already set on the provided `URLRequest`s, it's set to `application/json`.
open class JSONParameterEncoder: ParameterEncoder {
    /// Returns an encoder with default parameters.
    public static var `default`: JSONParameterEncoder { return JSONParameterEncoder() }

    /// Returns an encoder with `JSONEncoder.outputFormatting` set to `.prettyPrinted`.
    public static var prettyPrinted: JSONParameterEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        return JSONParameterEncoder(encoder: encoder)
    }

    /// Returns an encoder with `JSONEncoder.outputFormatting` set to `.sortedKeys`.
    @available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
    public static var sortedKeys: JSONParameterEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        return JSONParameterEncoder(encoder: encoder)
    }

    /// `JSONEncoder` used to encode parameters.
    public let encoder: JSONEncoder

    /// Creates an instance with the provided `JSONEncoder`.
    ///
    /// - Parameter encoder: The `JSONEncoder`. Defaults to `JSONEncoder()`.
    public init(encoder: JSONEncoder = JSONEncoder()) {
        self.encoder = encoder
    }

    open func encode<Parameters: Encodable>(_ parameters: Parameters?,
                                            into request: URLRequest) throws -> URLRequest {
        guard let parameters = parameters else { return request }

        var request = request

        do {
            let data = try encoder.encode(parameters)
            request.httpBody = data
            if request.httpHeaders["Content-Type"] == nil {
                request.httpHeaders.update(.contentType("application/json"))
            }
        } catch {
            throw AFError.parameterEncodingFailed(reason: .jsonEncodingFailed(error: error))
        }

        return request
    }
}

/// A `ParameterEncoder` that encodes types as URL-encoded query strings to be set on the URL or as body data, depending
/// on the `Destination` set.
///
/// If no `Content-Type` header is already set on the provided `URLRequest`s, it will be set to
/// `application/x-www-form-urlencoded; charset=utf-8`.
///
/// There is no published specification for how to encode collection types. By default, the convention of appending
/// `[]` to the key for array values (`foo[]=1&foo[]=2`), and appending the key surrounded by square brackets for
/// nested dictionary values (`foo[bar]=baz`) is used. Optionally, `ArrayEncoding` can be used to omit the
/// square brackets appended to array keys.
///
/// `BoolEncoding` can be used to configure how boolean values are encoded. The default behavior is to encode
/// `true` as 1 and `false` as 0.
open class URLEncodedFormParameterEncoder: ParameterEncoder {
    /// Defines where the URL-encoded string should be set for each `URLRequest`.
    public enum Destination {
        /// Applies the encoded query string to any existing query string for `.get`, `.head`, and `.delete` request.
        /// Sets it to the `httpBody` for all other methods.
        case methodDependent
        /// Applies the encoded query string to any existing query string from the `URLRequest`.
        case queryString
        /// Applies the encoded query string to the `httpBody` of the `URLRequest`.
        case httpBody

        /// Determines whether the URL-encoded string should be applied to the `URLRequest`'s `url`.
        ///
        /// - Parameter method: The `HTTPMethod`.
        /// - Returns:          Whether the URL-encoded string should be applied to a `URL`.
        func encodesParametersInURL(for method: HTTPMethod) -> Bool {
            switch self {
            case .methodDependent: return [.get, .head, .delete].contains(method)
            case .queryString: return true
            case .httpBody: return false
            }
        }
    }

    /// Returns an encoder with default parameters.
    public static var `default`: URLEncodedFormParameterEncoder { return URLEncodedFormParameterEncoder() }

    /// The `URLEncodedFormEncoder` to use.
    public let encoder: URLEncodedFormEncoder

    /// The `Destination` for the URL-encoded string.
    public let destination: Destination

    /// Creates an instance with the provided `URLEncodedFormEncoder` instance and `Destination` value.
    ///
    /// - Parameters:
    ///   - encoder:     The `URLEncodedFormEncoder`. Defaults to `URLEncodedFormEncoder()`.
    ///   - destination: The `Destination`. Defaults to `.methodDependent`.
    public init(encoder: URLEncodedFormEncoder = URLEncodedFormEncoder(), destination: Destination = .methodDependent) {
        self.encoder = encoder
        self.destination = destination
    }

    open func encode<Parameters: Encodable>(_ parameters: Parameters?,
                                              into request: URLRequest) throws -> URLRequest {
        guard let parameters = parameters else { return request }

        var request = request

        guard let url = request.url else {
            throw AFError.parameterEncoderFailed(reason: .missingRequiredComponent(.url))
        }

        guard let rawMethod = request.httpMethod, let method = HTTPMethod(rawValue: rawMethod) else {
            let rawValue = request.httpMethod ?? "nil"
            throw AFError.parameterEncoderFailed(reason: .missingRequiredComponent(.httpMethod(rawValue: rawValue)))
        }

        if destination.encodesParametersInURL(for: method),
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            let query: String = try Result<String> { try encoder.encode(parameters) }
                                .mapError { AFError.parameterEncoderFailed(reason: .encoderFailed(error: $0)) }.unwrap()
            let newQueryString = [components.percentEncodedQuery, query].compactMap { $0 }.joinedWithAmpersands()
            components.percentEncodedQuery = newQueryString

            guard let newURL = components.url else {
                throw AFError.parameterEncoderFailed(reason: .missingRequiredComponent(.url))
            }

            request.url = newURL
        } else {
            if request.httpHeaders["Content-Type"] == nil {
                request.httpHeaders.update(.contentType("application/x-www-form-urlencoded; charset=utf-8"))
            }

            request.httpBody = try Result<Data> { try encoder.encode(parameters) }
                                .mapError { AFError.parameterEncoderFailed(reason: .encoderFailed(error: $0)) }.unwrap()
        }

        return request
    }
}

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
/// `SpaceEncoding` can be used to configure how spaces are encoded. Modern encodings use percent replacement (%20),
/// while older encoding may expect spaces to be replaced with +.
///
/// This type is largely based on Vapor's [`url-encoded-form`](https://github.com/vapor/url-encoded-form) project.
public final class URLEncodedFormEncoder {
    /// Configures how `Bool` parameters are encoded.
    public enum BoolEncoding {
        /// Encodes `true` as `1`, `false` as `0`.
        case numeric
        /// Encodes `true` as "true", `false` as "false".
        case literal

        /// Encodes the given `Bool` as a `String`.
        ///
        /// - Parameter value: The `Bool` to encode.
        /// - Returns:         The encoded `String`.
        func encode(_ value: Bool) -> String {
            switch self {
            case .numeric: return value ? "1" : "0"
            case .literal: return value ? "true" : "false"
            }
        }
    }

    /// Configures how `Array` parameters are encoded.
    public enum ArrayEncoding {
        /// An empty set of square brackets ("[]") are sppended to the key for every value.
        case brackets
        /// No brackets are appended to the key and the key is encoded as is.
        case noBrackets

        func encode(_ key: String) -> String {
            switch self {
            case .brackets: return "\(key)[]"
            case .noBrackets: return key
            }
        }
    }

    /// Configures how spaces are encoded.
    public enum SpaceEncoding {
        /// Encodes spaces according to normal percent escaping rules (%20).
        case percentEscaped
        /// Encodes spaces as `+`,
        case plusReplaced

        /// Encodes the string according to the encoding.
        ///
        /// - Parameter string: The `String` to encode.
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
            case let .invalidRootObject(object): return "URLEncodedFormEncoder requires keyed root object. Received \(object) instead."
            }
        }
    }

    /// The `ArrayEncoding` to use.
    public let arrayEncoding: ArrayEncoding
    /// The `BoolEncoding` to use.
    public let boolEncoding: BoolEncoding
    /// The `SpaceEncoding` to use.
    public let spaceEncoding: SpaceEncoding
    /// The `CharacterSet` of allowed characters.
    public var allowedCharacters: CharacterSet

    /// Creates an instance from the supplied parameters.
    ///
    /// - Parameters:
    ///   - arrayEncoding: The `ArrayEncoding` instance. Defaults to `.brackets`.
    ///   - boolEncoding:  The `BoolEncoding` instance. Defaults to `.numeric`.
    ///   - spaceEncoding: The `SpaceEncoding` instance. Defaults to `.percentEscaped`.
    ///   - allowedCharacters: The `CharacterSet` of allowed (non-escaped) characters. Defaults to `.afURLQueryAllowed`.
    public init(arrayEncoding: ArrayEncoding = .brackets,
                boolEncoding: BoolEncoding = .numeric,
                spaceEncoding: SpaceEncoding = .percentEscaped,
                allowedCharacters: CharacterSet = .afURLQueryAllowed) {
        self.arrayEncoding = arrayEncoding
        self.boolEncoding = boolEncoding
        self.spaceEncoding = spaceEncoding
        self.allowedCharacters = allowedCharacters
    }

    func encode(_ value: Encodable) throws -> URLEncodedFormComponent {
        let context = URLEncodedFormContext(.object([:]))
        let encoder = _URLEncodedFormEncoder(context: context, boolEncoding: boolEncoding)
        try value.encode(to: encoder)

        return context.component
    }

    /// Encodes the `value` as a URL form encoded `String`.
    ///
    /// - Parameter value: The `Encodable` value.`
    /// - Returns:         The encoded `String`.
    /// - Throws:          An `Error` or `EncodingError` instance if encoding fails.
    public func encode(_ value: Encodable) throws -> String {
        let component: URLEncodedFormComponent = try encode(value)

        guard case let .object(object) = component else {
            throw Error.invalidRootObject("\(component)")
        }

        let serializer = URLEncodedFormSerializer(arrayEncoding: arrayEncoding,
                                                  spaceEncoding: spaceEncoding,
                                                  allowedCharacters: allowedCharacters)
        let query = serializer.serialize(object)

        return query
    }

    /// Encodes the value as `Data`. This is performed by first creating an encoded `String` and then returning the
    /// `.utf8` data.
    ///
    /// - Parameter value: The `Encodable` value.
    /// - Returns:         The encoded `Data`.
    /// - Throws:          An `Error` or `EncodingError` instance if encoding fails.
    public func encode(_ value: Encodable) throws -> Data {
        let string: String = try encode(value)

        return Data(string.utf8)
    }
}

final class _URLEncodedFormEncoder {
    var codingPath: [CodingKey]
    // Returns an empty dictionary, as this encoder doesn't support userInfo.
    var userInfo: [CodingUserInfoKey : Any] { return [:] }

    let context: URLEncodedFormContext

    private let boolEncoding: URLEncodedFormEncoder.BoolEncoding

    public init(context: URLEncodedFormContext,
                codingPath: [CodingKey] = [],
                boolEncoding: URLEncodedFormEncoder.BoolEncoding) {
        self.context = context
        self.codingPath = codingPath
        self.boolEncoding = boolEncoding
    }
}

extension _URLEncodedFormEncoder: Encoder {
    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
        let container = _URLEncodedFormEncoder.KeyedContainer<Key>(context: context,
                                                                   codingPath: codingPath,
                                                                   boolEncoding: boolEncoding)
        return KeyedEncodingContainer(container)
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        return _URLEncodedFormEncoder.UnkeyedContainer(context: context,
                                                       codingPath: codingPath,
                                                       boolEncoding: boolEncoding)
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        return _URLEncodedFormEncoder.SingleValueContainer(context: context,
                                                           codingPath: codingPath,
                                                           boolEncoding: boolEncoding)
    }
}

final class URLEncodedFormContext {
    var component: URLEncodedFormComponent

    init(_ component: URLEncodedFormComponent) {
        self.component = component
    }
}

enum URLEncodedFormComponent {
    case string(String)
    case array([URLEncodedFormComponent])
    case object([String: URLEncodedFormComponent])

    /// Converts self to an `[URLEncodedFormData]` or returns `nil` if not convertible.
    var array: [URLEncodedFormComponent]? {
        switch self {
        case let .array(array): return array
        default: return nil
        }
    }

    /// Converts self to an `[String: URLEncodedFormData]` or returns `nil` if not convertible.
    var object: [String: URLEncodedFormComponent]? {
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
        guard path.count >= 1 else {
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
                child = context.object?[end.stringValue] ?? .object([:])
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
                object[end.stringValue] = child
                context = .object(object)
            } else {
                context = .object([end.stringValue: child])
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

    init<Key>(_ base: Key) where Key : CodingKey {
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

        init(context: URLEncodedFormContext,
             codingPath: [CodingKey],
             boolEncoding: URLEncodedFormEncoder.BoolEncoding) {
            self.context = context
            self.codingPath = codingPath
            self.boolEncoding = boolEncoding
        }

        private func nestedCodingPath(for key: CodingKey) -> [CodingKey] {
            return codingPath + [key]
        }
    }
}

extension _URLEncodedFormEncoder.KeyedContainer: KeyedEncodingContainerProtocol {
    func encodeNil(forKey key: Key) throws {
        let context = EncodingError.Context(codingPath: codingPath,
                                            debugDescription: "URLEncodedFormEncoder cannot encode nil values.")
        throw EncodingError.invalidValue("\(key): nil", context)
    }

    func encode<T>(_ value: T, forKey key: Key) throws where T : Encodable {
        var container = nestedSingleValueEncoder(for: key)
        try container.encode(value)
    }

    func nestedSingleValueEncoder(for key: Key) -> SingleValueEncodingContainer {
        let container = _URLEncodedFormEncoder.SingleValueContainer(context: context,
                                                                    codingPath: nestedCodingPath(for: key),
                                                                    boolEncoding: boolEncoding)

        return container
    }

    func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        let container = _URLEncodedFormEncoder.UnkeyedContainer(context: context,
                                                                codingPath: nestedCodingPath(for: key),
                                                                boolEncoding: boolEncoding)

        return container
    }

    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        let container = _URLEncodedFormEncoder.KeyedContainer<NestedKey>(context: context,
                                                                         codingPath: nestedCodingPath(for: key),
                                                                         boolEncoding: boolEncoding)

        return KeyedEncodingContainer(container)
    }

    func superEncoder() -> Encoder {
        return _URLEncodedFormEncoder(context: context, codingPath: codingPath, boolEncoding: boolEncoding)
    }

    func superEncoder(forKey key: Key) -> Encoder {
        return _URLEncodedFormEncoder(context: context, codingPath: nestedCodingPath(for: key), boolEncoding: boolEncoding)
    }
}

extension _URLEncodedFormEncoder {
    final class SingleValueContainer {
        var codingPath: [CodingKey]

        private var canEncodeNewValue = true

        private let context: URLEncodedFormContext
        private let boolEncoding: URLEncodedFormEncoder.BoolEncoding

        init(context: URLEncodedFormContext, codingPath: [CodingKey], boolEncoding: URLEncodedFormEncoder.BoolEncoding) {
            self.context = context
            self.codingPath = codingPath
            self.boolEncoding = boolEncoding
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

    private func encode<T>(_ value: T, as string: String) throws where T : Encodable {
        try checkCanEncode(value: value)
        defer { canEncodeNewValue = false }

        context.component.set(to: .string(string), at: codingPath)
    }

    func encode<T>(_ value: T) throws where T : Encodable {
        try checkCanEncode(value: value)
        defer { canEncodeNewValue = false }

        let encoder = _URLEncodedFormEncoder(context: context,
                                             codingPath: codingPath,
                                             boolEncoding: boolEncoding)
        try value.encode(to: encoder)
    }
}

extension _URLEncodedFormEncoder {
    final class UnkeyedContainer {
        var codingPath: [CodingKey]

        var count = 0
        var nestedCodingPath: [CodingKey] {
            return codingPath + [AnyCodingKey(intValue: count)!]
        }

        private let context: URLEncodedFormContext
        private let boolEncoding: URLEncodedFormEncoder.BoolEncoding

        init(context: URLEncodedFormContext,
             codingPath: [CodingKey],
             boolEncoding: URLEncodedFormEncoder.BoolEncoding) {
            self.context = context
            self.codingPath = codingPath
            self.boolEncoding = boolEncoding
        }
    }
}

extension _URLEncodedFormEncoder.UnkeyedContainer: UnkeyedEncodingContainer {
    func encodeNil() throws {
        let context = EncodingError.Context(codingPath: codingPath,
                                            debugDescription: "URLEncodedFormEncoder cannot encode nil values.")
        throw EncodingError.invalidValue("nil", context)
    }

    func encode<T>(_ value: T) throws where T : Encodable {
        var container = nestedSingleValueContainer()
        try container.encode(value)
    }

    func nestedSingleValueContainer() -> SingleValueEncodingContainer {
        defer { count += 1 }

        return _URLEncodedFormEncoder.SingleValueContainer(context: context,
                                                           codingPath: nestedCodingPath,
                                                           boolEncoding: boolEncoding)
    }

    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        defer { count += 1 }
        let container = _URLEncodedFormEncoder.KeyedContainer<NestedKey>(context: context,
                                                                         codingPath: nestedCodingPath,
                                                                         boolEncoding: boolEncoding)

        return KeyedEncodingContainer(container)
    }

    func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        defer { count += 1 }

        return _URLEncodedFormEncoder.UnkeyedContainer(context: context,
                                                       codingPath: nestedCodingPath,
                                                       boolEncoding: boolEncoding)
    }

    func superEncoder() -> Encoder {
        defer { count += 1 }

        return _URLEncodedFormEncoder(context: context, codingPath: codingPath, boolEncoding: boolEncoding)
    }
}

final class URLEncodedFormSerializer {
    let arrayEncoding: URLEncodedFormEncoder.ArrayEncoding
    let spaceEncoding: URLEncodedFormEncoder.SpaceEncoding
    let allowedCharacters: CharacterSet

    init(arrayEncoding: URLEncodedFormEncoder.ArrayEncoding,
         spaceEncoding: URLEncodedFormEncoder.SpaceEncoding,
         allowedCharacters: CharacterSet) {
        self.arrayEncoding = arrayEncoding
        self.spaceEncoding = spaceEncoding
        self.allowedCharacters = allowedCharacters
    }

    func serialize(_ object: [String: URLEncodedFormComponent]) -> String {
        var output: [String] = []
        for (key, component) in object {
            let value = serialize(component, forKey: key)
            output.append(value)
        }

        return output.joinedWithAmpersands()
    }

    func serialize(_ component: URLEncodedFormComponent, forKey key: String) -> String {
        switch component {
        case let .string(string): return "\(escape(key))=\(escape(string))"
        case let .array(array): return serialize(array, forKey: key)
        case let .object(dictionary): return serialize(dictionary, forKey: key)
        }
    }

    func serialize(_ object: [String: URLEncodedFormComponent], forKey key: String) -> String {
        let segments: [String] = object.map { (subKey, value) in
            let keyPath = "[\(subKey)]"
            return serialize(value, forKey: key + keyPath)
        }

        return segments.joinedWithAmpersands()
    }

    func serialize(_ array: [URLEncodedFormComponent], forKey key: String) -> String {
        let segments: [String] = array.map { (component) in
            let keyPath = arrayEncoding.encode(key)
            return serialize(component, forKey: keyPath)
        }

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
        return joined(separator: "&")
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
