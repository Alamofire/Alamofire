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
    ///
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
    public static var `default`: JSONParameterEncoder { JSONParameterEncoder() }

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
    /// - Parameter encoder: The `JSONEncoder`. `JSONEncoder()` by default.
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
            if request.headers["Content-Type"] == nil {
                request.headers.update(.contentType("application/json"))
            }
        } catch {
            throw AFError.parameterEncodingFailed(reason: .jsonEncodingFailed(error: error))
        }

        return request
    }
}

extension ParameterEncoder where Self == JSONParameterEncoder {
    /// Provides a default `JSONParameterEncoder` instance.
    public static var json: JSONParameterEncoder { JSONParameterEncoder() }

    /// Creates a `JSONParameterEncoder` using the provided `JSONEncoder`.
    ///
    /// - Parameter encoder: `JSONEncoder` used to encode parameters. `JSONEncoder()` by default.
    /// - Returns:           The `JSONParameterEncoder`.
    public static func json(encoder: JSONEncoder = JSONEncoder()) -> JSONParameterEncoder {
        JSONParameterEncoder(encoder: encoder)
    }
}

/// A `ParameterEncoder` that encodes types as URL-encoded query strings to be set on the URL or as body data, depending
/// on the `Destination` set.
///
/// If no `Content-Type` header is already set on the provided `URLRequest`s, it will be set to
/// `application/x-www-form-urlencoded; charset=utf-8`.
///
/// Encoding behavior can be customized by passing an instance of `URLEncodedFormEncoder` to the initializer.
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
        ///
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
    public static var `default`: URLEncodedFormParameterEncoder { URLEncodedFormParameterEncoder() }

    /// The `URLEncodedFormEncoder` to use.
    public let encoder: URLEncodedFormEncoder

    /// The `Destination` for the URL-encoded string.
    public let destination: Destination

    /// Creates an instance with the provided `URLEncodedFormEncoder` instance and `Destination` value.
    ///
    /// - Parameters:
    ///   - encoder:     The `URLEncodedFormEncoder`. `URLEncodedFormEncoder()` by default.
    ///   - destination: The `Destination`. `.methodDependent` by default.
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

        guard let method = request.method else {
            let rawValue = request.method?.rawValue ?? "nil"
            throw AFError.parameterEncoderFailed(reason: .missingRequiredComponent(.httpMethod(rawValue: rawValue)))
        }

        if destination.encodesParametersInURL(for: method),
           var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            let query: String = try Result<String, Error> { try encoder.encode(parameters) }
                .mapError { AFError.parameterEncoderFailed(reason: .encoderFailed(error: $0)) }.get()
            let newQueryString = [components.percentEncodedQuery, query].compactMap { $0 }.joinedWithAmpersands()
            components.percentEncodedQuery = newQueryString.isEmpty ? nil : newQueryString

            guard let newURL = components.url else {
                throw AFError.parameterEncoderFailed(reason: .missingRequiredComponent(.url))
            }

            request.url = newURL
        } else {
            if request.headers["Content-Type"] == nil {
                request.headers.update(.contentType("application/x-www-form-urlencoded; charset=utf-8"))
            }

            request.httpBody = try Result<Data, Error> { try encoder.encode(parameters) }
                .mapError { AFError.parameterEncoderFailed(reason: .encoderFailed(error: $0)) }.get()
        }

        return request
    }
}

extension ParameterEncoder where Self == URLEncodedFormParameterEncoder {
    /// Provides a default `URLEncodedFormParameterEncoder` instance.
    public static var urlEncodedForm: URLEncodedFormParameterEncoder { URLEncodedFormParameterEncoder() }

    /// Creates a `URLEncodedFormParameterEncoder` with the provided encoder and destination.
    ///
    /// - Parameters:
    ///   - encoder:     `URLEncodedFormEncoder` used to encode the parameters. `URLEncodedFormEncoder()` by default.
    ///   - destination: `Destination` to which to encode the parameters. `.methodDependent` by default.
    /// - Returns:       The `URLEncodedFormParameterEncoder`.
    public static func urlEncodedForm(encoder: URLEncodedFormEncoder = URLEncodedFormEncoder(),
                                      destination: URLEncodedFormParameterEncoder.Destination = .methodDependent) -> URLEncodedFormParameterEncoder {
        URLEncodedFormParameterEncoder(encoder: encoder, destination: destination)
    }
}
