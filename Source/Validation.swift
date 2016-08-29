//
//  Validation.swift
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

extension Request {
    /// Used to represent whether validation was successful or encountered an error resulting in a failure.
    ///
    /// - success: The validation was successful.
    /// - failure: The validation failed encountering the provided error.
    public enum ValidationResult {
        case success
        case failure(Error)
    }

    /// A closure used to validate a request that takes a URL request and URL response, and returns whether the
    /// request was valid.
    public typealias Validation = (URLRequest?, HTTPURLResponse) -> ValidationResult

    /// Validates the request, using the specified closure.
    ///
    /// If validation fails, subsequent calls to response handlers will have an associated error.
    ///
    /// - parameter validation: A closure to validate the request.
    ///
    /// - returns: The request.
    @discardableResult
    public func validate(_ validation: Validation) -> Self {
        delegate.queue.addOperation {
            if
                let response = self.response,
                self.delegate.error == nil,
                case let .failure(error) = validation(self.request, response)
            {
                self.delegate.error = error
            }
        }

        return self
    }

    // MARK: - Status Code

    /// Validates that the response has a status code in the specified range.
    ///
    /// If validation fails, subsequent calls to response handlers will have an associated error.
    ///
    /// - parameter range: The range of acceptable status codes.
    ///
    /// - returns: The request.
    @discardableResult
    public func validate<S: Sequence>(statusCode acceptableStatusCode: S) -> Self where S.Iterator.Element == Int {
        return validate { _, response in
            if acceptableStatusCode.contains(response.statusCode) {
                return .success
            } else {
                return .failure(AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: response.statusCode)))
            }
        }
    }

    // MARK: - Content-Type

    private struct MIMEType {
        let type: String
        let subtype: String

        init?(_ string: String) {
            let components: [String] = {
                let stripped = string.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                let split = stripped.substring(to: stripped.range(of: ";")?.lowerBound ?? stripped.endIndex)
                return split.components(separatedBy: "/")
            }()

            if let type = components.first, let subtype = components.last {
                self.type = type
                self.subtype = subtype
            } else {
                return nil
            }
        }

        func matches(_ mime: MIMEType) -> Bool {
            switch (type, subtype) {
            case (mime.type, mime.subtype), (mime.type, "*"), ("*", mime.subtype), ("*", "*"):
                return true
            default:
                return false
            }
        }
    }

    /// Validates that the response has a content type in the specified array.
    ///
    /// If validation fails, subsequent calls to response handlers will have an associated error.
    ///
    /// - parameter contentType: The acceptable content types, which may specify wildcard types and/or subtypes.
    ///
    /// - returns: The request.
    @discardableResult
    public func validate<S: Sequence>(contentType acceptableContentTypes: S) -> Self where S.Iterator.Element == String {
        return validate { _, response in
            guard let validData = self.delegate.data, validData.count > 0 else { return .success }

            guard
                let responseContentType = response.mimeType,
                let responseMIMEType = MIMEType(responseContentType) else {
                for contentType in acceptableContentTypes {
                    if let mimeType = MIMEType(contentType), mimeType.type == "*" && mimeType.subtype == "*" {
                        return .success
                    }
                }

                return .failure(AFError.responseValidationFailed(reason: .missingContentType(acceptableContentTypes: Array(acceptableContentTypes))))
            }

            for contentType in acceptableContentTypes {
                if let acceptableMIMEType = MIMEType(contentType), acceptableMIMEType.matches(responseMIMEType) {
                    return .success
                }
            }

            let error = AFError.responseValidationFailed(reason: .unacceptableContentType(acceptableContentTypes: Array(acceptableContentTypes), responseContentType: responseContentType))

            return .failure(error)
        }
    }

    // MARK: - Automatic

    /// Validates that the response has a status code in the default acceptable range of 200...299, and that the content
    /// type matches any specified in the Accept HTTP header field.
    ///
    /// If validation fails, subsequent calls to response handlers will have an associated error.
    ///
    /// - returns: The request.
    @discardableResult
    public func validate() -> Self {
        let acceptableStatusCodes: CountableRange<Int> = 200..<300
        let acceptableContentTypes: [String] = {
            if let accept = request?.value(forHTTPHeaderField: "Accept") {
                return accept.components(separatedBy: ",")
            }

            return ["*/*"]
        }()

        return validate(statusCode: acceptableStatusCodes).validate(contentType: acceptableContentTypes)
    }
}
