// ResponseSerialization.swift
//
// Copyright (c) 2014–2015 Alamofire Software Foundation (http://alamofire.org/)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation

// MARK: ResponseSerializer

/**
    The type in which all response serializers must conform to in order to serialize a response.
*/
public protocol ResponseSerializer {
    /// The type of serialized object to be created by this `ResponseSerializer`.
    typealias SerializedObject

    /**
        A closure used by response handlers that takes a request, response, and data and returns a result.
    */
    var serializeResponse: (NSURLRequest?, NSHTTPURLResponse?, NSData?) -> Result<SerializedObject> { get }
}

// MARK: -

/**
    A generic `ResponseSerializer` used to serialize a request, response, and data into a serialized object.
*/
public struct GenericResponseSerializer<T>: ResponseSerializer {
    /// The type of serialized object to be created by this `ResponseSerializer`.
    public typealias SerializedObject = T

    /**
        A closure used by response handlers that takes a request, response, and data and returns a result.
    */
    public var serializeResponse: (NSURLRequest?, NSHTTPURLResponse?, NSData?) -> Result<SerializedObject>

    /**
        Initializes the `GenericResponseSerializer` instance with the given serialize response closure.

        - parameter serializeResponse: The closure used to serialize the response.

        - returns: The new generic response serializer instance.
    */
    public init(serializeResponse: (NSURLRequest?, NSHTTPURLResponse?, NSData?) -> Result<SerializedObject>) {
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
    public func response(
        queue queue: dispatch_queue_t? = nil,
        completionHandler: (NSURLRequest?, NSHTTPURLResponse?, NSData?, ErrorType?) -> Void)
        -> Self
    {
        delegate.queue.addOperationWithBlock {
            dispatch_async(queue ?? dispatch_get_main_queue()) {
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
    public func response<T: ResponseSerializer, V where T.SerializedObject == V>(
        queue queue: dispatch_queue_t? = nil,
        responseSerializer: T,
        completionHandler: (NSURLRequest?, NSHTTPURLResponse?, Result<V>) -> Void)
        -> Self
    {
        delegate.queue.addOperationWithBlock {
            let result: Result<T.SerializedObject> = {
                if let error = self.delegate.error {
                    return .Failure(self.delegate.data, error)
                } else {
                    return responseSerializer.serializeResponse(self.request, self.response, self.delegate.data)
                }
            }()

            dispatch_async(queue ?? dispatch_get_main_queue()) {
                completionHandler(self.request, self.response, result)
            }
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
    public static func dataResponseSerializer() -> GenericResponseSerializer<NSData> {
        return GenericResponseSerializer { _, _, data in
            guard let validData = data else {
                let failureReason = "Data could not be serialized. Input data was nil."
                let error = Error.errorWithCode(.DataSerializationFailed, failureReason: failureReason)
                return .Failure(data, error)
            }

            return .Success(validData)
        }
    }

    /**
        Adds a handler to be called once the request has finished.

        - parameter completionHandler: The code to be executed once the request has finished.

        - returns: The request.
    */
    public func responseData(completionHandler: (NSURLRequest?, NSHTTPURLResponse?, Result<NSData>) -> Void) -> Self {
        return response(responseSerializer: Request.dataResponseSerializer(), completionHandler: completionHandler)
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
        var encoding encoding: NSStringEncoding? = nil)
        -> GenericResponseSerializer<String>
    {
        return GenericResponseSerializer { _, response, data in
            guard let validData = data else {
                let failureReason = "String could not be serialized because input data was nil."
                let error = Error.errorWithCode(.StringSerializationFailed, failureReason: failureReason)
                return .Failure(data, error)
            }

            if let encodingName = response?.textEncodingName where encoding == nil {
                encoding = CFStringConvertEncodingToNSStringEncoding(
                    CFStringConvertIANACharSetNameToEncoding(encodingName)
                )
            }

            let actualEncoding = encoding ?? NSISOLatin1StringEncoding

            if let string = NSString(data: validData, encoding: actualEncoding) as? String {
                return .Success(string)
            } else {
                let failureReason = "String could not be serialized with encoding: \(actualEncoding)"
                let error = Error.errorWithCode(.StringSerializationFailed, failureReason: failureReason)
                return .Failure(data, error)
            }
        }
    }

    /**
        Adds a handler to be called once the request has finished.

        - parameter encoding:          The string encoding. If `nil`, the string encoding will be determined from the 
                                       server response, falling back to the default HTTP default character set, 
                                       ISO-8859-1.
        - parameter completionHandler: A closure to be executed once the request has finished. The closure takes 3
                                       arguments: the URL request, the URL response and the result produced while
                                       creating the string.

        - returns: The request.
    */
    public func responseString(
        encoding encoding: NSStringEncoding? = nil,
        completionHandler: (NSURLRequest?, NSHTTPURLResponse?, Result<String>) -> Void)
        -> Self
    {
        return response(
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
        options options: NSJSONReadingOptions = .AllowFragments)
        -> GenericResponseSerializer<AnyObject>
    {
        return GenericResponseSerializer { _, _, data in
            guard let validData = data else {
                let failureReason = "JSON could not be serialized because input data was nil."
                let error = Error.errorWithCode(.JSONSerializationFailed, failureReason: failureReason)
                return .Failure(data, error)
            }

            do {
                let JSON = try NSJSONSerialization.JSONObjectWithData(validData, options: options)
                return .Success(JSON)
            } catch {
                return .Failure(data, error as NSError)
            }
        }
    }

    /**
        Adds a handler to be called once the request has finished.

        - parameter options:           The JSON serialization reading options. `.AllowFragments` by default.
        - parameter completionHandler: A closure to be executed once the request has finished. The closure takes 3
                                       arguments: the URL request, the URL response and the result produced while
                                       creating the JSON object.

        - returns: The request.
    */
    public func responseJSON(
        options options: NSJSONReadingOptions = .AllowFragments,
        completionHandler: (NSURLRequest?, NSHTTPURLResponse?, Result<AnyObject>) -> Void)
        -> Self
    {
        return response(
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
        options options: NSPropertyListReadOptions = NSPropertyListReadOptions())
        -> GenericResponseSerializer<AnyObject>
    {
        return GenericResponseSerializer { _, _, data in
            guard let validData = data else {
                let failureReason = "Property list could not be serialized because input data was nil."
                let error = Error.errorWithCode(.PropertyListSerializationFailed, failureReason: failureReason)
                return .Failure(data, error)
            }

            do {
                let plist = try NSPropertyListSerialization.propertyListWithData(validData, options: options, format: nil)
                return .Success(plist)
            } catch {
                return .Failure(data, error as NSError)
            }
        }
    }

    /**
        Adds a handler to be called once the request has finished.

        - parameter options:           The property list reading options. `0` by default.
        - parameter completionHandler: A closure to be executed once the request has finished. The closure takes 3
                                       arguments: the URL request, the URL response and the result produced while
                                       creating the property list.

        - returns: The request.
    */
    public func responsePropertyList(
        options options: NSPropertyListReadOptions = NSPropertyListReadOptions(),
        completionHandler: (NSURLRequest?, NSHTTPURLResponse?, Result<AnyObject>) -> Void)
        -> Self
    {
        return response(
            responseSerializer: Request.propertyListResponseSerializer(options: options),
            completionHandler: completionHandler
        )
    }
}
