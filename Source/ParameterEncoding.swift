//
//  ParameterEncoding.swift
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

/**
    HTTP method definitions.

    See https://tools.ietf.org/html/rfc7231#section-4.3
*/
public enum Method: String {
    case OPTIONS, GET, HEAD, POST, PUT, PATCH, DELETE, TRACE, CONNECT
}

// MARK: ParameterEncoding

/**
    Used to specify the way in which a set of parameters are applied to a URL request.

    - `URL`:             Creates a query string to be set as or appended to any existing URL query for `GET`, `HEAD`, 
                         and `DELETE` requests, or set as the body for requests with any other HTTP method. The 
                         `Content-Type` HTTP header field of an encoded request with HTTP body is set to
                         `application/x-www-form-urlencoded; charset=utf-8`. Since there is no published specification
                         for how to encode collection types, the convention of appending `[]` to the key for array
                         values (`foo[]=1&foo[]=2`), and appending the key surrounded by square brackets for nested
                         dictionary values (`foo[bar]=baz`).

    - `URLEncodedInURL`: Creates query string to be set as or appended to any existing URL query. Uses the same
                         implementation as the `.URL` case, but always applies the encoded result to the URL.

    - `JSON`:            Uses `NSJSONSerialization` to create a JSON representation of the parameters object, which is 
                         set as the body of the request. The `Content-Type` HTTP header field of an encoded request is 
                         set to `application/json`.

    - `PropertyList`:    Uses `NSPropertyListSerialization` to create a plist representation of the parameters object,
                         according to the associated format and write options values, which is set as the body of the
                         request. The `Content-Type` HTTP header field of an encoded request is set to
                         `application/x-plist`.

    - `Custom`:          Uses the associated closure value to construct a new request given an existing request and
                         parameters.
*/
public enum ParameterEncoding {
    case URL
    case URLEncodedInURL
    case JSON
    case PropertyList(NSPropertyListFormat, NSPropertyListWriteOptions)
    case Custom((URLRequestConvertible, [String: AnyObject]?) -> (NSMutableURLRequest, NSError?))

    /**
        Creates a URL request by encoding parameters and applying them onto an existing request.

        - parameter URLRequest: The request to have parameters applied.
        - parameter parameters: The parameters to apply.

        - returns: A tuple containing the constructed request and the error that occurred during parameter encoding, 
                   if any.
    */
    public func encode(
        URLRequest: URLRequestConvertible,
        parameters: [String: AnyObject]?)
        -> (NSMutableURLRequest, NSError?)
    {
        var mutableURLRequest = URLRequest.URLRequest

        guard let parameters = parameters else { return (mutableURLRequest, nil) }

        var encodingError: NSError? = nil

        switch self {
        case .URL, .URLEncodedInURL:
            func query(parameters: [String: AnyObject]) -> String {
                var components: [(String, String)] = []

                for key in parameters.keys.sort(<) {
                    let value = parameters[key]!
                    components += queryComponents(key, value)
                }

                return (components.map { "\($0)=\($1)" } as [String]).joinWithSeparator("&")
            }

            func encodesParametersInURL(method: Method) -> Bool {
                switch self {
                case .URLEncodedInURL:
                    return true
                default:
                    break
                }

                switch method {
                case .GET, .HEAD, .DELETE:
                    return true
                default:
                    return false
                }
            }

            if let method = Method(rawValue: mutableURLRequest.HTTPMethod) where encodesParametersInURL(method) {
                if let
                    URLComponents = NSURLComponents(URL: mutableURLRequest.URL!, resolvingAgainstBaseURL: false)
                    where !parameters.isEmpty
                {
                    let percentEncodedQuery = (URLComponents.percentEncodedQuery.map { $0 + "&" } ?? "") + query(parameters)
                    URLComponents.percentEncodedQuery = percentEncodedQuery
                    mutableURLRequest.URL = URLComponents.URL
                }
            } else {
                if mutableURLRequest.valueForHTTPHeaderField("Content-Type") == nil {
                    mutableURLRequest.setValue(
                        "application/x-www-form-urlencoded; charset=utf-8",
                        forHTTPHeaderField: "Content-Type"
                    )
                }

                mutableURLRequest.HTTPBody = query(parameters).dataUsingEncoding(
                    NSUTF8StringEncoding,
                    allowLossyConversion: false
                )
            }
        case .JSON:
            do {
                let options = NSJSONWritingOptions()
                let data = try NSJSONSerialization.dataWithJSONObject(parameters, options: options)

                if mutableURLRequest.valueForHTTPHeaderField("Content-Type") == nil {
                    mutableURLRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                }

                mutableURLRequest.HTTPBody = data
            } catch {
                encodingError = error as NSError
            }
        case .PropertyList(let format, let options):
            do {
                let data = try NSPropertyListSerialization.dataWithPropertyList(
                    parameters,
                    format: format,
                    options: options
                )

                if mutableURLRequest.valueForHTTPHeaderField("Content-Type") == nil {
                    mutableURLRequest.setValue("application/x-plist", forHTTPHeaderField: "Content-Type")
                }

                mutableURLRequest.HTTPBody = data
            } catch {
                encodingError = error as NSError
            }
        case .Custom(let closure):
            (mutableURLRequest, encodingError) = closure(mutableURLRequest, parameters)
        }

        return (mutableURLRequest, encodingError)
    }

    /**
        Creates percent-escaped, URL encoded query string components from the given key-value pair using recursion.

        - parameter key:   The key of the query component.
        - parameter value: The value of the query component.

        - returns: The percent-escaped, URL encoded query string components.
    */
    public func queryComponents(key: String, _ value: AnyObject) -> [(String, String)] {
        var components: [(String, String)] = []

        if let dictionary = value as? [String: AnyObject] {
            for (nestedKey, value) in dictionary {
                components += queryComponents("\(key)[\(nestedKey)]", value)
            }
        } else if let array = value as? [AnyObject] {
            for value in array {
                components += queryComponents("\(key)[]", value)
            }
        } else {
            components.append((escape(key), escape("\(value)")))
        }

        return components
    }

    /**
        Returns a percent-escaped string following RFC 3986 for a query string key or value.

        RFC 3986 states that the following characters are "reserved" characters.

        - General Delimiters: ":", "#", "[", "]", "@", "?", "/"
        - Sub-Delimiters: "!", "$", "&", "'", "(", ")", "*", "+", ",", ";", "="

        In RFC 3986 - Section 3.4, it states that the "?" and "/" characters should not be escaped to allow
        query strings to include a URL. Therefore, all "reserved" characters with the exception of "?" and "/"
        should be percent-escaped in the query string.

        - parameter string: The string to be percent-escaped.

        - returns: The percent-escaped string.
    */
    public func escape(string: String) -> String {
        let generalDelimitersToEncode = ":#[]@" // does not include "?" or "/" due to RFC 3986 - Section 3.4
        let subDelimitersToEncode = "!$&'()*+,;="

        let allowedCharacterSet = NSCharacterSet.URLQueryAllowedCharacterSet().mutableCopy() as! NSMutableCharacterSet
        allowedCharacterSet.removeCharactersInString(generalDelimitersToEncode + subDelimitersToEncode)

        var escaped = ""

        //==========================================================================================================
        //
        //  Batching is required for escaping due to an internal bug in iOS 8.1 and 8.2. Encoding more than a few
        //  hundred Chinense characters causes various malloc error crashes. To avoid this issue until iOS 8 is no
        //  longer supported, batching MUST be used for encoding. This introduces roughly a 20% overhead. For more
        //  info, please refer to:
        //
        //      - https://github.com/Alamofire/Alamofire/issues/206
        //
        //==========================================================================================================

        if #available(iOS 8.3, OSX 10.10, *) {
            escaped = string.stringByAddingPercentEncodingWithAllowedCharacters(allowedCharacterSet) ?? string
        } else {
            let batchSize = 50
            var index = string.startIndex

            while index != string.endIndex {
                let startIndex = index
                let endIndex = index.advancedBy(batchSize, limit: string.endIndex)
                let range = startIndex..<endIndex

                let substring = string.substringWithRange(range)

                escaped += substring.stringByAddingPercentEncodingWithAllowedCharacters(allowedCharacterSet) ?? substring

                index = endIndex
            }
        }

        return escaped
    }
}
