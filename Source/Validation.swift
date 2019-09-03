//
//  Validation.swift
//
//  Copyright (c) 2014 Alamofire Software Foundation (http://alamofire.org/)
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

    /// Used to represent whether validation was successful or encountered an error resulting in a failure.
    ///
    /// - success: The validation was successful.
    /// - failure: The validation failed encountering the provided error.
    public enum ValidationResult {
        case success
        case failure(Error)
    }

    fileprivate struct MIMEType {
        let type: String
        let subtype: String

        var isWildcard: Bool { return type == "*" && subtype == "*" }

        init?(_ string: String) {
            let components: [String] = {
                let stripped = string.trimmingCharacters(in: .whitespacesAndNewlines)

            #if swift(>=3.2)
                let split = stripped[..<(stripped.range(of: ";")?.lowerBound ?? stripped.endIndex)]
            #else
                let split = stripped.substring(to: stripped.range(of: ";")?.lowerBound ?? stripped.endIndex)
            #endif

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

    // MARK: Properties

    fileprivate var acceptableStatusCodes: [Int] { return Array(200..<300) }

    fileprivate var acceptableContentTypes: [String] {
        if let accept = request?.value(forHTTPHeaderField: "Accept") {
            return accept.components(separatedBy: ",")
        }

        return ["*/*"]
    }

    // MARK: Status Code

    fileprivate func validate<S: Sequence>(
        statusCode acceptableStatusCodes: S,
        response: HTTPURLResponse)
        -> ValidationResult
        where S.Iterator.Element == Int
    {
        if acceptableStatusCodes.contains(response.statusCode) {
            return .success
        } else {
            let reason: ErrorReason = .unacceptableStatusCode(code: response.statusCode)
            return .failure(AFError.responseValidationFailed(reason: reason))
        }
    }

    // MARK: Content Type

    fileprivate func validate<S: Sequence>(
        contentType acceptableContentTypes: S,
        response: HTTPURLResponse,
        data: Data?)
        -> ValidationResult
        where S.Iterator.Element == String
    {
        guard let data = data, data.count > 0 else { return .success }

        guard
            let responseContentType = response.mimeType,
            let responseMIMEType = MIMEType(responseContentType)
        else {
            for contentType in acceptableContentTypes {
                if let mimeType = MIMEType(contentType), mimeType.isWildcard {
                    return .success
                }
            }

            let error: AFError = {
                let reason: ErrorReason = .missingContentType(acceptableContentTypes: Array(acceptableContentTypes))
                return AFError.responseValidationFailed(reason: reason)
            }()

            return .failure(error)
        }

        for contentType in acceptableContentTypes {
            if let acceptableMIMEType = MIMEType(contentType), acceptableMIMEType.matches(responseMIMEType) {
                return .success
            }
        }

        let error: AFError = {
            let reason: ErrorReason = .unacceptableContentType(
                acceptableContentTypes: Array(acceptableContentTypes),
                responseContentType: responseContentType
            )

            return AFError.responseValidationFailed(reason: reason)
        }()

        return .failure(error)
    }
}

// MARK: -

extension DataRequest {
    /// A closure used to validate a request that takes a URL request, a URL response and data, and returns whether the
    /// request was valid.
    public typealias Validation = (URLRequest?, HTTPURLResponse, Data?) -> ValidationResult

    /// Validates the request, using the specified closure.
    ///
    /// If validation fails, subsequent calls to response handlers will have an associated error.
    ///
    /// - parameter validation: A closure to validate the request.
    ///
    /// - returns: The request.
    @discardableResult
    public func validate(_ validation: @escaping Validation) -> Self {
        let validationExecution: () -> Void = { [unowned self] in
            if
                let response = self.response,
                self.delegate.error == nil,
                case let .failure(error) = validation(self.request, response, self.delegate.data)
            {
                self.delegate.error = error
            }
        }

        validations.append(validationExecution)

        return self
    }

    /// Validates that the response has a status code in the specified sequence.
    ///
    /// If validation fails, subsequent calls to response handlers will have an associated error.
    ///
    /// - parameter range: The range of acceptable status codes.
    ///
    /// - returns: The request.
    @discardableResult
    public func validate<S: Sequence>(statusCode acceptableStatusCodes: S) -> Self where S.Iterator.Element == Int {
        return validate { [unowned self] _, response, _ in
            return self.validate(statusCode: acceptableStatusCodes, response: response)
        }
    }

    /// Validates that the response has a content type in the specified sequence.
    ///
    /// If validation fails, subsequent calls to response handlers will have an associated error.
    ///
    /// - parameter contentType: The acceptable content types, which may specify wildcard types and/or subtypes.
    ///
    /// - returns: The request.
    @discardableResult
    public func validate<S: Sequence>(contentType acceptableContentTypes: S) -> Self where S.Iterator.Element == String {
        return validate { [unowned self] _, response, data in
            return self.validate(contentType: acceptableContentTypes, response: response, data: data)
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
        let contentTypes = { [unowned self] in
            self.acceptableContentTypes
        }
        return validate(statusCode: acceptableStatusCodes).validate(contentType: contentTypes())
    }
}

// MARK: -

extension DownloadRequest {
    /// A closure used to validate a request that takes a URL request, a URL response, a temporary URL and a
    /// destination URL, and returns whether the request was valid.
    public typealias Validation = (
        _ request: URLRequest?,
        _ response: HTTPURLResponse,
        _ temporaryURL: URL?,
        _ destinationURL: URL?)
        -> ValidationResult

    /// Validates the request, using the specified closure.
    ///
    /// If validation fails, subsequent calls to response handlers will have an associated error.
    ///
    /// - parameter validation: A closure to validate the request.
    ///
    /// - returns: The request.
    @discardableResult
    public func validate(_ validation: @escaping Validation) -> Self {
        let validationExecution: () -> Void = { [unowned self] in
            let request = self.request
            let temporaryURL = self.downloadDelegate.temporaryURL
            let destinationURL = self.downloadDelegate.destinationURL

            if
                let response = self.response,
                self.delegate.error == nil,
                case let .failure(error) = validation(request, response, temporaryURL, destinationURL)
            {
                self.delegate.error = error
            }
        }

        validations.append(validationExecution)

        return self
    }

    /// Validates that the response has a status code in the specified sequence.
    ///
    /// If validation fails, subsequent calls to response handlers will have an associated error.
    ///
    /// - parameter range: The range of acceptable status codes.
    ///
    /// - returns: The request.
    @discardableResult
    public func validate<S: Sequence>(statusCode acceptableStatusCodes: S) -> Self where S.Iterator.Element == Int {
        return validate { [unowned self] _, response, _, _ in
            return self.validate(statusCode: acceptableStatusCodes, response: response)
        }
    }

    /// Validates that the response has a content type in the specified sequence.
    ///
    /// If validation fails, subsequent calls to response handlers will have an associated error.
    ///
    /// - parameter contentType: The acceptable content types, which may specify wildcard types and/or subtypes.
    ///
    /// - returns: The request.
    @discardableResult
    public func validate<S: Sequence>(contentType acceptableContentTypes: S) -> Self where S.Iterator.Element == String {
        return validate { [unowned self] _, response, _, _ in
            let fileURL = self.downloadDelegate.fileURL

            guard let validFileURL = fileURL else {
                return .failure(AFError.responseValidationFailed(reason: .dataFileNil))
            }

            do {
                let data = try Data(contentsOf: validFileURL)
                return self.validate(contentType: acceptableContentTypes, response: response, data: data)
            } catch {
                return .failure(AFError.responseValidationFailed(reason: .dataFileReadFailed(at: validFileURL)))
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
        let contentTypes = { [unowned self] in
            self.acceptableContentTypes
        }
        return validate(statusCode: acceptableStatusCodes).validate(contentType: contentTypes())
    }
}
