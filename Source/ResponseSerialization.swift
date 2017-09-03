//
//  ResponseSerialization.swift
//
//  Copyright (c) 2014-2016 Alamofire Software Foundation (http://alamofire.org/)
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

// MARK: Protocols

/// The type to which all data response serializers must conform in order to serialize a response.
public protocol DataResponseSerializerProtocol {
    /// The type of serialized object to be created by this serializer.
    associatedtype SerializedObject

    /// The function used to serialize the response data in response handlers.
    func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) -> Result<SerializedObject>
}

/// The type to which all download response serializers must conform in order to serialize a response.
public protocol DownloadResponseSerializerProtocol {
    /// The type of serialized object to be created by this `DownloadResponseSerializerType`.
    associatedtype SerializedObject

    /// The function used to serialize the downloaded data in response handlers.
    func serializeDownload(request: URLRequest?, response: HTTPURLResponse?, fileURL: URL?, error: Error?) -> Result<SerializedObject>
}

/// A serializer that can handle both data and download responses.
public typealias ResponseSerializer = DataResponseSerializerProtocol & DownloadResponseSerializerProtocol

/// By default, any serializer declared to conform to both types will get file serialization for free, as it just feeds
/// the data read from disk into the data response serializer.
public extension DownloadResponseSerializerProtocol where Self: DataResponseSerializerProtocol {
    public func serializeDownload(request: URLRequest?, response: HTTPURLResponse?, fileURL: URL?, error: Error?) -> Result<SerializedObject> {
        guard error == nil else { return .failure(error!) }

        guard let fileURL = fileURL else {
            return .failure(AFError.responseSerializationFailed(reason: .inputFileNil))
        }

        do {
            let data = try Data(contentsOf: fileURL)
            return self.serialize(request: request, response: response, data: data, error: error)
        } catch {
            return .failure(AFError.responseSerializationFailed(reason: .inputFileReadFailed(at: fileURL)))
        }
    }
}

// MARK: - AnyResponseSerializer

/// A generic `ResponseSerializer` conforming type.
public final class AnyResponseSerializer<Value>: ResponseSerializer {
    /// A closure which can be used to serialize data responses.
    public typealias DataSerializer = (_ request: URLRequest?, _ response: HTTPURLResponse?, _ data: Data?, _ error: Error?) -> Result<Value>
    /// A closure which can be used to serialize download reponses.
    public typealias DownloadSerializer = (_ request: URLRequest?, _ response: HTTPURLResponse?, _ fileURL: URL?, _ error: Error?) -> Result<Value>

    let dataSerializer: DataSerializer
    let downloadSerializer: DownloadSerializer?

    /// Initialze the instance with both a `DataSerializer` closure and a `DownloadSerializer` closure.
    ///
    /// - Parameters:
    ///   - dataSerializer:     A `DataSerializer` closure.
    ///   - downloadSerializer: A `DownloadSerializer` closure.
    public init(dataSerializer: @escaping DataSerializer, downloadSerializer: @escaping DownloadSerializer) {
        self.dataSerializer = dataSerializer
        self.downloadSerializer = downloadSerializer
    }

    /// Initialze the instance with a `DataSerializer` closure. Download serialization will fallback to a default
    /// implementation.
    ///
    /// - Parameters:
    ///   - dataSerializer:     A `DataSerializer` closure.
    public init(dataSerializer: @escaping DataSerializer) {
        self.dataSerializer = dataSerializer
        self.downloadSerializer = nil
    }

    public func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) -> Result<Value> {
        return dataSerializer(request, response, data, error)
    }

    public func serializeDownload(request: URLRequest?, response: HTTPURLResponse?, fileURL: URL?, error: Error?) -> Result<Value> {
        return downloadSerializer?(request, response, fileURL, error) ?? { (request, response, fileURL, error) in
            guard error == nil else { return .failure(error!) }

            guard let fileURL = fileURL else {
                return .failure(AFError.responseSerializationFailed(reason: .inputFileNil))
            }

            do {
                let data = try Data(contentsOf: fileURL)
                return self.serialize(request: request, response: response, data: data, error: error)
            } catch {
                return .failure(AFError.responseSerializationFailed(reason: .inputFileReadFailed(at: fileURL)))
            }
        }(request, response, fileURL, error)
    }
}

// MARK: - Timeline

extension Request {
    var timeline: Timeline {
        let requestStartTime = self.startTime ?? CFAbsoluteTimeGetCurrent()
        let requestCompletedTime = self.endTime ?? CFAbsoluteTimeGetCurrent()
        let initialResponseTime = self.delegate.initialResponseTime ?? requestCompletedTime

        return Timeline(
            requestStartTime: requestStartTime,
            initialResponseTime: initialResponseTime,
            requestCompletedTime: requestCompletedTime,
            serializationCompletedTime: CFAbsoluteTimeGetCurrent()
        )
    }
}

// MARK: - Default

extension DataRequest {
    /// Adds a handler to be called once the request has finished.
    ///
    /// - Parameters:
    ///   - queue:             The queue on which the completion handler is dispatched. Defaults to `nil`, which means
    ///                        the handler is called on `.main`.
    ///   - completionHandler: The code to be executed once the request has finished.
    /// - Returns:             The request.
    @discardableResult
    public func response(queue: DispatchQueue? = nil, completionHandler: @escaping (DefaultDataResponse) -> Void) -> Self {
        delegate.queue.addOperation {
            (queue ?? DispatchQueue.main).async {
                var dataResponse = DefaultDataResponse(
                    request: self.request,
                    response: self.response,
                    data: self.delegate.data,
                    error: self.delegate.error,
                    timeline: self.timeline
                )

                dataResponse.add(self.delegate.metrics)

                completionHandler(dataResponse)
            }
        }

        return self
    }

    /// Adds a handler to be called once the request has finished.
    ///
    /// - Parameters:
    ///   - queue:              The queue on which the completion handler is dispatched. Defaults to `nil`, which means
    ///                         the handler is called on `.main`.
    ///   - responseSerializer: The response serializer responsible for serializing the request, response, and data.
    ///   - completionHandler:  The code to be executed once the request has finished.
    /// - Returns:              The request.
    @discardableResult
    public func response<T: DataResponseSerializerProtocol>(
        queue: DispatchQueue? = nil,
        responseSerializer: T,
        completionHandler: @escaping (DataResponse<T.SerializedObject>) -> Void)
        -> Self
    {
        delegate.queue.addOperation {
            let result = responseSerializer.serialize(request: self.request,
                                                      response: self.response,
                                                      data: self.delegate.data,
                                                      error: self.delegate.error)
            var dataResponse = DataResponse<T.SerializedObject>(
                request: self.request,
                response: self.response,
                data: self.delegate.data,
                result: result,
                timeline: self.timeline
            )

            dataResponse.add(self.delegate.metrics)

            (queue ?? DispatchQueue.main).async { completionHandler(dataResponse) }
        }

        return self
    }
}

extension DownloadRequest {
    /// Adds a handler to be called once the request has finished.
    ///
    /// - Parameters:
    ///   - queue:             The queue on which the completion handler is dispatched. Defaults to `nil`, which means
    ///                        the handler is called on `.main`.
    ///   - completionHandler: The code to be executed once the request has finished.
    /// - Returns:             The request.
    @discardableResult
    public func response(
        queue: DispatchQueue? = nil,
        completionHandler: @escaping (DefaultDownloadResponse) -> Void)
        -> Self
    {
        delegate.queue.addOperation {
            (queue ?? DispatchQueue.main).async {
                var downloadResponse = DefaultDownloadResponse(
                    request: self.request,
                    response: self.response,
                    temporaryURL: self.downloadDelegate.temporaryURL,
                    destinationURL: self.downloadDelegate.destinationURL,
                    resumeData: self.downloadDelegate.resumeData,
                    error: self.downloadDelegate.error,
                    timeline: self.timeline
                )

                downloadResponse.add(self.delegate.metrics)

                completionHandler(downloadResponse)
            }
        }

        return self
    }

    /// Adds a handler to be called once the request has finished.
    ///
    /// - Parameters:
    ///   - queue:              The queue on which the completion handler is dispatched. Defaults to `nil`, which means
    ///                         the handler is called on `.main`.
    ///   - responseSerializer: The response serializer responsible for serializing the request, response, and data
    ///                         contained in the destination url.
    ///   - completionHandler:  The code to be executed once the request has finished.
    /// - Returns:              The request.
    @discardableResult
    public func response<T: DownloadResponseSerializerProtocol>(
        queue: DispatchQueue? = nil,
        responseSerializer: T,
        completionHandler: @escaping (DownloadResponse<T.SerializedObject>) -> Void)
        -> Self
    {
        delegate.queue.addOperation {
            let result = responseSerializer.serializeDownload(request: self.request,
                                                              response: self.response,
                                                              fileURL: self.downloadDelegate.fileURL,
                                                              error: self.downloadDelegate.error)
            var downloadResponse = DownloadResponse<T.SerializedObject>(
                request: self.request,
                response: self.response,
                temporaryURL: self.downloadDelegate.temporaryURL,
                destinationURL: self.downloadDelegate.destinationURL,
                resumeData: self.downloadDelegate.resumeData,
                result: result,
                timeline: self.timeline
            )

            downloadResponse.add(self.delegate.metrics)

            (queue ?? DispatchQueue.main).async { completionHandler(downloadResponse) }
        }

        return self
    }
}

// MARK: - Data

extension DataRequest {
    /// Adds a handler to be called once the request has finished.
    ///
    /// - Parameters:
    ///   - queue:             The queue on which the completion handler is dispatched. Defaults to `nil`, which means
    ///                        the handler is called on `.main`.
    ///   - completionHandler: The code to be executed once the request has finished.
    /// - Returns:             The request.
    @discardableResult
    public func responseData(
        queue: DispatchQueue? = nil,
        completionHandler: @escaping (DataResponse<Data>) -> Void)
        -> Self
    {
        return response(
            queue: queue,
            responseSerializer: DataResponseSerializer(),
            completionHandler: completionHandler
        )
    }
}

/// A `ResponseSerializer` that performs minimal reponse checking and returns any response data as-is. By default, a
/// request returning `nil` or no data is considered an error. However, if the response is has a status code valid for
/// empty responses (`204`, `205`), then an empty `Data` value is returned.
public final class DataResponseSerializer: ResponseSerializer {

    public init() { }

    public func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) -> Result<Data> {
        guard error == nil else { return .failure(error!) }

        if let response = response, emptyDataStatusCodes.contains(response.statusCode) { return .success(Data()) }

        guard let validData = data else {
            return .failure(AFError.responseSerializationFailed(reason: .inputDataNil))
        }

        return .success(validData)
    }
}

extension DownloadRequest {
    /// Adds a handler to be called once the request has finished.
    ///
    /// - Parameters:
    ///   - queue:             The queue on which the completion handler is dispatched. Defaults to `nil`, which means
    ///                        the handler is called on `.main`.
    ///   - completionHandler: The code to be executed once the request has finished.
    /// - Returns:             The request.
    @discardableResult
    public func responseData(
        queue: DispatchQueue? = nil,
        completionHandler: @escaping (DownloadResponse<Data>) -> Void)
        -> Self
    {
        return response(
            queue: queue,
            responseSerializer: DataResponseSerializer(),
            completionHandler: completionHandler
        )
    }
}

// MARK: - String

/// A `ResponseSerializer` that decodes the response data as a `String`. By default, a request returning `nil` or no
/// data is considered an error. However, if the response is has a status code valid for empty responses (`204`, `205`),
/// then an empty `String` is returned.
public final class StringResponseSerializer: ResponseSerializer {
    let encoding: String.Encoding?

    /// Creates an instance with the given `String.Encoding`.
    ///
    /// - Parameter encoding: A string encoding. Defaults to `nil`, in which case the encoding will be determined from
    ///                       the server response, falling back to the default HTTP character set, `ISO-8859-1`.
    public init(encoding: String.Encoding? = nil) {
        self.encoding = encoding
    }

    public func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) -> Result<String> {
        guard error == nil else { return .failure(error!) }

        if let response = response, emptyDataStatusCodes.contains(response.statusCode) { return .success("") }

        guard let validData = data else {
            return .failure(AFError.responseSerializationFailed(reason: .inputDataNil))
        }

        var convertedEncoding = encoding

        if let encodingName = response?.textEncodingName as CFString!, convertedEncoding == nil {
            convertedEncoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
                CFStringConvertIANACharSetNameToEncoding(encodingName))
            )
        }

        let actualEncoding = convertedEncoding ?? .isoLatin1

        if let string = String(data: validData, encoding: actualEncoding) {
            return .success(string)
        } else {
            return .failure(AFError.responseSerializationFailed(reason: .stringSerializationFailed(encoding: actualEncoding)))
        }
    }
}

extension DataRequest {
    /// Adds a handler to be called once the request has finished.
    ///
    /// - Parameters:
    ///   - queue:             The queue on which the completion handler is dispatched. Defaults to `nil`, which means
    ///                        the handler is called on `.main`.
    ///   - encoding:          The string encoding. Defaults to `nil`, in which case the encoding will be determined from
    ///                        the server response, falling back to the default HTTP character set, `ISO-8859-1`.
    ///   - completionHandler: A closure to be executed once the request has finished.
    /// - Returns:             The request.
    @discardableResult
    public func responseString(
        queue: DispatchQueue? = nil,
        encoding: String.Encoding? = nil,
        completionHandler: @escaping (DataResponse<String>) -> Void)
        -> Self
    {
        return response(
            queue: queue,
            responseSerializer: StringResponseSerializer(encoding: encoding),
            completionHandler: completionHandler
        )
    }
}

extension DownloadRequest {
    /// Adds a handler to be called once the request has finished.
    ///
    /// - Parameters:
    ///   - queue:             The queue on which the completion handler is dispatched. Defaults to `nil`, which means
    ///                        the handler is called on `.main`.
    ///   - encoding:          The string encoding. Defaults to `nil`, in which case the encoding will be determined from
    ///                        the server response, falling back to the default HTTP character set, `ISO-8859-1`.
    ///   - completionHandler: A closure to be executed once the request has finished.
    /// - Returns:             The request.
    @discardableResult
    public func responseString(
        queue: DispatchQueue? = nil,
        encoding: String.Encoding? = nil,
        completionHandler: @escaping (DownloadResponse<String>) -> Void)
        -> Self
    {
        return response(
            queue: queue,
            responseSerializer: StringResponseSerializer(encoding: encoding),
            completionHandler: completionHandler
        )
    }
}

// MARK: - JSON

/// A `ResponseSerializer` that decodes the response data using `JSONSerialization`. By default, a request returning
/// `nil` or no data is considered an error. However, if the response is has a status code valid for empty responses
/// (`204`, `205`), then an `NSNull`  value is returned.
public final class JSONResponseSerializer: ResponseSerializer {
    let options: JSONSerialization.ReadingOptions

    /// Creates an instance with the given `JSONSerilization.ReadingOptions`.
    ///
    /// - Parameter options: The options to use. Defaults to `.allowFragments`.
    public init(options: JSONSerialization.ReadingOptions = .allowFragments) {
        self.options = options
    }

    public func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) -> Result<Any> {
        guard error == nil else { return .failure(error!) }

        guard let validData = data, validData.count > 0 else {
            if let response = response, emptyDataStatusCodes.contains(response.statusCode) {
                return .success(NSNull())
            }

            return .failure(AFError.responseSerializationFailed(reason: .inputDataNilOrZeroLength))
        }

        do {
            let json = try JSONSerialization.jsonObject(with: validData, options: options)
            return .success(json)
        } catch {
            return .failure(AFError.responseSerializationFailed(reason: .jsonSerializationFailed(error: error)))
        }
    }
}

extension DataRequest {
    /// Adds a handler to be called once the request has finished.
    ///
    /// - Parameters:
    ///   - queue:             The queue on which the completion handler is dispatched. Defaults to `nil`, which means
    ///                        the handler is called on `.main`.
    ///   - options:           The JSON serialization reading options. Defaults to `.allowFragments`.
    ///   - completionHandler: A closure to be executed once the request has finished.
    /// - Returns:             The request.
    @discardableResult
    public func responseJSON(
        queue: DispatchQueue? = nil,
        options: JSONSerialization.ReadingOptions = .allowFragments,
        completionHandler: @escaping (DataResponse<Any>) -> Void)
        -> Self
    {
        return response(
            queue: queue,
            responseSerializer: JSONResponseSerializer(options: options),
            completionHandler: completionHandler
        )
    }
}

extension DownloadRequest {
    /// Adds a handler to be called once the request has finished.
    ///
    /// - Parameters:
    ///   - queue:             The queue on which the completion handler is dispatched. Defaults to `nil`, which means
    ///                        the handler is called on `.main`.
    ///   - options:           The JSON serialization reading options. Defaults to `.allowFragments`.
    ///   - completionHandler: A closure to be executed once the request has finished.
    /// - Returns:             The request.
    @discardableResult
    public func responseJSON(
        queue: DispatchQueue? = nil,
        options: JSONSerialization.ReadingOptions = .allowFragments,
        completionHandler: @escaping (DownloadResponse<Any>) -> Void)
        -> Self
    {
        return response(
            queue: queue,
            responseSerializer: JSONResponseSerializer(options: options),
            completionHandler: completionHandler
        )
    }
}

// MARK: - Empty

/// A type representing an empty response. Use `Empty.response` to get the instance.
public struct Empty: Decodable {
    public static let response = Empty()
}

// MARK: - JSON Decodable

/// A `ResponseSerializer` that decodes the response data as a generic value using a `JSONDecoder`. By default, a
/// request returning `nil` or no data is considered an error. However, if the response is has a status code valid for
/// empty responses (`204`, `205`), then the `Empty.response` value is returned.
public final class JSONDecodableResponseSerializer<T: Decodable>: ResponseSerializer {
    let decoder: JSONDecoder

    /// Creates an instance with the given `JSONDecoder` instance.
    ///
    /// - Parameter decoder: A decoder. Defaults to a `JSONDecoder` with default settings.
    public init(decoder: JSONDecoder = JSONDecoder()) {
        self.decoder = decoder
    }

    public func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) -> Result<T> {
        guard error == nil else { return .failure(error!) }

        guard let validData = data, validData.count > 0 else {
            if let response = response, emptyDataStatusCodes.contains(response.statusCode) {
                guard let emptyResponse = Empty.response as? T else {
                    return .failure(AFError.responseSerializationFailed(reason: .invalidEmptyResponse(type: "\(T.self)")))
                }

                return .success(emptyResponse)
            }

            return .failure(AFError.responseSerializationFailed(reason: .inputDataNilOrZeroLength))
        }

        do {
            return .success(try decoder.decode(T.self, from: validData))
        } catch {
            return .failure(error)
        }
    }
}

extension DataRequest {
    /// Adds a handler to be called once the request has finished.
    ///
    /// - Parameters:
    ///   - queue:             The queue on which the completion handler is dispatched. Defaults to `nil`, which means
    ///                        the handler is called on `.main`.
    ///   - decoder:           The decoder to use to decode the response. Defaults to a `JSONDecoder` with default
    ///                        settings.
    ///   - completionHandler: A closure to be executed once the request has finished.
    /// - Returns:             The request.
    @discardableResult
    public func responseJSONDecodable<T: Decodable>(
        queue: DispatchQueue? = nil,
        decoder: JSONDecoder = JSONDecoder(),
        completionHandler: @escaping (DataResponse<T>) -> Void)
        -> Self
    {
        return response(
            queue: queue,
            responseSerializer: JSONDecodableResponseSerializer(decoder: decoder),
            completionHandler: completionHandler
        )
    }
}

// MARK: - Property List

/// A `ResponseSerializer` that decodes the response data using `PropertyListSerialization`. By default, a request
/// returning `nil` or no data is considered an error. However, if the response is has a status code valid for empty
/// responses (`204`, `205`), then an `NSNull` value is returned.
public final class PropertyListResponseSerializer: ResponseSerializer {
    let options: PropertyListSerialization.ReadOptions

    /// Creates an instance with the given `JSONSerilization.ReadingOptions`.
    ///
    /// - Parameter options: The options to use. Defaults to `[]`.
    public init(options: PropertyListSerialization.ReadOptions = []) {
        self.options = options
    }

    public func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) -> Result<Any> {
        guard error == nil else { return .failure(error!) }

        guard let validData = data, validData.count > 0 else {
            if let response = response, emptyDataStatusCodes.contains(response.statusCode) {
                return .success(NSNull())
            }

            return .failure(AFError.responseSerializationFailed(reason: .inputDataNilOrZeroLength))
        }

        do {
            let plist = try PropertyListSerialization.propertyList(from: validData, options: options, format: nil)
            return .success(plist)
        } catch {
            return .failure(AFError.responseSerializationFailed(reason: .propertyListSerializationFailed(error: error)))
        }
    }
}

extension DataRequest {
    /// Adds a handler to be called once the request has finished.
    ///
    /// - Parameters:
    ///   - queue:             The queue on which the completion handler is dispatched. Defaults to `nil`, which means
    ///                        the handler is called on `.main`.
    ///   - options:           The property list reading options. Defaults to `[]`.
    ///   - completionHandler: A closure to be executed once the request has finished.
    /// - Returns:             The request.
    @discardableResult
    public func responsePropertyList(
        queue: DispatchQueue? = nil,
        options: PropertyListSerialization.ReadOptions = [],
        completionHandler: @escaping (DataResponse<Any>) -> Void)
        -> Self
    {
        return response(
            queue: queue,
            responseSerializer: PropertyListResponseSerializer(options: options),
            completionHandler: completionHandler
        )
    }
}

extension DownloadRequest {
    /// Adds a handler to be called once the request has finished.
    ///
    /// - Parameters:
    ///   - queue:             The queue on which the completion handler is dispatched. Defaults to `nil`, which means
    ///                        the handler is called on `.main`.
    ///   - options:           The property list reading options. Defaults to `[]`.
    ///   - completionHandler: A closure to be executed once the request has finished.
    /// - Returns:             The request.
    @discardableResult
    public func responsePropertyList(
        queue: DispatchQueue? = nil,
        options: PropertyListSerialization.ReadOptions = [],
        completionHandler: @escaping (DownloadResponse<Any>) -> Void)
        -> Self
    {
        return response(
            queue: queue,
            responseSerializer: PropertyListResponseSerializer(options: options),
            completionHandler: completionHandler
        )
    }
}

// MARK: - PropertyList Decodable

/// A `ResponseSerializer` that decodes the response data as a generic value using a `PropertyListDecoder`. By default,
/// a request returning `nil` or no data is considered an error. However, if the response is has a status code valid for
/// empty responses (`204`, `205`), then the `Empty.response` value is returned.
public final class PropertyListDecodableResponseSerializer<T: Decodable>: ResponseSerializer {
    let decoder: PropertyListDecoder


    /// Creates an instance with the given `JSONDecoder` instance.
    ///
    /// - Parameter decoder: A decoder. Defaults to a `PropertyListDecoder` with default settings.
    public init(decoder: PropertyListDecoder = PropertyListDecoder()) {
        self.decoder = decoder
    }

    public func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) -> Result<T> {
        guard error == nil else { return .failure(error!) }

        guard let validData = data, validData.count > 0 else {
            if let response = response, emptyDataStatusCodes.contains(response.statusCode) {
                guard let emptyResponse = Empty.response as? T else {
                    return .failure(AFError.responseSerializationFailed(reason: .invalidEmptyResponse(type: "\(T.self)")))
                }

                return .success(emptyResponse)
            }

            return .failure(AFError.responseSerializationFailed(reason: .inputDataNilOrZeroLength))
        }

        do {
            return .success(try decoder.decode(T.self, from: validData))
        } catch {
            return .failure(error)
        }
    }
}

/// A set of HTTP response status code that do not contain response data.
private let emptyDataStatusCodes: Set<Int> = [204, 205]
