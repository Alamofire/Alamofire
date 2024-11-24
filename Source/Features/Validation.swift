//
//  Validation.swift
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

extension Request {
    // MARK: Helper Types

    fileprivate typealias ErrorReason = AFError.ResponseValidationFailureReason

    /// Used to represent whether a validation succeeded or failed.
    public typealias ValidationResult = Result<Void, any(Error & Sendable)>

    fileprivate struct MIMEType {
        let type: String
        let subtype: String

        var isWildcard: Bool { type == "*" && subtype == "*" }

        init?(_ string: String) {
            let components: [String] = {
                let stripped = string.trimmingCharacters(in: .whitespacesAndNewlines)
                let split = stripped[..<(stripped.range(of: ";")?.lowerBound ?? stripped.endIndex)]

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
                true
            default:
                false
            }
        }
    }

    // MARK: Properties

    fileprivate var acceptableStatusCodes: Range<Int> { 200..<300 }

    fileprivate var acceptableContentTypes: [String] {
        if let accept = request?.value(forHTTPHeaderField: "Accept") {
            return accept.components(separatedBy: ",")
        }

        return ["*/*"]
    }

    // MARK: Status Code

    fileprivate func validate<S: Sequence>(statusCode acceptableStatusCodes: S,
                                           response: HTTPURLResponse)
        -> ValidationResult
        where S.Iterator.Element == Int {
        if acceptableStatusCodes.contains(response.statusCode) {
            return .success(())
        } else {
            let reason: ErrorReason = .unacceptableStatusCode(code: response.statusCode)
            return .failure(AFError.responseValidationFailed(reason: reason))
        }
    }

    // MARK: Content Type

    fileprivate func validate<S: Sequence>(contentType acceptableContentTypes: S,
                                           response: HTTPURLResponse,
                                           isEmpty: Bool)
        -> ValidationResult
        where S.Iterator.Element == String {
        guard !isEmpty else { return .success(()) }

        return validate(contentType: acceptableContentTypes, response: response)
    }

    fileprivate func validate<S: Sequence>(contentType acceptableContentTypes: S,
                                           response: HTTPURLResponse)
        -> ValidationResult
        where S.Iterator.Element == String {
        guard
            let responseContentType = response.mimeType,
            let responseMIMEType = MIMEType(responseContentType)
        else {
            for contentType in acceptableContentTypes {
                if let mimeType = MIMEType(contentType), mimeType.isWildcard {
                    return .success(())
                }
            }

            let error: AFError = {
                let reason: ErrorReason = .missingContentType(acceptableContentTypes: acceptableContentTypes.sorted())
                return AFError.responseValidationFailed(reason: reason)
            }()

            return .failure(error)
        }

        for contentType in acceptableContentTypes {
            if let acceptableMIMEType = MIMEType(contentType), acceptableMIMEType.matches(responseMIMEType) {
                return .success(())
            }
        }

        let error: AFError = {
            let reason: ErrorReason = .unacceptableContentType(acceptableContentTypes: acceptableContentTypes.sorted(),
                                                               responseContentType: responseContentType)

            return AFError.responseValidationFailed(reason: reason)
        }()

        return .failure(error)
    }
}

// MARK: -

extension DataRequest {
    /// A closure used to validate a request that takes a URL request, a URL response and data, and returns whether the
    /// request was valid.
    public typealias Validation = @Sendable (URLRequest?, HTTPURLResponse, Data?) -> ValidationResult

    /// Validates that the response has a status code in the specified sequence.
    ///
    /// If validation fails, subsequent calls to response handlers will have an associated error.
    ///
    /// - Parameter acceptableStatusCodes: `Sequence` of acceptable response status codes.
    ///
    /// - Returns:                         The instance.
    @preconcurrency
    @discardableResult
    public func validate<S: Sequence>(statusCode acceptableStatusCodes: S) -> Self where S.Iterator.Element == Int, S: Sendable {
        validate { [unowned self] _, response, _ in
            self.validate(statusCode: acceptableStatusCodes, response: response)
        }
    }

    /// Validates that the response has a content type in the specified sequence.
    ///
    /// If validation fails, subsequent calls to response handlers will have an associated error.
    ///
    /// - parameter contentType: The acceptable content types, which may specify wildcard types and/or subtypes.
    ///
    /// - returns: The request.
    @preconcurrency
    @discardableResult
    public func validate<S: Sequence>(contentType acceptableContentTypes: @escaping @Sendable @autoclosure () -> S) -> Self where S.Iterator.Element == String, S: Sendable {
        validate { [unowned self] _, response, data in
            self.validate(contentType: acceptableContentTypes(), response: response, isEmpty: (data == nil || data?.isEmpty == true))
        }
    }

    /// Validates that the response has a status code in the default acceptable range of 200...299, and that the content
    /// type matches any specified in the Accept HTTP header field.
    ///
    /// If validation fails, subsequent calls to response handlers will have an associated error.
    ///
    /// - returns: The request.
    @discardableResult
    public func validate() -> Self {
        let contentTypes: @Sendable () -> [String] = { [unowned self] in
            acceptableContentTypes
        }
        return validate(statusCode: acceptableStatusCodes).validate(contentType: contentTypes())
    }
}

extension DataStreamRequest {
    /// A closure used to validate a request that takes a `URLRequest` and `HTTPURLResponse` and returns whether the
    /// request was valid.
    public typealias Validation = @Sendable (_ request: URLRequest?, _ response: HTTPURLResponse) -> ValidationResult

    /// Validates that the response has a status code in the specified sequence.
    ///
    /// If validation fails, subsequent calls to response handlers will have an associated error.
    ///
    /// - Parameter acceptableStatusCodes: `Sequence` of acceptable response status codes.
    ///
    /// - Returns:                         The instance.
    @preconcurrency
    @discardableResult
    public func validate<S: Sequence>(statusCode acceptableStatusCodes: S) -> Self where S.Iterator.Element == Int, S: Sendable {
        validate { [unowned self] _, response in
            self.validate(statusCode: acceptableStatusCodes, response: response)
        }
    }

    /// Validates that the response has a content type in the specified sequence.
    ///
    /// If validation fails, subsequent calls to response handlers will have an associated error.
    ///
    /// - parameter contentType: The acceptable content types, which may specify wildcard types and/or subtypes.
    ///
    /// - returns: The request.
    @preconcurrency
    @discardableResult
    public func validate<S: Sequence>(contentType acceptableContentTypes: @escaping @Sendable @autoclosure () -> S) -> Self where S.Iterator.Element == String, S: Sendable {
        validate { [unowned self] _, response in
            self.validate(contentType: acceptableContentTypes(), response: response)
        }
    }

    /// Validates that the response has a status code in the default acceptable range of 200...299, and that the content
    /// type matches any specified in the Accept HTTP header field.
    ///
    /// If validation fails, subsequent calls to response handlers will have an associated error.
    ///
    /// - Returns: The instance.
    @discardableResult
    public func validate() -> Self {
        let contentTypes: @Sendable () -> [String] = { [unowned self] in
            acceptableContentTypes
        }
        return validate(statusCode: acceptableStatusCodes).validate(contentType: contentTypes())
    }
}

// MARK: -

extension DownloadRequest {
    /// A closure used to validate a request that takes a URL request, a URL response, a temporary URL and a
    /// destination URL, and returns whether the request was valid.
    public typealias Validation = @Sendable (_ request: URLRequest?,
                                             _ response: HTTPURLResponse,
                                             _ fileURL: URL?)
        -> ValidationResult

    /// Validates that the response has a status code in the specified sequence.
    ///
    /// If validation fails, subsequent calls to response handlers will have an associated error.
    ///
    /// - Parameter acceptableStatusCodes: `Sequence` of acceptable response status codes.
    ///
    /// - Returns:                         The instance.
    @preconcurrency
    @discardableResult
    public func validate<S: Sequence>(statusCode acceptableStatusCodes: S) -> Self where S.Iterator.Element == Int, S: Sendable {
        validate { [unowned self] _, response, _ in
            self.validate(statusCode: acceptableStatusCodes, response: response)
        }
    }

    /// Validates that the response has a `Content-Type` in the specified sequence.
    ///
    /// If validation fails, subsequent calls to response handlers will have an associated error.
    ///
    /// - parameter contentType: The acceptable content types, which may specify wildcard types and/or subtypes.
    ///
    /// - returns: The request.
    @preconcurrency
    @discardableResult
    public func validate<S: Sequence>(contentType acceptableContentTypes: @escaping @Sendable @autoclosure () -> S) -> Self where S.Iterator.Element == String, S: Sendable {
        validate { [unowned self] _, response, fileURL in
            guard let fileURL else {
                return .failure(AFError.responseValidationFailed(reason: .dataFileNil))
            }

            do {
                let isEmpty = try (fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) == 0
                return self.validate(contentType: acceptableContentTypes(), response: response, isEmpty: isEmpty)
            } catch {
                return .failure(AFError.responseValidationFailed(reason: .dataFileReadFailed(at: fileURL)))
            }
        }
    }

    /// Validates that the response has a status code in the default acceptable range of 200...299, and that the content
    /// type matches any specified in the Accept HTTP header field.
    ///
    /// If validation fails, subsequent calls to response handlers will have an associated error.
    ///
    /// - returns: The request.
    @discardableResult
    public func validate() -> Self {
        let contentTypes: @Sendable () -> [String] = { [unowned self] in
            acceptableContentTypes
        }
        return validate(statusCode: acceptableStatusCodes).validate(contentType: contentTypes())
    }
}
