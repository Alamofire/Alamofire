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

/// The type in which all data response serializers must conform to in order to serialize a response.
public protocol DataResponseSerializerProtocol {
    /// The type of serialized object to be created by this `DataResponseSerializerType`.
    associatedtype SerializedObject

    /// A closure used by response handlers that takes a request, response, data and error and returns a result.
    var serializeResponse: (URLRequest?, HTTPURLResponse?, Data?, Error?) -> Result<SerializedObject> { get }
}

// MARK: -

///// A generic `DataResponseSerializerType` used to serialize a request, response, and data into a serialized object.
//public struct DataResponseSerializer<Value>: DataResponseSerializerProtocol {
//    /// The type of serialized object to be created by this `DataResponseSerializer`.
//    public typealias SerializedObject = Value
//
//    /// A closure used by response handlers that takes a request, response, data and error and returns a result.
//    public var serializeResponse: (URLRequest?, HTTPURLResponse?, Data?, Error?) -> Result<Value>
//
//    /// Initializes the `ResponseSerializer` instance with the given serialize response closure.
//    ///
//    /// - parameter serializeResponse: The closure used to serialize the response.
//    ///
//    /// - returns: The new generic response serializer instance.
//    public init(serializeResponse: @escaping (URLRequest?, HTTPURLResponse?, Data?, Error?) -> Result<Value>) {
//        self.serializeResponse = serializeResponse
//    }
//}

// MARK: -

/// The type in which all download response serializers must conform to in order to serialize a response.
public protocol DownloadResponseSerializerProtocol {
    /// The type of serialized object to be created by this `DownloadResponseSerializerType`.
    associatedtype SerializedObject

    /// A closure used by response handlers that takes a request, response, url and error and returns a result.
    var serializeDownloadResponse: (URLRequest?, HTTPURLResponse?, URL?, Error?) -> Result<SerializedObject> { get }
}

// MARK: -

///// A generic `DownloadResponseSerializerType` used to serialize a request, response, and data into a serialized object.
//public struct DownloadResponseSerializer<Value>: DownloadResponseSerializerProtocol {
//    /// The type of serialized object to be created by this `DownloadResponseSerializer`.
//    public typealias SerializedObject = Value
//
//    /// A closure used by response handlers that takes a request, response, url and error and returns a result.
//    public var serializeDownloadResponse: (URLRequest?, HTTPURLResponse?, URL?, Error?) -> Result<Value>
//
//    /// Initializes the `ResponseSerializer` instance with the given serialize response closure.
//    ///
//    /// - parameter serializeResponse: The closure used to serialize the response.
//    ///
//    /// - returns: The new generic response serializer instance.
//    public init(serializeResponse: @escaping (URLRequest?, HTTPURLResponse?, URL?, Error?) -> Result<Value>) {
//        self.serializeDownloadResponse = serializeResponse
//    }
//}

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
    /// - parameter queue:             The queue on which the completion handler is dispatched.
    /// - parameter completionHandler: The code to be executed once the request has finished.
    ///
    /// - returns: The request.
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
    /// - parameter queue:              The queue on which the completion handler is dispatched.
    /// - parameter responseSerializer: The response serializer responsible for serializing the request, response,
    ///                                 and data.
    /// - parameter completionHandler:  The code to be executed once the request has finished.
    ///
    /// - returns: The request.
    @discardableResult
    public func response<T: DataResponseSerializerProtocol>(
        queue: DispatchQueue? = nil,
        responseSerializer: T,
        completionHandler: @escaping (DataResponse<T.SerializedObject>) -> Void)
        -> Self
    {
        delegate.queue.addOperation {
            let result = responseSerializer.serializeResponse(
                self.request,
                self.response,
                self.delegate.data,
                self.delegate.error
            )

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
    /// - parameter queue:             The queue on which the completion handler is dispatched.
    /// - parameter completionHandler: The code to be executed once the request has finished.
    ///
    /// - returns: The request.
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
    /// - parameter queue:              The queue on which the completion handler is dispatched.
    /// - parameter responseSerializer: The response serializer responsible for serializing the request, response,
    ///                                 and data contained in the destination url.
    /// - parameter completionHandler:  The code to be executed once the request has finished.
    ///
    /// - returns: The request.
    @discardableResult
    public func response<T: DownloadResponseSerializerProtocol>(
        queue: DispatchQueue? = nil,
        responseSerializer: T,
        completionHandler: @escaping (DownloadResponse<T.SerializedObject>) -> Void)
        -> Self
    {
        delegate.queue.addOperation {
            let result = responseSerializer.serializeDownloadResponse(
                self.request,
                self.response,
                self.downloadDelegate.fileURL,
                self.downloadDelegate.error
            )

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
    /// - parameter completionHandler: The code to be executed once the request has finished.
    ///
    /// - returns: The request.
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

public final class DataResponseSerializer {
    
    public init() { }
    
    func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) -> Result<Data> {
        guard error == nil else { return .failure(error!) }
        
        if let response = response, emptyDataStatusCodes.contains(response.statusCode) { return .success(Data()) }
        
        guard let validData = data else {
            return .failure(AFError.responseSerializationFailed(reason: .inputDataNil))
        }
        
        return .success(validData)
    }
}

extension DataResponseSerializer: DataResponseSerializerProtocol {
    public var serializeResponse: (URLRequest?, HTTPURLResponse?, Data?, Error?) -> Result<Data> {
        return serialize
    }
}

extension DataResponseSerializer: DownloadResponseSerializerProtocol {
    public var serializeDownloadResponse: (URLRequest?, HTTPURLResponse?, URL?, Error?) -> Result<Data> {
        return { (request, response, fileURL, error) in
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
}

extension DownloadRequest {
    /// Adds a handler to be called once the request has finished.
    ///
    /// - parameter completionHandler: The code to be executed once the request has finished.
    ///
    /// - returns: The request.
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

final public class StringResponseSerializer {
    let encoding: String.Encoding?
    
    public init(encoding: String.Encoding? = nil) {
        self.encoding = encoding
    }

    func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) -> Result<String> {
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

extension StringResponseSerializer: DataResponseSerializerProtocol {
    public var serializeResponse: (URLRequest?, HTTPURLResponse?, Data?, Error?) -> Result<String> {
        return serialize
    }
}

extension StringResponseSerializer: DownloadResponseSerializerProtocol {
    public var serializeDownloadResponse: (URLRequest?, HTTPURLResponse?, URL?, Error?) -> Result<String> {
        return { (request, response, fileURL, error) in
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
}

extension DataRequest {
    /// Adds a handler to be called once the request has finished.
    ///
    /// - parameter encoding:          The string encoding. If `nil`, the string encoding will be determined from the
    ///                                server response, falling back to the default HTTP default character set,
    ///                                ISO-8859-1.
    /// - parameter completionHandler: A closure to be executed once the request has finished.
    ///
    /// - returns: The request.
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
    /// - parameter encoding:          The string encoding. If `nil`, the string encoding will be determined from the
    ///                                server response, falling back to the default HTTP default character set,
    ///                                ISO-8859-1.
    /// - parameter completionHandler: A closure to be executed once the request has finished.
    ///
    /// - returns: The request.
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

public final class JSONResponseSerializer {
    let options: JSONSerialization.ReadingOptions
    
    public init(options: JSONSerialization.ReadingOptions = []) {
        self.options = options
    }
    
    func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) -> Result<Any> {
        guard error == nil else { return .failure(error!) }
        
        if let response = response, emptyDataStatusCodes.contains(response.statusCode) { return .success(NSNull()) }
        
        guard let validData = data, validData.count > 0 else {
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

extension JSONResponseSerializer: DataResponseSerializerProtocol {
    public var serializeResponse: (URLRequest?, HTTPURLResponse?, Data?, Error?) -> Result<Any> {
        return serialize
    }
}

extension JSONResponseSerializer: DownloadResponseSerializerProtocol {
    public var serializeDownloadResponse: (URLRequest?, HTTPURLResponse?, URL?, Error?) -> Result<Any> {
        return { (request, response, fileURL, error) in
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
}

extension DataRequest {
    /// Adds a handler to be called once the request has finished.
    ///
    /// - parameter options:           The JSON serialization reading options. Defaults to `.allowFragments`.
    /// - parameter completionHandler: A closure to be executed once the request has finished.
    ///
    /// - returns: The request.
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
    /// - parameter options:           The JSON serialization reading options. Defaults to `.allowFragments`.
    /// - parameter completionHandler: A closure to be executed once the request has finished.
    ///
    /// - returns: The request.
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

// MARK: - JSON Decodable

public final class JSONDecodableResponseSerializer<T: Decodable> {
    let decoder: JSONDecoder
    
    public init(decoder: JSONDecoder = JSONDecoder()) {
        self.decoder = decoder
    }
    
    func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) -> Result<T> {
        guard error == nil else { return .failure(error!) }
        
        if
            let response = response,
            emptyDataStatusCodes.contains(response.statusCode)
        {
            guard let castValue = Empty() as? T else {
                // TODO: Need real error for failed empty cast.
                return .failure(AFError.responseSerializationFailed(reason: .inputDataNilOrZeroLength))
            }
            
            return .success(castValue)
            
        }
        
        guard let validData = data, validData.count > 0 else {
            return .failure(AFError.responseSerializationFailed(reason: .inputDataNilOrZeroLength))
        }
        
        do {
            return .success(try decoder.decode(T.self, from: validData))
        } catch {
            return .failure(error)
        }
    }
}

extension JSONDecodableResponseSerializer: DataResponseSerializerProtocol {
    public var serializeResponse: (URLRequest?, HTTPURLResponse?, Data?, Error?) -> Result<T> {
        return serialize
    }
}

extension JSONDecodableResponseSerializer: DownloadResponseSerializerProtocol {
    public var serializeDownloadResponse: (URLRequest?, HTTPURLResponse?, URL?, Error?) -> Result<T> {
        return { (request, response, fileURL, error) in
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
}

// TODO: Decide how to express empty responses.
public struct Empty: Decodable { }

extension DataRequest {
    /// Adds a handler to be called once the request has finished.
    ///
    /// - parameter options:           The JSON serialization reading options. Defaults to `.allowFragments`.
    /// - parameter completionHandler: A closure to be executed once the request has finished.
    ///
    /// - returns: The request.
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

public final class PropertyListResponseSerializer {
    
    let options: PropertyListSerialization.ReadOptions
    
    public init(options: PropertyListSerialization.ReadOptions = []) {
        self.options = options
    }
    
    func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) -> Result<Any> {
        guard error == nil else { return .failure(error!) }
        
        if let response = response, emptyDataStatusCodes.contains(response.statusCode) { return .success(NSNull()) }
        
        guard let validData = data, validData.count > 0 else {
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

extension PropertyListResponseSerializer: DataResponseSerializerProtocol {
    
    public var serializeResponse: (URLRequest?, HTTPURLResponse?, Data?, Error?) -> Result<Any> {
        return serialize
    }
    
}

extension PropertyListResponseSerializer: DownloadResponseSerializerProtocol {
    
    public var serializeDownloadResponse: (URLRequest?, HTTPURLResponse?, URL?, Error?) -> Result<Any> {
        return { (request, response, fileURL, error) in
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
    
}

extension DataRequest {
    /// Adds a handler to be called once the request has finished.
    ///
    /// - parameter options:           The property list reading options. Defaults to `[]`.
    /// - parameter completionHandler: A closure to be executed once the request has finished.
    ///
    /// - returns: The request.
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
    /// - parameter options:           The property list reading options. Defaults to `[]`.
    /// - parameter completionHandler: A closure to be executed once the request has finished.
    ///
    /// - returns: The request.
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

//MARK: - PropertyList Decodable

public final class PropertyListDecodableResponseSerializer<T: Decodable> {
    let decoder: PropertyListDecoder
    
    public init(decoder: PropertyListDecoder = PropertyListDecoder()) {
        self.decoder = decoder
    }
    
    func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) -> Result<T> {
        guard error == nil else { return .failure(error!) }
        
        guard let validData = data, validData.count > 0 else {
            return .failure(AFError.responseSerializationFailed(reason: .inputDataNilOrZeroLength))
        }
        
        do {
            return .success(try decoder.decode(T.self, from: validData))
        } catch {
            return .failure(error)
        }
    }
}

extension PropertyListDecodableResponseSerializer: DataResponseSerializerProtocol {
    public var serializeResponse: (URLRequest?, HTTPURLResponse?, Data?, Error?) -> Result<T> {
        return serialize
    }
}

extension PropertyListDecodableResponseSerializer: DownloadResponseSerializerProtocol {
    public var serializeDownloadResponse: (URLRequest?, HTTPURLResponse?, URL?, Error?) -> Result<T> {
        return { (request, response, fileURL, error) in
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
}

/// A set of HTTP response status code that do not contain response data.
private let emptyDataStatusCodes: Set<Int> = [204, 205]
