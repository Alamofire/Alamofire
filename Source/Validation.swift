// Validation.swift
//
// Copyright (c) 2014–2016 Alamofire Software Foundation (http://alamofire.org/)
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
        Used to represent whether validation was successful or encountered an error resulting in a failure.

        - Success: The validation was successful.
        - Failure: The validation failed encountering the provided error.
    */
    public enum ValidationResult {
        case Success
        case Failure(NSError)
    }

    /**
        A closure used to validate a request that takes a URL request and URL response, and returns whether the 
        request was valid.
    */
    public typealias Validation = (NSURLRequest?, NSHTTPURLResponse) -> ValidationResult

    /**
        Validates the request, using the specified closure.

        If validation fails, subsequent calls to response handlers will have an associated error.

        - parameter validation: A closure to validate the request.

        - returns: The request.
    */
    public func validate(validation: Validation) -> Self {
        delegate.queue.addOperationWithBlock {
            if let
                response = self.response where self.delegate.error == nil,
                case let .Failure(error) = validation(self.request, response)
            {
                self.delegate.error = error
            }
        }

        return self
    }

    // MARK: - Status Code

    /**
        Validates that the response has a status code in the specified range.

        If validation fails, subsequent calls to response handlers will have an associated error.

        - parameter range: The range of acceptable status codes.

        - returns: The request.
    */
    public func validate<S: SequenceType where S.Generator.Element == Int>(statusCode acceptableStatusCode: S) -> Self {
        return validate { _, response in
            if acceptableStatusCode.contains(response.statusCode) {
                return .Success
            } else {
                let failureReason = "Response status code was unacceptable: \(response.statusCode)"

                let error = NSError(
                    domain: Error.Domain,
                    code: Error.Code.StatusCodeValidationFailed.rawValue,
                    userInfo: [
                        NSLocalizedFailureReasonErrorKey: failureReason,
                        Error.UserInfoKeys.StatusCode: response.statusCode
                    ]
                )

                return .Failure(error)
            }
        }
    }

    // MARK: - Content-Type

    private struct MIMEType {
        let type: String
        let subtype: String

        init?(_ string: String) {
            let components: [String] = {
                let stripped = string.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
                let split = stripped.substringToIndex(stripped.rangeOfString(";")?.startIndex ?? stripped.endIndex)
                return split.componentsSeparatedByString("/")
            }()

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

        - parameter contentType: The acceptable content types, which may specify wildcard types and/or subtypes.

        - returns: The request.
    */
    public func validate<S : SequenceType where S.Generator.Element == String>(contentType acceptableContentTypes: S) -> Self {
        return validate { _, response in
            guard let validData = self.delegate.data where validData.length > 0 else { return .Success }

            if let
                responseContentType = response.MIMEType,
                responseMIMEType = MIMEType(responseContentType)
            {
                for contentType in acceptableContentTypes {
                    if let acceptableMIMEType = MIMEType(contentType) where acceptableMIMEType.matches(responseMIMEType) {
                        return .Success
                    }
                }
            } else {
                for contentType in acceptableContentTypes {
                    if let MIMEType = MIMEType(contentType) where MIMEType.type == "*" && MIMEType.subtype == "*" {
                        return .Success
                    }
                }
            }

            let contentType: String
            let failureReason: String

            if let responseContentType = response.MIMEType {
                contentType = responseContentType

                failureReason = (
                    "Response content type \"\(responseContentType)\" does not match any acceptable " +
                    "content types: \(acceptableContentTypes)"
                )
            } else {
                contentType = ""
                failureReason = "Response content type was missing and acceptable content type does not match \"*/*\""
            }

            let error = NSError(
                domain: Error.Domain,
                code: Error.Code.ContentTypeValidationFailed.rawValue,
                userInfo: [
                    NSLocalizedFailureReasonErrorKey: failureReason,
                    Error.UserInfoKeys.ContentType: contentType
                ]
            )

            return .Failure(error)
        }
    }

    // MARK: - Automatic

    /**
        Validates that the response has a status code in the default acceptable range of 200...299, and that the content 
        type matches any specified in the Accept HTTP header field.

        If validation fails, subsequent calls to response handlers will have an associated error.

        - returns: The request.
    */
    public func validate() -> Self {
        let acceptableStatusCodes: Range<Int> = 200..<300
        let acceptableContentTypes: [String] = {
            if let accept = request?.valueForHTTPHeaderField("Accept") {
                return accept.componentsSeparatedByString(",")
            }

            return ["*/*"]
        }()

        return validate(statusCode: acceptableStatusCodes).validate(contentType: acceptableContentTypes)
    }
}
