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

public protocol ParameterEncoder {
    func encode<Parameters: Encodable>(_ parameters: Parameters?, into request: URLRequestConvertible) throws -> URLRequest
}

open class JSONParameterEncoder: ParameterEncoder {
    public static let `default` = JSONParameterEncoder()
    public static let prettyPrinted: JSONParameterEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        return JSONParameterEncoder(encoder: encoder)
    }()

    let encoder: JSONEncoder

    init(encoder: JSONEncoder = JSONEncoder()) {
        self.encoder = encoder
    }

    public func encode<Parameters: Encodable>(_ parameters: Parameters?, into request: URLRequestConvertible) throws -> URLRequest {
        var urlRequest = try request.asURLRequest()

        guard let parameters = parameters else { return urlRequest }

        do {
            let data = try encoder.encode(parameters)
            urlRequest.httpBody = data
            if urlRequest.httpHeaders["Content-Type"] == nil {
                urlRequest.httpHeaders.update(.contentType("application/json"))
            }

            return urlRequest
        } catch {
            throw AFError.parameterEncodingFailed(reason: .jsonEncodingFailed(error: error))
        }
    }
}

public class URLEncodedFormEncoder {
    public enum BoolEncoding {
        case numeric
        case literal
        
        func encode(_ value: Bool) -> String {
            switch self {
            case .numeric: return value ? "1" : "0"
            case .literal: return value ? "true" : "false"
            }
        }
    }
    
    public enum ArrayEncoding {
        case brackets
        case noBrackets
        
        func encode(_ key: String) -> String {
            switch self {
            case .brackets: return "\(key)[]"
            case .noBrackets: return key
            }
        }
    }
    
    enum Error: Swift.Error {
        case invalidRootObject
    }
    
    private let arrayEncoding: ArrayEncoding
    private let boolEncoding: BoolEncoding
    
    init(arrayEncoding: ArrayEncoding = .brackets, boolEncoding: BoolEncoding = .numeric) {
        self.arrayEncoding = arrayEncoding
        self.boolEncoding = boolEncoding
    }
    
    func encode(_ value: Encodable) throws -> URLEncodedFormComponent {
        let encoder = _URLEncodedFormEncoder(boolEncoding: boolEncoding)
        try value.encode(to: encoder)
        
        return encoder.component
    }
    
    func encode(_ value: Encodable) throws -> String {
        let component: URLEncodedFormComponent = try encode(value)
        guard case let .object(object) = component else {
            throw Error.invalidRootObject
        }
        let serializer = URLEncodedFormSerializer(arrayEncoding: arrayEncoding)
        
        return try serializer.serialize(object)
    }
    
    func encode(_ value: Encodable) throws -> Data {
        let string: String = try encode(value)
        
        return Data(string.utf8)
    }
}

final class _URLEncodedFormEncoder {
    var codingPath: [CodingKey]
    // Return empty dictionary, as this encoder supports no userInfo.
    var userInfo: [CodingUserInfoKey : Any] { return [:] }
    
    var container: _URLEncodedFormEncodingContainer?
    var component: URLEncodedFormComponent { return container?.component ?? .string("") }
    
    private let boolEncoding: URLEncodedFormEncoder.BoolEncoding
    
    public init(codingPath: [CodingKey] = [],
                boolEncoding: URLEncodedFormEncoder.BoolEncoding) {
        self.codingPath = codingPath
        
        self.boolEncoding = boolEncoding
    }
}

extension _URLEncodedFormEncoder: Encoder {
    fileprivate func assertCanCreateContainer() {
        precondition(self.container == nil)
    }
    
    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
        assertCanCreateContainer()
        
        let container = _URLEncodedFormEncoder.KeyedContainer<Key>(codingPath: codingPath,
                                                                   boolEncoding: boolEncoding)
        self.container = container
        
        return KeyedEncodingContainer(container)
    }
    
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        assertCanCreateContainer()
        
        let container = _URLEncodedFormEncoder.UnkeyedContainer(codingPath: codingPath,
                                                                boolEncoding: boolEncoding)
        self.container = container
        
        return container
    }
    
    func singleValueContainer() -> SingleValueEncodingContainer {
        assertCanCreateContainer()
        
        let container = _URLEncodedFormEncoder.SingleValueContainer(codingPath: codingPath,
                                                                    boolEncoding: boolEncoding)
        self.container = container
        
        return container
    }
}

protocol _URLEncodedFormEncodingContainer: AnyObject {
    var component: URLEncodedFormComponent { get }
}

enum URLEncodedFormComponent {
    case string(String)
    case array([URLEncodedFormComponent])
    case object([(String, URLEncodedFormComponent)])
}

final class URLEncodedFormSerializer {
    let arrayEncoding: URLEncodedFormEncoder.ArrayEncoding
    
    init(arrayEncoding: URLEncodedFormEncoder.ArrayEncoding) {
        self.arrayEncoding = arrayEncoding
    }
    
    func serialize(_ object: [(String, URLEncodedFormComponent)]) throws -> String {
        var output: [String] = []
        for (key, component) in object {
            // TODO: Escape key
            let value = try serialize(component, forKey: key)
            output.append(value)
        }
        
        return output.joined(separator: "&")
    }
    
    func serialize(_ component: URLEncodedFormComponent, forKey key: String) throws -> String {
        switch component {
        // TODO: Escape string.
        case let .string(string): return "\(key)=\(string)"
        case let .array(array): return try serialize(array, forKey: key)
        case let .object(dictionary): return try serialize(dictionary, forKey: key)
        }
    }
    
    func serialize(_ object: [(String, URLEncodedFormComponent)], forKey key: String) throws -> String {
        let segments: [String] = try object.map { (subKey, value) in
            // TODO: Escape key
            let keyPath = "[\(subKey)]"
            return try serialize(value, forKey: key + keyPath)
        }
        
        return segments.joined(separator: "&")
    }
    
    func serialize(_ array: [URLEncodedFormComponent], forKey key: String) throws -> String {
        let segments: [String] = try array.map { (component) in
            let keyPath = arrayEncoding.encode(key)
            // TODO: Escape key
            return try serialize(component, forKey: keyPath)
        }
        
        return segments.joined(separator: "&")
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
        
        private var storage: [(AnyCodingKey, _URLEncodedFormEncodingContainer)] = []
        
        private let boolEncoding: URLEncodedFormEncoder.BoolEncoding
        
        init(codingPath: [CodingKey],
             boolEncoding: URLEncodedFormEncoder.BoolEncoding) {
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
        let container = _URLEncodedFormEncoder.SingleValueContainer(codingPath: nestedCodingPath(for: key),
                                                                    boolEncoding: boolEncoding)
        storage.append((AnyCodingKey(key), container))
        
        return container
    }
    
    func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        let container = _URLEncodedFormEncoder.UnkeyedContainer(codingPath: nestedCodingPath(for: key),
                                                                boolEncoding: boolEncoding)
        storage.append((AnyCodingKey(key), container))
        
        return container
    }
    
    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        let container = _URLEncodedFormEncoder.KeyedContainer<NestedKey>(codingPath: nestedCodingPath(for: key),
                                                                         boolEncoding: boolEncoding)
        storage.append((AnyCodingKey(key), container))
        
        return KeyedEncodingContainer(container)
    }
    
    func superEncoder() -> Encoder {
        return _URLEncodedFormEncoder(codingPath: codingPath,
                                      boolEncoding: boolEncoding)
        
    }
    
    func superEncoder(forKey key: Key) -> Encoder {
        return _URLEncodedFormEncoder(codingPath: nestedCodingPath(for: key),
                                      boolEncoding: boolEncoding)
    }
}

extension _URLEncodedFormEncoder.KeyedContainer: _URLEncodedFormEncodingContainer {
    var component: URLEncodedFormComponent {
        return .object(storage.map { ($0.0.stringValue, $0.1.component) })
    }
}

extension _URLEncodedFormEncoder {
    final class SingleValueContainer {
        var codingPath: [CodingKey]
        
        var component = URLEncodedFormComponent.string("")
        
        private var canEncodeNewValue = true
        private let boolEncoding: URLEncodedFormEncoder.BoolEncoding
        
        init(codingPath: [CodingKey], boolEncoding: URLEncodedFormEncoder.BoolEncoding) {
            self.codingPath = codingPath
            self.boolEncoding = boolEncoding
        }
        
        private func checkCanEncode(value: Any?) throws {
            guard canEncodeNewValue else {
                let context = EncodingError.Context(codingPath: self.codingPath,
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
                                            debugDescription: "FormData cannot encode nil values.")
        throw EncodingError.invalidValue("nil", context)
    }
    
    func encode(_ value: Bool) throws {
        try checkCanEncode(value: value)
        defer { canEncodeNewValue = false }
        
        component = .string(boolEncoding.encode(value))
    }
    
    func encode(_ value: String) throws {
        try checkCanEncode(value: value)
        defer { canEncodeNewValue = false }
        
        component = .string(value)
    }
    
    func encode(_ value: Double) throws {
        try checkCanEncode(value: value)
        defer { canEncodeNewValue = false }
        
        component = .string(String(value))
    }
    
    func encode(_ value: Float) throws {
        try checkCanEncode(value: value)
        defer { canEncodeNewValue = false }
        
        component = .string(String(value))
    }
    
    func encode(_ value: Int) throws {
        try checkCanEncode(value: value)
        defer { canEncodeNewValue = false }
        
        component = .string(String(value))
    }
    
    func encode(_ value: Int8) throws {
        try checkCanEncode(value: value)
        defer { canEncodeNewValue = false }
        
        component = .string(String(value))
    }
    
    func encode(_ value: Int16) throws {
        try checkCanEncode(value: value)
        defer { canEncodeNewValue = false }
        
        component = .string(String(value))
    }
    
    func encode(_ value: Int32) throws {
        try checkCanEncode(value: value)
        defer { canEncodeNewValue = false }
        
        component = .string(String(value))
    }
    
    func encode(_ value: Int64) throws {
        try checkCanEncode(value: value)
        defer { canEncodeNewValue = false }
        
        component = .string(String(value))
    }
    
    func encode(_ value: UInt) throws {
        try checkCanEncode(value: value)
        defer { canEncodeNewValue = false }
        
        component = .string(String(value))
    }
    
    func encode(_ value: UInt8) throws {
        try checkCanEncode(value: value)
        defer { canEncodeNewValue = false }
        
        component = .string(String(value))
    }
    
    func encode(_ value: UInt16) throws {
        try checkCanEncode(value: value)
        defer { canEncodeNewValue = false }
        
        component = .string(String(value))
    }
    
    func encode(_ value: UInt32) throws {
        try checkCanEncode(value: value)
        defer { canEncodeNewValue = false }
        
        component = .string(String(value))
    }
    
    func encode(_ value: UInt64) throws {
        try checkCanEncode(value: value)
        defer { canEncodeNewValue = false }
        
        component = .string(String(value))
    }
    
    func encode<T>(_ value: T) throws where T : Encodable {
        try checkCanEncode(value: value)
        defer { canEncodeNewValue = false }
        
        let encoder = _URLEncodedFormEncoder(codingPath: codingPath,
                                             boolEncoding: boolEncoding)
        try value.encode(to: encoder)
        component = encoder.component
    }
}

extension _URLEncodedFormEncoder.SingleValueContainer: _URLEncodedFormEncodingContainer { }

extension _URLEncodedFormEncoder {
    final class UnkeyedContainer {
        var codingPath: [CodingKey]
        
        private var storage: [_URLEncodedFormEncodingContainer] = []
        var count: Int { return storage.count }
        var nestedCodingPath: [CodingKey] {
            return codingPath + [AnyCodingKey(intValue: count)!]
        }
        
        private let boolEncoding: URLEncodedFormEncoder.BoolEncoding
        
        init(codingPath: [CodingKey],
             boolEncoding: URLEncodedFormEncoder.BoolEncoding) {
            self.codingPath = codingPath
            self.boolEncoding = boolEncoding
        }
    }
}

extension _URLEncodedFormEncoder.UnkeyedContainer: UnkeyedEncodingContainer {
    func encodeNil() throws {
        let context = EncodingError.Context(codingPath: codingPath,
                                            debugDescription: "FormData cannot encode nil values.")
        throw EncodingError.invalidValue("nil", context)
    }
    
    func encode<T>(_ value: T) throws where T : Encodable {
        var container = nestedSingleValueContainer()
        try container.encode(value)
    }
    
    func nestedSingleValueContainer() -> SingleValueEncodingContainer {
        let container = _URLEncodedFormEncoder.SingleValueContainer(codingPath: nestedCodingPath,
                                                                    boolEncoding: boolEncoding)
        storage.append(container)
        
        return container
    }
    
    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        let container = _URLEncodedFormEncoder.KeyedContainer<NestedKey>(codingPath: nestedCodingPath,
                                                                         boolEncoding: boolEncoding)
        storage.append(container)
        
        return KeyedEncodingContainer(container)
    }
    
    func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let container = _URLEncodedFormEncoder.UnkeyedContainer(codingPath: nestedCodingPath,
                                                                boolEncoding: boolEncoding)
        storage.append(container)
        
        return container
    }
    
    func superEncoder() -> Encoder {
        return _URLEncodedFormEncoder(codingPath: nestedCodingPath,
                                      boolEncoding: boolEncoding)
    }
}

extension _URLEncodedFormEncoder.UnkeyedContainer: _URLEncodedFormEncodingContainer {
    var component: URLEncodedFormComponent {
        return .array(storage.map { $0.component })
    }
}
