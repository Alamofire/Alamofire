//
//  ResponseSerialization.swift
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

/// The type to which all data response serializers must conform in order to serialize a response.
public protocol DataResponseSerializerProtocol<SerializedObject> {
    /// The type of serialized object to be created.
    associatedtype SerializedObject

    /// Serialize the response `Data` into the provided type.
    ///
    /// - Parameters:
    ///   - request:  `URLRequest` which was used to perform the request, if any.
    ///   - response: `HTTPURLResponse` received from the server, if any.
    ///   - data:     `Data` returned from the server, if any.
    ///   - error:    `Error` produced by Alamofire or the underlying `URLSession` during the request.
    ///
    /// - Returns:    The `SerializedObject`.
    /// - Throws:     Any `Error` produced during serialization.
    func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) throws -> SerializedObject
}

/// The type to which all download response serializers must conform in order to serialize a response.
public protocol DownloadResponseSerializerProtocol<SerializedObject> {
    /// The type of serialized object to be created.
    associatedtype SerializedObject

    /// Serialize the downloaded response `Data` from disk into the provided type.
    ///
    /// - Parameters:
    ///   - request:  `URLRequest` which was used to perform the request, if any.
    ///   - response: `HTTPURLResponse` received from the server, if any.
    ///   - fileURL:  File `URL` to which the response data was downloaded.
    ///   - error:    `Error` produced by Alamofire or the underlying `URLSession` during the request.
    ///
    /// - Returns:    The `SerializedObject`.
    /// - Throws:     Any `Error` produced during serialization.
    func serializeDownload(request: URLRequest?, response: HTTPURLResponse?, fileURL: URL?, error: Error?) throws -> SerializedObject
}

/// A serializer that can handle both data and download responses.
public protocol ResponseSerializer<SerializedObject>: DataResponseSerializerProtocol & DownloadResponseSerializerProtocol {
    /// `DataPreprocessor` used to prepare incoming `Data` for serialization.
    var dataPreprocessor: DataPreprocessor { get }
    /// `HTTPMethod`s for which empty response bodies are considered appropriate.
    var emptyRequestMethods: Set<HTTPMethod> { get }
    /// HTTP response codes for which empty response bodies are considered appropriate.
    var emptyResponseCodes: Set<Int> { get }
}

/// Type used to preprocess `Data` before it handled by a serializer.
public protocol DataPreprocessor {
    /// Process           `Data` before it's handled by a serializer.
    /// - Parameter data: The raw `Data` to process.
    func preprocess(_ data: Data) throws -> Data
}

/// `DataPreprocessor` that returns passed `Data` without any transform.
public struct PassthroughPreprocessor: DataPreprocessor {
    /// Creates an instance.
    public init() {}

    public func preprocess(_ data: Data) throws -> Data { data }
}

/// `DataPreprocessor` that trims Google's typical `)]}',\n` XSSI JSON header.
public struct GoogleXSSIPreprocessor: DataPreprocessor {
    /// Creates an instance.
    public init() {}

    public func preprocess(_ data: Data) throws -> Data {
        (data.prefix(6) == Data(")]}',\n".utf8)) ? data.dropFirst(6) : data
    }
}

extension DataPreprocessor where Self == PassthroughPreprocessor {
    /// Provides a `PassthroughPreprocessor` instance.
    public static var passthrough: PassthroughPreprocessor { PassthroughPreprocessor() }
}

extension DataPreprocessor where Self == GoogleXSSIPreprocessor {
    /// Provides a `GoogleXSSIPreprocessor` instance.
    public static var googleXSSI: GoogleXSSIPreprocessor { GoogleXSSIPreprocessor() }
}

extension ResponseSerializer {
    /// Default `DataPreprocessor`. `PassthroughPreprocessor` by default.
    public static var defaultDataPreprocessor: DataPreprocessor { PassthroughPreprocessor() }
    /// Default `HTTPMethod`s for which empty response bodies are always considered appropriate. `[.head]` by default.
    public static var defaultEmptyRequestMethods: Set<HTTPMethod> { [.head] }
    /// HTTP response codes for which empty response bodies are always considered appropriate. `[204, 205]` by default.
    public static var defaultEmptyResponseCodes: Set<Int> { [204, 205] }

    public var dataPreprocessor: DataPreprocessor { Self.defaultDataPreprocessor }
    public var emptyRequestMethods: Set<HTTPMethod> { Self.defaultEmptyRequestMethods }
    public var emptyResponseCodes: Set<Int> { Self.defaultEmptyResponseCodes }

    /// Determines whether the `request` allows empty response bodies, if `request` exists.
    ///
    /// - Parameter request: `URLRequest` to evaluate.
    ///
    /// - Returns:           `Bool` representing the outcome of the evaluation, or `nil` if `request` was `nil`.
    public func requestAllowsEmptyResponseData(_ request: URLRequest?) -> Bool? {
        request.flatMap(\.httpMethod)
            .flatMap(HTTPMethod.init)
            .map { emptyRequestMethods.contains($0) }
    }

    /// Determines whether the `response` allows empty response bodies, if `response` exists.
    ///
    /// - Parameter response: `HTTPURLResponse` to evaluate.
    ///
    /// - Returns:            `Bool` representing the outcome of the evaluation, or `nil` if `response` was `nil`.
    public func responseAllowsEmptyResponseData(_ response: HTTPURLResponse?) -> Bool? {
        response.map(\.statusCode)
            .map { emptyResponseCodes.contains($0) }
    }

    /// Determines whether `request` and `response` allow empty response bodies.
    ///
    /// - Parameters:
    ///   - request:  `URLRequest` to evaluate.
    ///   - response: `HTTPURLResponse` to evaluate.
    ///
    /// - Returns:    `true` if `request` or `response` allow empty bodies, `false` otherwise.
    public func emptyResponseAllowed(forRequest request: URLRequest?, response: HTTPURLResponse?) -> Bool {
        (requestAllowsEmptyResponseData(request) == true) || (responseAllowsEmptyResponseData(response) == true)
    }
}

/// By default, any serializer declared to conform to both types will get file serialization for free, as it just feeds
/// the data read from disk into the data response serializer.
extension DownloadResponseSerializerProtocol where Self: DataResponseSerializerProtocol {
    public func serializeDownload(request: URLRequest?, response: HTTPURLResponse?, fileURL: URL?, error: Error?) throws -> Self.SerializedObject {
        guard error == nil else { throw error! }

        guard let fileURL else {
            throw AFError.responseSerializationFailed(reason: .inputFileNil)
        }

        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw AFError.responseSerializationFailed(reason: .inputFileReadFailed(at: fileURL))
        }

        do {
            return try serialize(request: request, response: response, data: data, error: error)
        } catch {
            throw error
        }
    }
}

// MARK: - URL

/// A `DownloadResponseSerializerProtocol` that performs only `Error` checking and ensures that a downloaded `fileURL`
/// is present.
public struct URLResponseSerializer: DownloadResponseSerializerProtocol {
    /// Creates an instance.
    public init() {}

    public func serializeDownload(request: URLRequest?,
                                  response: HTTPURLResponse?,
                                  fileURL: URL?,
                                  error: Error?) throws -> URL {
        guard error == nil else { throw error! }

        guard let url = fileURL else {
            throw AFError.responseSerializationFailed(reason: .inputFileNil)
        }

        return url
    }
}

extension DownloadResponseSerializerProtocol where Self == URLResponseSerializer {
    /// Provides a `URLResponseSerializer` instance.
    public static var url: URLResponseSerializer { URLResponseSerializer() }
}

// MARK: - Data

/// A `ResponseSerializer` that performs minimal response checking and returns any response `Data` as-is. By default, a
/// request returning `nil` or no data is considered an error. However, if the request has an `HTTPMethod` or the
/// response has an  HTTP status code valid for empty responses, then an empty `Data` value is returned.
public final class DataResponseSerializer: ResponseSerializer {
    public let dataPreprocessor: DataPreprocessor
    public let emptyResponseCodes: Set<Int>
    public let emptyRequestMethods: Set<HTTPMethod>

    /// Creates a `DataResponseSerializer` using the provided parameters.
    ///
    /// - Parameters:
    ///   - dataPreprocessor:    `DataPreprocessor` used to prepare the received `Data` for serialization.
    ///   - emptyResponseCodes:  The HTTP response codes for which empty responses are allowed. `[204, 205]` by default.
    ///   - emptyRequestMethods: The HTTP request methods for which empty responses are allowed. `[.head]` by default.
    public init(dataPreprocessor: DataPreprocessor = DataResponseSerializer.defaultDataPreprocessor,
                emptyResponseCodes: Set<Int> = DataResponseSerializer.defaultEmptyResponseCodes,
                emptyRequestMethods: Set<HTTPMethod> = DataResponseSerializer.defaultEmptyRequestMethods) {
        self.dataPreprocessor = dataPreprocessor
        self.emptyResponseCodes = emptyResponseCodes
        self.emptyRequestMethods = emptyRequestMethods
    }

    public func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) throws -> Data {
        guard error == nil else { throw error! }

        guard var data, !data.isEmpty else {
            guard emptyResponseAllowed(forRequest: request, response: response) else {
                throw AFError.responseSerializationFailed(reason: .inputDataNilOrZeroLength)
            }

            return Data()
        }

        data = try dataPreprocessor.preprocess(data)

        return data
    }
}

extension ResponseSerializer where Self == DataResponseSerializer {
    /// Provides a default `DataResponseSerializer` instance.
    public static var data: DataResponseSerializer { DataResponseSerializer() }

    /// Creates a `DataResponseSerializer` using the provided parameters.
    ///
    /// - Parameters:
    ///   - dataPreprocessor:    `DataPreprocessor` used to prepare the received `Data` for serialization.
    ///   - emptyResponseCodes:  The HTTP response codes for which empty responses are allowed. `[204, 205]` by default.
    ///   - emptyRequestMethods: The HTTP request methods for which empty responses are allowed. `[.head]` by default.
    ///
    /// - Returns:               The `DataResponseSerializer`.
    public static func data(dataPreprocessor: DataPreprocessor = DataResponseSerializer.defaultDataPreprocessor,
                            emptyResponseCodes: Set<Int> = DataResponseSerializer.defaultEmptyResponseCodes,
                            emptyRequestMethods: Set<HTTPMethod> = DataResponseSerializer.defaultEmptyRequestMethods) -> DataResponseSerializer {
        DataResponseSerializer(dataPreprocessor: dataPreprocessor,
                               emptyResponseCodes: emptyResponseCodes,
                               emptyRequestMethods: emptyRequestMethods)
    }
}

// MARK: - String

/// A `ResponseSerializer` that decodes the response data as a `String`. By default, a request returning `nil` or no
/// data is considered an error. However, if the request has an `HTTPMethod` or the response has an  HTTP status code
/// valid for empty responses, then an empty `String` is returned.
public final class StringResponseSerializer: ResponseSerializer {
    public let dataPreprocessor: DataPreprocessor
    /// Optional string encoding used to validate the response.
    public let encoding: String.Encoding?
    public let emptyResponseCodes: Set<Int>
    public let emptyRequestMethods: Set<HTTPMethod>

    /// Creates an instance with the provided values.
    ///
    /// - Parameters:
    ///   - dataPreprocessor:    `DataPreprocessor` used to prepare the received `Data` for serialization.
    ///   - encoding:            A string encoding. Defaults to `nil`, in which case the encoding will be determined
    ///                          from the server response, falling back to the default HTTP character set, `ISO-8859-1`.
    ///   - emptyResponseCodes:  The HTTP response codes for which empty responses are allowed. `[204, 205]` by default.
    ///   - emptyRequestMethods: The HTTP request methods for which empty responses are allowed. `[.head]` by default.
    public init(dataPreprocessor: DataPreprocessor = StringResponseSerializer.defaultDataPreprocessor,
                encoding: String.Encoding? = nil,
                emptyResponseCodes: Set<Int> = StringResponseSerializer.defaultEmptyResponseCodes,
                emptyRequestMethods: Set<HTTPMethod> = StringResponseSerializer.defaultEmptyRequestMethods) {
        self.dataPreprocessor = dataPreprocessor
        self.encoding = encoding
        self.emptyResponseCodes = emptyResponseCodes
        self.emptyRequestMethods = emptyRequestMethods
    }

    public func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) throws -> String {
        guard error == nil else { throw error! }

        guard var data, !data.isEmpty else {
            guard emptyResponseAllowed(forRequest: request, response: response) else {
                throw AFError.responseSerializationFailed(reason: .inputDataNilOrZeroLength)
            }

            return ""
        }

        data = try dataPreprocessor.preprocess(data)

        var convertedEncoding = encoding

        if let encodingName = response?.textEncodingName, convertedEncoding == nil {
            convertedEncoding = String.Encoding(ianaCharsetName: encodingName)
        }

        let actualEncoding = convertedEncoding ?? .isoLatin1

        guard let string = String(data: data, encoding: actualEncoding) else {
            throw AFError.responseSerializationFailed(reason: .stringSerializationFailed(encoding: actualEncoding))
        }

        return string
    }
}

extension ResponseSerializer where Self == StringResponseSerializer {
    /// Provides a default `StringResponseSerializer` instance.
    public static var string: StringResponseSerializer { StringResponseSerializer() }

    /// Creates a `StringResponseSerializer` with the provided values.
    ///
    /// - Parameters:
    ///   - dataPreprocessor:    `DataPreprocessor` used to prepare the received `Data` for serialization.
    ///   - encoding:            A string encoding. Defaults to `nil`, in which case the encoding will be determined
    ///                          from the server response, falling back to the default HTTP character set, `ISO-8859-1`.
    ///   - emptyResponseCodes:  The HTTP response codes for which empty responses are allowed. `[204, 205]` by default.
    ///   - emptyRequestMethods: The HTTP request methods for which empty responses are allowed. `[.head]` by default.
    ///
    /// - Returns:               The `StringResponseSerializer`.
    public static func string(dataPreprocessor: DataPreprocessor = StringResponseSerializer.defaultDataPreprocessor,
                              encoding: String.Encoding? = nil,
                              emptyResponseCodes: Set<Int> = StringResponseSerializer.defaultEmptyResponseCodes,
                              emptyRequestMethods: Set<HTTPMethod> = StringResponseSerializer.defaultEmptyRequestMethods) -> StringResponseSerializer {
        StringResponseSerializer(dataPreprocessor: dataPreprocessor,
                                 encoding: encoding,
                                 emptyResponseCodes: emptyResponseCodes,
                                 emptyRequestMethods: emptyRequestMethods)
    }
}

// MARK: - JSON

/// A `ResponseSerializer` that decodes the response data using `JSONSerialization`. By default, a request returning
/// `nil` or no data is considered an error. However, if the request has an `HTTPMethod` or the response has an
/// HTTP status code valid for empty responses, then an `NSNull` value is returned.
///
/// - Note: This serializer is deprecated and should not be used. Instead, create concrete types conforming to
///         `Decodable` and use a `DecodableResponseSerializer`.
@available(*, deprecated, message: "JSONResponseSerializer deprecated and will be removed in Alamofire 6. Use DecodableResponseSerializer instead.")
public final class JSONResponseSerializer: ResponseSerializer {
    public let dataPreprocessor: DataPreprocessor
    public let emptyResponseCodes: Set<Int>
    public let emptyRequestMethods: Set<HTTPMethod>
    /// `JSONSerialization.ReadingOptions` used when serializing a response.
    public let options: JSONSerialization.ReadingOptions

    /// Creates an instance with the provided values.
    ///
    /// - Parameters:
    ///   - dataPreprocessor:    `DataPreprocessor` used to prepare the received `Data` for serialization.
    ///   - emptyResponseCodes:  The HTTP response codes for which empty responses are allowed. `[204, 205]` by default.
    ///   - emptyRequestMethods: The HTTP request methods for which empty responses are allowed. `[.head]` by default.
    ///   - options:             The options to use. `.allowFragments` by default.
    public init(dataPreprocessor: DataPreprocessor = JSONResponseSerializer.defaultDataPreprocessor,
                emptyResponseCodes: Set<Int> = JSONResponseSerializer.defaultEmptyResponseCodes,
                emptyRequestMethods: Set<HTTPMethod> = JSONResponseSerializer.defaultEmptyRequestMethods,
                options: JSONSerialization.ReadingOptions = .allowFragments) {
        self.dataPreprocessor = dataPreprocessor
        self.emptyResponseCodes = emptyResponseCodes
        self.emptyRequestMethods = emptyRequestMethods
        self.options = options
    }

    public func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) throws -> Any {
        guard error == nil else { throw error! }

        guard var data, !data.isEmpty else {
            guard emptyResponseAllowed(forRequest: request, response: response) else {
                throw AFError.responseSerializationFailed(reason: .inputDataNilOrZeroLength)
            }

            return NSNull()
        }

        data = try dataPreprocessor.preprocess(data)

        do {
            return try JSONSerialization.jsonObject(with: data, options: options)
        } catch {
            throw AFError.responseSerializationFailed(reason: .jsonSerializationFailed(error: error))
        }
    }
}

// MARK: - Empty

/// Protocol representing an empty response. Use `T.emptyValue()` to get an instance.
public protocol EmptyResponse {
    /// Empty value for the conforming type.
    ///
    /// - Returns: Value of `Self` to use for empty values.
    static func emptyValue() -> Self
}

/// Type representing an empty value. Use `Empty.value` to get the static instance.
public struct Empty: Codable, Sendable {
    /// Static `Empty` instance used for all `Empty` responses.
    public static let value = Empty()
}

extension Empty: EmptyResponse {
    public static func emptyValue() -> Empty {
        value
    }
}

// MARK: - DataDecoder Protocol

/// Any type which can decode `Data` into a `Decodable` type.
public protocol DataDecoder {
    /// Decode `Data` into the provided type.
    ///
    /// - Parameters:
    ///   - type:  The `Type` to be decoded.
    ///   - data:  The `Data` to be decoded.
    ///
    /// - Returns: The decoded value of type `D`.
    /// - Throws:  Any error that occurs during decode.
    func decode<D: Decodable>(_ type: D.Type, from data: Data) throws -> D
}

/// `JSONDecoder` automatically conforms to `DataDecoder`.
extension JSONDecoder: DataDecoder {}
/// `PropertyListDecoder` automatically conforms to `DataDecoder`.
extension PropertyListDecoder: DataDecoder {}

// MARK: - Decodable

/// A `ResponseSerializer` that decodes the response data as a generic value using any type that conforms to
/// `DataDecoder`. By default, this is an instance of `JSONDecoder`. Additionally, a request returning `nil` or no data
/// is considered an error. However, if the request has an `HTTPMethod` or the response has an HTTP status code valid
/// for empty responses then an empty value will be returned. If the decoded type conforms to `EmptyResponse`, the
/// type's `emptyValue()` will be returned. If the decoded type is `Empty`, the `.value` instance is returned. If the
/// decoded type *does not* conform to `EmptyResponse` and isn't `Empty`, an error will be produced.
public final class DecodableResponseSerializer<T: Decodable>: ResponseSerializer {
    public let dataPreprocessor: DataPreprocessor
    /// The `DataDecoder` instance used to decode responses.
    public let decoder: DataDecoder
    public let emptyResponseCodes: Set<Int>
    public let emptyRequestMethods: Set<HTTPMethod>

    /// Creates an instance using the values provided.
    ///
    /// - Parameters:
    ///   - dataPreprocessor:    `DataPreprocessor` used to prepare the received `Data` for serialization.
    ///   - decoder:             The `DataDecoder`. `JSONDecoder()` by default.
    ///   - emptyResponseCodes:  The HTTP response codes for which empty responses are allowed. `[204, 205]` by default.
    ///   - emptyRequestMethods: The HTTP request methods for which empty responses are allowed. `[.head]` by default.
    public init(dataPreprocessor: DataPreprocessor = DecodableResponseSerializer.defaultDataPreprocessor,
                decoder: DataDecoder = JSONDecoder(),
                emptyResponseCodes: Set<Int> = DecodableResponseSerializer.defaultEmptyResponseCodes,
                emptyRequestMethods: Set<HTTPMethod> = DecodableResponseSerializer.defaultEmptyRequestMethods) {
        self.dataPreprocessor = dataPreprocessor
        self.decoder = decoder
        self.emptyResponseCodes = emptyResponseCodes
        self.emptyRequestMethods = emptyRequestMethods
    }

    public func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) throws -> T {
        guard error == nil else { throw error! }

        guard var data, !data.isEmpty else {
            guard emptyResponseAllowed(forRequest: request, response: response) else {
                throw AFError.responseSerializationFailed(reason: .inputDataNilOrZeroLength)
            }

            guard let emptyResponseType = T.self as? EmptyResponse.Type, let emptyValue = emptyResponseType.emptyValue() as? T else {
                throw AFError.responseSerializationFailed(reason: .invalidEmptyResponse(type: "\(T.self)"))
            }

            return emptyValue
        }

        data = try dataPreprocessor.preprocess(data)

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw AFError.responseSerializationFailed(reason: .decodingFailed(error: error))
        }
    }
}

extension ResponseSerializer {
    /// Creates a `DecodableResponseSerializer` using the values provided.
    ///
    /// - Parameters:
    ///   - type:                `Decodable` type to decode from response data.
    ///   - dataPreprocessor:    `DataPreprocessor` used to prepare the received `Data` for serialization.
    ///   - decoder:             The `DataDecoder`. `JSONDecoder()` by default.
    ///   - emptyResponseCodes:  The HTTP response codes for which empty responses are allowed. `[204, 205]` by default.
    ///   - emptyRequestMethods: The HTTP request methods for which empty responses are allowed. `[.head]` by default.
    ///
    /// - Returns:               The `DecodableResponseSerializer`.
    public static func decodable<T: Decodable>(of type: T.Type,
                                               dataPreprocessor: DataPreprocessor = DecodableResponseSerializer<T>.defaultDataPreprocessor,
                                               decoder: DataDecoder = JSONDecoder(),
                                               emptyResponseCodes: Set<Int> = DecodableResponseSerializer<T>.defaultEmptyResponseCodes,
                                               emptyRequestMethods: Set<HTTPMethod> = DecodableResponseSerializer<T>.defaultEmptyRequestMethods) -> DecodableResponseSerializer<T> where Self == DecodableResponseSerializer<T> {
        DecodableResponseSerializer<T>(dataPreprocessor: dataPreprocessor,
                                       decoder: decoder,
                                       emptyResponseCodes: emptyResponseCodes,
                                       emptyRequestMethods: emptyRequestMethods)
    }
}
