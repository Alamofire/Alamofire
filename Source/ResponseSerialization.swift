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

// MARK: ResponseSerializer

/**
    The type in which all response serializers must conform to in order to serialize a response.
*/
public protocol ResponseSerializerType {
    /// The type of serialized object to be created by this `ResponseSerializerType`.
    associatedtype SerializedObject

    /// The type of error to be created by this `ResponseSerializer` if serialization fails.
    associatedtype ErrorObject: ErrorProtocol

    /**
        A closure used by response handlers that takes a request, response, data and error and returns a result.
    */
    var serializeResponse: (Foundation.URLRequest?, HTTPURLResponse?, Data?, NSError?) -> Result<SerializedObject, ErrorObject> { get }
}

// MARK: -

/**
    A generic `ResponseSerializerType` used to serialize a request, response, and data into a serialized object.
*/
public struct ResponseSerializer<Value, Error: ErrorProtocol>: ResponseSerializerType {
    /// The type of serialized object to be created by this `ResponseSerializer`.
    public typealias SerializedObject = Value

    /// The type of error to be created by this `ResponseSerializer` if serialization fails.
    public typealias ErrorObject = Error

    /**
        A closure used by response handlers that takes a request, response, data and error and returns a result.
    */
    public var serializeResponse: (Foundation.URLRequest?, HTTPURLResponse?, Data?, NSError?) -> Result<Value, Error>

    /**
        Initializes the `ResponseSerializer` instance with the given serialize response closure.

        - parameter serializeResponse: The closure used to serialize the response.

        - returns: The new generic response serializer instance.
    */
    public init(serializeResponse: (Foundation.URLRequest?, HTTPURLResponse?, Data?, NSError?) -> Result<Value, Error>) {
        self.serializeResponse = serializeResponse
    }
}

// MARK: - Default

extension Request {

    /**
        Adds a handler to be called once the request has finished.

        - parameter queue:             The queue on which the completion handler is dispatched.
        - parameter completionHandler: The code to be executed once the request has finished.

        - returns: The request.
    */
    @discardableResult
    public func response(
        queue: DispatchQueue? = nil,
        completionHandler: (Foundation.URLRequest?, HTTPURLResponse?, Data?, NSError?) -> Void)
        -> Self
    {
        delegate.queue.addOperation {
            (queue ?? DispatchQueue.main).async {
                completionHandler(self.request, self.response, self.delegate.data, self.delegate.error)
            }
        }

        return self
    }

    /**
        Adds a handler to be called once the request has finished.

        - parameter queue:              The queue on which the completion handler is dispatched.
        - parameter responseSerializer: The response serializer responsible for serializing the request, response,
                                        and data.
        - parameter completionHandler:  The code to be executed once the request has finished.

        - returns: The request.
    */
    public func response<T: ResponseSerializerType>(
        queue: DispatchQueue? = nil,
        responseSerializer: T,
        completionHandler: (Response<T.SerializedObject, T.ErrorObject>) -> Void)
        -> Self
    {
        delegate.queue.addOperation {
            let result = responseSerializer.serializeResponse(
                self.request,
                self.response,
                self.delegate.data,
                self.delegate.error
            )

            let requestCompletedTime = self.endTime ?? CFAbsoluteTimeGetCurrent()
            let initialResponseTime = self.delegate.initialResponseTime ?? requestCompletedTime

            let timeline = Timeline(
                requestStartTime: self.startTime ?? CFAbsoluteTimeGetCurrent(),
                initialResponseTime: initialResponseTime,
                requestCompletedTime: requestCompletedTime,
                serializationCompletedTime: CFAbsoluteTimeGetCurrent()
            )

            let response = Response<T.SerializedObject, T.ErrorObject>(
                request: self.request,
                response: self.response,
                data: self.delegate.data,
                result: result,
                timeline: timeline
            )

            (queue ?? DispatchQueue.main).async { completionHandler(response) }
        }

        return self
    }
}

// MARK: - Data

extension Request {

    /**
        Creates a response serializer that returns the associated data as-is.

        - returns: A data response serializer.
    */
    public static func dataResponseSerializer() -> ResponseSerializer<Data, NSError> {
        return ResponseSerializer { _, response, data, error in
            guard error == nil else { return .failure(error!) }

            if let response = response, response.statusCode == 204 { return .success(Data()) }

            guard let validData = data else {
                let failureReason = "Data could not be serialized. Input data was nil."
                let error = Error.error(code: .dataSerializationFailed, failureReason: failureReason)
                return .failure(error)
            }

            return .success(validData)
        }
    }

    /**
        Adds a handler to be called once the request has finished.

        - parameter completionHandler: The code to be executed once the request has finished.

        - returns: The request.
    */
    @discardableResult
    public func responseData(
        queue: DispatchQueue? = nil,
        completionHandler: (Response<Data, NSError>) -> Void)
        -> Self
    {
        return response(queue: queue, responseSerializer: Request.dataResponseSerializer(), completionHandler: completionHandler)
    }
}

// MARK: - String

extension Request {

    /**
        Creates a response serializer that returns a string initialized from the response data with the specified
        string encoding.

        - parameter encoding: The string encoding. If `nil`, the string encoding will be determined from the server
                              response, falling back to the default HTTP default character set, ISO-8859-1.

        - returns: A string response serializer.
    */
    public static func stringResponseSerializer(
        encoding: String.Encoding? = nil)
        -> ResponseSerializer<String, NSError>
    {
        return ResponseSerializer { _, response, data, error in
            guard error == nil else { return .failure(error!) }

            if let response = response, response.statusCode == 204 { return .success("") }

            guard let validData = data else {
                let failureReason = "String could not be serialized. Input data was nil."
                let error = Error.error(code: .stringSerializationFailed, failureReason: failureReason)
                return .failure(error)
            }

            var convertedEncoding = encoding

            if let encodingName = response?.textEncodingName, convertedEncoding == nil {
                convertedEncoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
                    CFStringConvertIANACharSetNameToEncoding(encodingName))
                )
            }

            let actualEncoding = convertedEncoding ?? String.Encoding.isoLatin1

            if let string = String(data: validData, encoding: actualEncoding) {
                return .success(string)
            } else {
                let failureReason = "String could not be serialized with encoding: \(actualEncoding)"
                let error = Error.error(code: .stringSerializationFailed, failureReason: failureReason)
                return .failure(error)
            }
        }
    }

    /**
        Adds a handler to be called once the request has finished.

        - parameter encoding:          The string encoding. If `nil`, the string encoding will be determined from the
                                       server response, falling back to the default HTTP default character set,
                                       ISO-8859-1.
        - parameter completionHandler: A closure to be executed once the request has finished.

        - returns: The request.
    */
    @discardableResult
    public func responseString(
        queue: DispatchQueue? = nil,
        encoding: String.Encoding? = nil,
        completionHandler: (Response<String, NSError>) -> Void)
        -> Self
    {
        return response(
            queue: queue,
            responseSerializer: Request.stringResponseSerializer(encoding: encoding),
            completionHandler: completionHandler
        )
    }
}

// MARK: - JSON

extension Request {

    /**
        Creates a response serializer that returns a JSON object constructed from the response data using
        `NSJSONSerialization` with the specified reading options.

        - parameter options: The JSON serialization reading options. `.AllowFragments` by default.

        - returns: A JSON object response serializer.
    */
    public static func JSONResponseSerializer(
        options: JSONSerialization.ReadingOptions = .allowFragments)
        -> ResponseSerializer<AnyObject, NSError>
    {
        return ResponseSerializer { _, response, data, error in
            guard error == nil else { return .failure(error!) }

            if let response = response, response.statusCode == 204 { return .success(NSNull()) }

            guard let validData = data, validData.count > 0 else {
                let failureReason = "JSON could not be serialized. Input data was nil or zero length."
                let error = Error.error(code: .jsonSerializationFailed, failureReason: failureReason)
                return .failure(error)
            }

            do {
                let JSON = try JSONSerialization.jsonObject(with: validData, options: options)
                return .success(JSON)
            } catch {
                return .failure(error as NSError)
            }
        }
    }

    /**
        Adds a handler to be called once the request has finished.

        - parameter options:           The JSON serialization reading options. `.AllowFragments` by default.
        - parameter completionHandler: A closure to be executed once the request has finished.

        - returns: The request.
    */
    @discardableResult
    public func responseJSON(
        queue: DispatchQueue? = nil,
        options: JSONSerialization.ReadingOptions = .allowFragments,
        completionHandler: (Response<AnyObject, NSError>) -> Void)
        -> Self
    {
        return response(
            queue: queue,
            responseSerializer: Request.JSONResponseSerializer(options: options),
            completionHandler: completionHandler
        )
    }
}

// MARK: - Property List

extension Request {

    /**
        Creates a response serializer that returns an object constructed from the response data using
        `NSPropertyListSerialization` with the specified reading options.

        - parameter options: The property list reading options. `NSPropertyListReadOptions()` by default.

        - returns: A property list object response serializer.
    */
    public static func propertyListResponseSerializer(
        options: PropertyListSerialization.ReadOptions = PropertyListSerialization.ReadOptions())
        -> ResponseSerializer<AnyObject, NSError>
    {
        return ResponseSerializer { _, response, data, error in
            guard error == nil else { return .failure(error!) }

            if let response = response, response.statusCode == 204 { return .success(NSNull()) }

            guard let validData = data, validData.count > 0 else {
                let failureReason = "Property list could not be serialized. Input data was nil or zero length."
                let error = Error.error(code: .propertyListSerializationFailed, failureReason: failureReason)
                return .failure(error)
            }

            do {
                let plist = try PropertyListSerialization.propertyList(from: validData, options: options, format: nil)
                return .success(plist)
            } catch {
                return .failure(error as NSError)
            }
        }
    }

    /**
        Adds a handler to be called once the request has finished.

        - parameter options:           The property list reading options. `0` by default.
        - parameter completionHandler: A closure to be executed once the request has finished. The closure takes 3
                                       arguments: the URL request, the URL response, the server data and the result
                                       produced while creating the property list.

        - returns: The request.
    */
    public func responsePropertyList(
        queue: DispatchQueue? = nil,
        options: PropertyListSerialization.ReadOptions = PropertyListSerialization.ReadOptions(),
        completionHandler: (Response<AnyObject, NSError>) -> Void)
        -> Self
    {
        return response(
            queue: queue,
            responseSerializer: Request.propertyListResponseSerializer(options: options),
            completionHandler: completionHandler
        )
    }
}
