// Validation.swift
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

extension Request {

    /**
        A closure used to validate a request that takes a URL request and URL response, and returns whether the request was valid.
    */
    public typealias Validation = (NSURLRequest, NSHTTPURLResponse) -> Bool

    /**
        Validates the request, using the specified closure.

        If validation fails, subsequent calls to response handlers will have an associated error.

        :param: validation A closure to validate the request.

        :returns: The request.
    */
    public func validate(validation: Validation) -> Self {
        delegate.queue.addOperationWithBlock {
            if let response = self.response where self.delegate.error == nil && !validation(self.request, response) {
                self.delegate.error = NSError(domain: AlamofireErrorDomain, code: -1, userInfo: nil)
            }
        }

        return self
    }

    // MARK: - Status Code

    /**
        Validates that the response has a status code in the specified range.

        If validation fails, subsequent calls to response handlers will have an associated error.

        :param: range The range of acceptable status codes.

        :returns: The request.
    */
    public func validate<S: SequenceType where S.Generator.Element == Int>(statusCode acceptableStatusCode: S) -> Self {
        return validate { _, response in
            return contains(acceptableStatusCode, response.statusCode)
        }
    }

    // MARK: - Content-Type

    private struct MIMEType {
        let type: String
        let subtype: String

        init?(_ string: String) {
            let components = string.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
                                   .substringToIndex(string.rangeOfString(";")?.endIndex ?? string.endIndex)
                                   .componentsSeparatedByString("/")

            if let
                type = components.first,
                subtype = components.last
            {
                self.type = type
                self.subtype = subtype
            } else {
                return nil
            }
        }

        func matches(MIME: MIMEType) -> Bool {
            switch (type, subtype) {
            case (MIME.type, MIME.subtype), (MIME.type, "*"), ("*", MIME.subtype), ("*", "*"):
                return true
            default:
                return false
            }
        }
    }

    /**
        Validates that the response has a content type in the specified array.

        If validation fails, subsequent calls to response handlers will have an associated error.

        :param: contentType The acceptable content types, which may specify wildcard types and/or subtypes.

        :returns: The request.
    */
    public func validate<S : SequenceType where S.Generator.Element == String>(contentType acceptableContentTypes: S) -> Self {
        return validate { _, response in
            if let
                responseContentType = response.MIMEType,
                responseMIMEType = MIMEType(responseContentType)
            {
                for contentType in acceptableContentTypes {
                    if let acceptableMIMEType = MIMEType(contentType) where acceptableMIMEType.matches(responseMIMEType) {
                        return true
                    }
                }
            } else {
                for contentType in acceptableContentTypes {
                    if let MIMEType = MIMEType(contentType) where MIMEType.type == "*" && MIMEType.subtype == "*" {
                        return true
                    }
                }
            }

            return false
        }
    }

    // MARK: - Automatic

    /**
        Validates that the response has a status code in the default acceptable range of 200...299, and that the content type matches any specified in the Accept HTTP header field.

        If validation fails, subsequent calls to response handlers will have an associated error.

        :returns: The request.
    */
    public func validate() -> Self {
        let acceptableStatusCodes: Range<Int> = 200..<300
        let acceptableContentTypes: [String] = {
            if let accept = self.request.valueForHTTPHeaderField("Accept") {
                return accept.componentsSeparatedByString(",")
            }

            return ["*/*"]
        }()

        return validate(statusCode: acceptableStatusCodes).validate(contentType: acceptableContentTypes)
    }
}
