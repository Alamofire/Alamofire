//
//  Error.swift
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

/// `AFError` is the error type returned by the Alamofire framework. It encompasses several
/// different types of errors, each with their own associated reasons.
///
/// - multipartEncodingFailed:          Returned by the multipart body data APIs. Contains a `MultipartEncodingFailureReason`.
/// - inputStreamReadFailed:            <#inputStreamReadFailed description#>
/// - outputStreamWriteFailed:          <#outputStreamWriteFailed description#>
/// - responseValidationFailed:         <#responseValidationFailed description#>
/// - responseSerializationFailed:      <#responseSerializationFailed description#>
public enum AFError: Error {
    
    public enum MultipartEncodingFailureReason {
        case notAFile(at: URL)
        case failedToExtractFilename(for: URL)
        case fileNotReachable(at: URL)
        case isDirectory(at: URL)
        case failedToFetchAttributes(from: URL)
        case failedToCreateInputStream(from: URL)
    }
    
    /// `OutputStreamFailureReason` is the reason returned for an `AFError.multipartEncodingFailed` error.
    ///
    /// - writeFailed:          <#writeFailed description#>
    /// - failedToCreateStream: <#failedToCreateStream description#>
    /// - fileAlreadyExists:    <#fileAlreadyExists description#>
    /// - invalidFile:          <#invalidFile description#>
    public enum OutputStreamFailureReason {
        case writeFailed(to: OutputStream)
        case failedToCreateStream(at: URL)
        case fileAlreadyExists(at: URL)
        case invalidFile(at: URL)
    }
    
    public enum SerializationFailureReason {
        case inputDataNil
        case inputDataNilOrZeroLength
        case invalidStringEncoding(String.Encoding)
    }
    
    public enum ValidationFailureReason {
        case contentTypeMismatch(acceptable: [String], actual: String)
        case contentTypeMissingAndNotWildcard
        case unacceptableStatusCode(code: Int)
    }
    
    case multipartEncodingFailed(reason: MultipartEncodingFailureReason)
    case inputStreamReadFailed(inputStream: InputStream)
    case outputStreamWriteFailed(reason: OutputStreamFailureReason)
    case responseValidationFailed(reason: ValidationFailureReason)
    case responseSerializationFailed(reason: SerializationFailureReason)
}

// MARK: Error Booleans

public extension AFError {
    
    // MARK: Multipart Encoding
    
    /// Returns whether or not the AFError is a multipart encoding error. When this property is true,
    /// the `url` property will contain the associated `URL`.
    var isMultipartEncodingError: Bool {
        if case .multipartEncodingFailed = self { return true }
        return false
    }
    
    var isMultipartNotAFileError: Bool {
        guard case let .multipartEncodingFailed(reason) = self else { return false }
        return reason.isNotAFile
    }
    
    var isMultipartFailedToExtractFilenameError: Bool {
        guard case let .multipartEncodingFailed(reason) = self else { return false }
        return reason.isFailedToExtractFilename
    }
    
    var isMultipartFileNotReachableError: Bool {
        guard case let .multipartEncodingFailed(reason) = self else { return false }
        return reason.isFileNotReachable
    }
    
    var isMultipartIsADirectoryError: Bool {
        guard case let .multipartEncodingFailed(reason) = self else { return false }
        return reason.isADirectory
    }
    
    var isMultipartFailedToFetchAttributesError: Bool {
        guard case let .multipartEncodingFailed(reason) = self else { return false }
        return reason.isFailedToFetchAttributes
    }
    
    var isMultipartFailedToCreateInputStreamError: Bool {
        guard case let .multipartEncodingFailed(reason) = self else { return false }
        return reason.isFailedToCreateInputStream
    }
    
    // MARK: InputStream
    
    /// Returns whether or not the `AFError` is a `.inputStreamReadFailed` error. When this property is true the `inputStream` property will contain the associated `InputStream`.
    var isInputStreamReadError: Bool {
        if case .inputStreamReadFailed = self { return true }
        return false
    }
    
    // MARK: OutputStream
    
    var isOutputStreamWriteError: Bool {
        if case .outputStreamWriteFailed = self { return true }
        return false
    }
    
    var isOutputStreamWriteFailedError: Bool {
        guard case let .outputStreamWriteFailed(reason) = self else { return false }
        return reason.isWriteFailed
    }
    
    var isOutputStreamFailedToCreateStream: Bool {
        guard case let .outputStreamWriteFailed(reason) = self else { return false }
        return reason.isFailedToCreateStream
    }
    
    var isOutputStreamFileAlreadyExists: Bool {
        guard case let .outputStreamWriteFailed(reason) = self else { return false }
        return reason.isFileAlreadyExists
    }
    
    var isOutputStreamInvalidFile: Bool {
        guard case let .outputStreamWriteFailed(reason) = self else { return false }
        return reason.isInvalidFile
    }
    
    // MARK: Response Validation
    
    var isResponseValidationError: Bool {
        if case .responseValidationFailed = self { return true }
        return false
    }
    
    var isResponseValidationContentTypeMismatchError: Bool {
        guard case let .responseValidationFailed(reason) = self else { return false }
        return reason.isContentTypeMismatch
    }
    
    var isResponseValidationContentTypeMissingAndNotWildCardError: Bool {
        guard case let .responseValidationFailed(reason) = self else { return false }
        return reason.isContentTypeMissingAndNotWildcard
    }
    
    var isResponseValidationUnacceptableStatusCodeError: Bool {
        guard case let .responseValidationFailed(reason) = self else { return false }
        return reason.isUnacceptableStatusCode
    }
    
    // MARK: Response Serialization
    
    var isResponseSerializationError: Bool {
        if case .responseSerializationFailed = self { return true }
        return false
    }
    
    var isResponseSerializationInputDataNilError: Bool {
        guard case let .responseSerializationFailed(reason) = self else { return false }
        return reason.isInputDataNil
    }
    
    var isResponseSerializationInputDataNilOrZeroLengthError: Bool {
        guard case let .responseSerializationFailed(reason) = self else { return false }
        return reason.isInputDataNilOrZeroLength
    }
    
    var isResponseSerializationInvalidStringEncodingError: Bool {
        guard case let .responseSerializationFailed(reason) = self else { return false }
        return reason.isInvalidStringEncoding
    }

}

extension AFError.MultipartEncodingFailureReason {
    
    var isNotAFile: Bool {
        if case .notAFile = self { return true }
        return false
    }
    
    var isFailedToExtractFilename: Bool {
        if case .failedToExtractFilename = self { return true }
        return false
    }
    
    var isFileNotReachable: Bool {
        if case .fileNotReachable = self { return true }
        return false
    }
    
    var isADirectory: Bool {
        if case .isDirectory = self { return true }
        return false
    }
    
    var isFailedToFetchAttributes: Bool {
        if case .failedToFetchAttributes = self { return true }
        return false
    }
    
    var isFailedToCreateInputStream: Bool {
        if case .failedToCreateInputStream = self { return true }
        return false
    }
    
}

extension AFError.OutputStreamFailureReason {
    
    var isWriteFailed: Bool {
        if case .writeFailed = self { return true }
        return false
    }
    
    var isFailedToCreateStream: Bool {
        if case .failedToCreateStream = self { return true }
        return false
    }
    
    var isFileAlreadyExists: Bool {
        if case .fileAlreadyExists = self { return true }
        return false
    }
    
    var isInvalidFile: Bool {
        if case .invalidFile = self { return true }
        return false
    }
    
}

extension AFError.ValidationFailureReason {
    
    var isContentTypeMismatch: Bool {
        if case .contentTypeMismatch = self { return true }
        return false
    }
    
    var isContentTypeMissingAndNotWildcard: Bool {
        if case .contentTypeMismatch = self { return true }
        return false
    }
    
    var isUnacceptableStatusCode: Bool {
        if case .contentTypeMismatch = self { return true }
        return false
    }
    
}

extension AFError.SerializationFailureReason {
    
    var isInputDataNil: Bool {
        if case .inputDataNil = self { return true }
        return false
    }
    
    var isInputDataNilOrZeroLength: Bool {
        if case .inputDataNilOrZeroLength = self { return true }
        return false
    }
    
    var isInvalidStringEncoding: Bool {
        if case .invalidStringEncoding = self { return true }
        return false
    }
    
}


// MARK: Associated Value Properties

extension AFError {
    
    /// The `URL` associated with all `.multipartEncodingFailed` reasons and some `.outputStreamWriteFailed` reasons. `nil` otherwise.
    var url: URL? {
        switch self {
        case let .multipartEncodingFailed(reason):
            return reason.url
        case let .outputStreamWriteFailed(reason):
            return reason.url
        default:
            return nil
        }
    }
    
    /// The `InputStream` associated with the `.inputStreamReadFailed` error. `nil` otherwise.
    var inputStream: InputStream? {
        guard case let .inputStreamReadFailed(inputStream) = self else { return nil }
        
        return inputStream
    }
    
    /// The `OutputStream` associated with the `.outputStreamWriteFailed` error. `nil` otherwise.
    var outputStream: OutputStream? {
        guard case let .outputStreamWriteFailed(reason) = self else { return nil }
        
        return reason.outputStream
    }
    
    /// The acceptable content types associated with a `.responseValidationFailed` error, if it was a `Content-Type` validation that failed. `nil` otherwise.
    var acceptableContentTypes: [String]? {
        guard case let .responseValidationFailed(reason) = self else { return nil }
        
        return reason.acceptableContentTypes
    }
    
    /// The actual content type recieved from the request associated with a `.responseValidationFailed` error, if it was a `Content-Type` validation that failed. `nil` otherwise.
    var actualContentType: String? {
        guard case let .responseValidationFailed(reason) = self else { return nil }
        
        return reason.actualContentType
    }
    
    /// The status code associated with a `.responseValidationFailed` error when it was a response code validation that failed. `nil` otherwise.
    var statusCode: Int? {
        guard case let .responseValidationFailed(reason) = self else { return nil }
        
        return reason.statusCode
    }
    
    /// The `String.Encoding` associated with the `.invalidStringEncoding` reason of the `.responseValidationFailed` error. `nil` otherwise.
    var stringEncoding: String.Encoding? {
        guard case let .responseSerializationFailed(reason) = self else { return nil }
        
        return reason.stringEncoding
    }
    
}

extension AFError.MultipartEncodingFailureReason {
    
    var url: URL {
        switch self {
        case .notAFile(let url), .failedToExtractFilename(let url), .fileNotReachable(let url),
             .isDirectory(let url), .failedToFetchAttributes(let url), .failedToCreateInputStream(let url):
            return url
        }
    }
    
}

extension AFError.OutputStreamFailureReason {
    
    var url: URL? {
        switch self {
        case .failedToCreateStream(let url), .fileAlreadyExists(let url), .invalidFile(let url):
            return url
        default:
            return nil
        }
    }
    
    var outputStream: OutputStream? {
        guard case let .writeFailed(outputStream) = self else { return nil }
        
        return outputStream
    }
    
}

extension AFError.ValidationFailureReason {
    
    var acceptableContentTypes: [String]? {
        guard case let .contentTypeMismatch(acceptableContentTypes, _) = self else { return nil }
        
        return acceptableContentTypes
    }
    
    var actualContentType: String? {
        guard case let .contentTypeMismatch(_, actualContentType) = self else { return nil }
        
        return actualContentType
    }
    
    var statusCode: Int? {
        guard case let .unacceptableStatusCode(statusCode) = self else { return nil }
        
        return statusCode
    }
    
}

extension AFError.SerializationFailureReason {
    
    var stringEncoding: String.Encoding? {
        guard case let .invalidStringEncoding(encoding) = self else { return nil }
        
        return encoding
    }
    
}

// MARK: Error Descriptions

extension AFError: LocalizedError {
    
    public var errorDescription: String? {
        return "Error"
    }
    
}

//let failureReason = "String could not be serialized with encoding: \(actualEncoding)"
//let failureReason = "String could not be serialized. Input data was nil."
////                let failureReason = "Data could not be serialized. Input data was nil."
//let failureReason = "JSON could not be serialized. Input data was nil or zero length."
//let failureReason = "Property list could not be serialized. Input data was nil or zero length."
//let failureReason = "Failed to extract the fileName of the provided URL: \(fileURL)"
//let failureReason = "The file URL is a directory, not a file: \(fileURL)"
////            setBodyPartError(withCode: NSURLErrorBadURL, failureReason: "The file URL is not reachable: \(fileURL)")
//let failureReason = "The file URL does not point to a file URL: \(fileURL)"
//let failureReason = "Failed to read from input stream: \(inputStream)"
//let failureReason = "Failed to read from input stream: \(inputStream)"
//let failureReason = "Failed to write to output stream: \(outputStream)"
//let failureReason = "Could not fetch attributes from the file URL: \(fileURL)"
//let failureReason = "Failed to create an input stream from the file URL: \(fileURL)"
//                let failureReason = "Response status code was unacceptable: \(response.statusCode)"
//                failureReason = (
//                    "Response content type \"\(responseContentType)\" does not match any acceptable " +
//                    "content types: \(acceptableContentTypes)"
//                )
//failureReason = "Response content type was missing and acceptable content type does not match \"*/*\""
