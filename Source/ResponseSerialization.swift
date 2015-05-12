// Alamofire.swift
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

// MARK: String

extension Request {
    /**
        Creates a response serializer that returns a string initialized from the response data with the specified string encoding.

        :param: encoding The string encoding. If `nil`, the string encoding will be determined from the server response, falling back to the default HTTP default character set, ISO-8859-1.

        :returns: A string response serializer.
    */
    public class func stringResponseSerializer(var encoding: NSStringEncoding? = nil) -> Serializer {
        return { _, response, data in
            if data == nil || data?.length == 0 {
                return (nil, nil)
            }

            if encoding == nil {
                if let encodingName = response?.textEncodingName {
                    encoding = CFStringConvertEncodingToNSStringEncoding(CFStringConvertIANACharSetNameToEncoding(encodingName))
                }
            }

            let string = NSString(data: data!, encoding: encoding ?? NSISOLatin1StringEncoding)

            return (string, nil)
        }
    }

    /**
        Adds a handler to be called once the request has finished.

        :param: encoding The string encoding. If `nil`, the string encoding will be determined from the server response, falling back to the default HTTP default character set, ISO-8859-1.
        :param: completionHandler A closure to be executed once the request has finished. The closure takes 4 arguments: the URL request, the URL response, if one was received, the string, if one could be created from the URL response and data, and any error produced while creating the string.

        :returns: The request.
    */
    public func responseString(encoding: NSStringEncoding? = nil, completionHandler: (NSURLRequest, NSHTTPURLResponse?, String?, NSError?) -> Void) -> Self  {
        return response(serializer: Request.stringResponseSerializer(encoding: encoding), completionHandler: { request, response, string, error in
            completionHandler(request, response, string as? String, error)
        })
    }
}

// MARK: - JSON

extension Request {
    /**
        Creates a response serializer that returns a JSON object constructed from the response data using `NSJSONSerialization` with the specified reading options.

        :param: options The JSON serialization reading options. `.AllowFragments` by default.

        :returns: A JSON object response serializer.
    */
    public class func JSONResponseSerializer(options: NSJSONReadingOptions = .AllowFragments) -> Serializer {
        return { request, response, data in
            if data == nil || data?.length == 0 {
                return (nil, nil)
            }

            var serializationError: NSError?
            let JSON: AnyObject? = NSJSONSerialization.JSONObjectWithData(data!, options: options, error: &serializationError)

            return (JSON, serializationError)
        }
    }

    /**
        Adds a handler to be called once the request has finished.

        :param: options The JSON serialization reading options. `.AllowFragments` by default.
        :param: completionHandler A closure to be executed once the request has finished. The closure takes 4 arguments: the URL request, the URL response, if one was received, the JSON object, if one could be created from the URL response and data, and any error produced while creating the JSON object.

        :returns: The request.
    */
    public func responseJSON(options: NSJSONReadingOptions = .AllowFragments, completionHandler: (NSURLRequest, NSHTTPURLResponse?, AnyObject?, NSError?) -> Void) -> Self {
        return response(serializer: Request.JSONResponseSerializer(options: options), completionHandler: { request, response, JSON, error in
            completionHandler(request, response, JSON, error)
        })
    }
}

// MARK: - Property List

extension Request {
    /**
        Creates a response serializer that returns an object constructed from the response data using `NSPropertyListSerialization` with the specified reading options.

        :param: options The property list reading options. `0` by default.

        :returns: A property list object response serializer.
    */
    public class func propertyListResponseSerializer(options: NSPropertyListReadOptions = 0) -> Serializer {
        return { request, response, data in
            if data == nil || data?.length == 0 {
                return (nil, nil)
            }

            var propertyListSerializationError: NSError?
            let plist: AnyObject? = NSPropertyListSerialization.propertyListWithData(data!, options: options, format: nil, error: &propertyListSerializationError)

            return (plist, propertyListSerializationError)
        }
    }

    /**
        Adds a handler to be called once the request has finished.

        :param: options The property list reading options. `0` by default.
        :param: completionHandler A closure to be executed once the request has finished. The closure takes 4 arguments: the URL request, the URL response, if one was received, the property list, if one could be created from the URL response and data, and any error produced while creating the property list.

        :returns: The request.
    */
    public func responsePropertyList(options: NSPropertyListReadOptions = 0, completionHandler: (NSURLRequest, NSHTTPURLResponse?, AnyObject?, NSError?) -> Void) -> Self {
        return response(serializer: Request.propertyListResponseSerializer(options: options), completionHandler: { request, response, plist, error in
            completionHandler(request, response, plist, error)
        })
    }
}
