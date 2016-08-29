//
//  AFError.swift
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

/// `AFError` is the error type returned by the Alamofire framework. It encompasses a few
/// different types of errors, each with their own associated reasons.
///
/// - `.multipartEncodingFailed` errors are returned when some step in the multipart encoding process fails.
///
/// - `.responseValidationFailed` errors are returned when a `validate()` call fails.
///
/// - `.responseSerializationFailed` errors are returned when a response serializer encounters an error in the
///     serialization process.
public enum AFError: Error {
    /// The reason underlying the `AFError.multipartEncodingFailed` state.
    ///
    /// - `.bodyPartURLInvalid`:                    The `fileURL` provided for reading an encodable body part isn't a
    ///                                             file URL.
    /// - `.bodyPartFilenameInvalid`:               The filename of the `fileURL` provided has either an empty
    ///                                             `lastPathComponent` or `pathExtension.
    /// - `.bodyPartFileNotReachable`:              The file at the `fileURL` provided was not reachable.
    /// - `.bodyPartFileNotReachableWithError`:     Attempting to check the reachability of the `fileURL` provided threw
    ///                                             an error.
    /// - `.bodyPartFileIsDirectory`:               The file at the `fileURL` provided is actually a directory.
    /// - `.bodyPartFileSizeNotAvailable`:          The size of the file at the `fileURL` provided was not returned by
    ///                                             the system.
    /// - `.bodyPartFileSizeQueryFailedWithError`:  The attempt to find the size of the file at the `fileURL` provided
    ///                                             threw an error.
    /// - `.bodyPartInputStreamCreationFailed`:     An `InputStream` could not be created for the provided `fileURL`.
    /// - `.outputStreamCreationFailed`:            An `OutputStream` could not be created when attempting to write the
    ///                                             encoded data to disk.
    /// - `.outputStreamFileAlreadyExists`:         The encoded body data could not be writtent disk because a file already
    ///                                             exists at the provided `fileURL`.
    /// - `.outputStreamURLInvalid`:                The `fileURL` provided for writing the encoded body data to disk is
    ///                                             not a file URL.
    /// - `.outputStreamWriteFailed`:               The attempt to write the encoded body data to disk failed with an
    ///                                             underlying error.
    /// - `.inputStreamReadFailed`:                 The attempt to read an encoded body part `InputStream` failed with
    ///                                             underlying system error.
    public enum MultipartEncodingFailureReason {
        case bodyPartURLInvalid(url: URL)
        case bodyPartFilenameInvalid(in: URL)
        case bodyPartFileNotReachable(at: URL)
        case bodyPartFileNotReachableWithError(atURL: URL, error: Error)
        case bodyPartFileIsDirectory(at: URL)
        case bodyPartFileSizeNotAvailable(at: URL)
        case bodyPartFileSizeQueryFailedWithError(forURL: URL, error: Error)
        case bodyPartInputStreamCreationFailed(for: URL)

        case outputStreamCreationFailed(for: URL)
        case outputStreamFileAlreadyExists(at: URL)
        case outputStreamURLInvalid(url: URL)
        case outputStreamWriteFailed(error: Error)

        case inputStreamReadFailed(error: Error)
    }

    /// The reason underlying the `AFError.responseValidationFailed` state.
    ///
    /// - `.missingContentType`:        The response did not contain a `Content-Type` and the `acceptableContentTypes`
    ///                                 provided did not contain wildcard type.
    /// - `unacceptableContentType`:    The response `Content-Type` did not match any type in the provided
    ///    .                            `acceptableContentTypes`.
    /// - `.unacceptableStatusCode`:    The response status code was not acceptable.
    public enum ValidationFailureReason {
        case missingContentType(acceptableContentTypes: [String])
        case unacceptableContentType(acceptableContentTypes: [String], responseContentType: String)
        case unacceptableStatusCode(code: Int)
    }

    /// The reason underlying the `AFError.responseSerializationFailed` state.
    ///
    /// - `.inputDataNil`:                      The response contained no data.
    /// - `.inputDataNilOrZeroLength`:          The response contained no data or the data was zero length.
    /// - `.stringSerializationFailed`:         String serialization failed using the provided `String.Encoding`.
    /// - `.jsonSerializationFailed`:           JSON serialization failed with an underlying system error.
    /// - `.propertyListSerializationFailed`:   Proptery list serialization failed with an underlying system error.
    public enum SerializationFailureReason {
        case inputDataNil
        case inputDataNilOrZeroLength
        case stringSerializationFailed(encoding: String.Encoding)
        case jsonSerializationFailed(error: Error)
        case propertyListSerializationFailed(error: Error)
    }

    case multipartEncodingFailed(reason: MultipartEncodingFailureReason)
    case responseValidationFailed(reason: ValidationFailureReason)
    case responseSerializationFailed(reason: SerializationFailureReason)
}

// MARK: - Error Booleans

public extension AFError {
    /// Returns whether the AFError is a multipart encoding error. When true, the `url` and `underlyingError` properties
    /// will contain the associated values.
    public var isMultipartEncodingError: Bool {
        if case .multipartEncodingFailed = self { return true }
        return false
    }

    /// Returns whether the `AFError` is a response validation error. When true, the `acceptableContentTypes`,
    /// `responseContentType`, and `responseCode` properties will contain the associated values.
    public var isResponseValidationError: Bool {
        if case .responseValidationFailed = self { return true }
        return false
    }

    /// Returns whether the `AFError` is a response serialization error. When true, the `failedStringEncoding` and
    /// `underlyingError` properties will contain the associated values.
    public var isResponseSerializationError: Bool {
        if case .responseSerializationFailed = self { return true }
        return false
    }
}

// MARK: - Convenience Properties

public extension AFError {
    /// The `URL` associated with the error.
    public var url: URL? {
        switch self {
        case .multipartEncodingFailed(let reason):
            return reason.url
        default:
            return nil
        }
    }

    /// The `Error` returned by a system framework associated with a `.multipartEncodingFailed` or
    /// `.responseSerializationFailed` error.
    public var underlyingError: Error? {
        switch self {
        case .multipartEncodingFailed(let reason):
            return reason.underlyingError
        case .responseSerializationFailed(let reason):
            return reason.underlyingError
        default:
            return nil
        }
    }

    /// The acceptable `Content-Type`s of a `.responseValidationFailed` error.
    public var acceptableContentTypes: [String]? {
        switch self {
        case .responseValidationFailed(let reason):
            return reason.acceptableContentTypes
        default:
            return nil
        }
    }

    /// The response `Content-Type` of a `.responseValidationFailed` error.
    public var responseContentType: String? {
        switch self {
        case .responseValidationFailed(let reason):
            return reason.responseContentType
        default:
            return nil
        }
    }

    /// The response code of a `.responseValidationFailed` error.
    public var responseCode: Int? {
        switch self {
        case .responseValidationFailed(let reason):
            return reason.responseCode
        default:
            return nil
        }
    }

    /// The `String.Encoding` associated with a failed `.stringResponse()` call.
    public var failedStringEncoding: String.Encoding? {
        switch self {
        case .responseSerializationFailed(let reason):
            return reason.failedStringEncoding
        default:
            return nil
        }
    }
}

extension AFError.MultipartEncodingFailureReason {
    var url: URL? {
        switch self {
        case .bodyPartURLInvalid(let url), .bodyPartFilenameInvalid(let url), .bodyPartFileNotReachable(let url),
             .bodyPartFileIsDirectory(let url), .bodyPartFileSizeNotAvailable(let url), .bodyPartInputStreamCreationFailed(let url),
             .outputStreamCreationFailed(let url), .outputStreamFileAlreadyExists(let url), .outputStreamURLInvalid(let url),
             .bodyPartFileNotReachableWithError(let url, _), .bodyPartFileSizeQueryFailedWithError(let url, _):
            return url
        default:
            return nil
        }
    }

    var underlyingError: Error? {
        switch self {
        case .bodyPartFileNotReachableWithError(_, let error), .bodyPartFileSizeQueryFailedWithError(_, let error),
             .outputStreamWriteFailed(let error), .inputStreamReadFailed(let error):
            return error
        default:
            return nil
        }
    }
}

extension AFError.ValidationFailureReason {
    var acceptableContentTypes: [String]? {
        switch self {
        case .missingContentType(let types), .unacceptableContentType(let types, _):
            return types
        default:
            return nil
        }
    }

    var responseContentType: String? {
        switch self {
        case .unacceptableContentType(_, let reponseType):
            return reponseType
        default:
            return nil
        }
    }

    var responseCode: Int? {
        switch self {
        case .unacceptableStatusCode(let code):
            return code
        default:
            return nil
        }
    }
}

extension AFError.SerializationFailureReason {
    var failedStringEncoding: String.Encoding? {
        switch self {
        case .stringSerializationFailed(let encoding):
            return encoding
        default:
            return nil
        }
    }

    var underlyingError: Error? {
        switch self {
        case .jsonSerializationFailed(let error), .propertyListSerializationFailed(let error):
            return error
        default:
            return nil
        }
    }
}

// MARK: - Error Descriptions

extension AFError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .multipartEncodingFailed(let reason):
            return reason.localizedDescription
        case .responseValidationFailed(let reason):
            return reason.localizedDescription
        case .responseSerializationFailed(let reason):
            return reason.localizedDescription
        }
    }
}

extension AFError.SerializationFailureReason {
    var localizedDescription: String {
        switch self {
        case .inputDataNil:
            return "Response could not be serialized, input data was nil."
        case .inputDataNilOrZeroLength:
            return "Response could not be serialized, input data was nil or zero length."
        case .stringSerializationFailed(let encoding):
            return "String could not be serialized with encoding: \(encoding)."
        case .jsonSerializationFailed(let error):
            return "JSON could not be serialized because of error:\n\(error.localizedDescription)"
        case .propertyListSerializationFailed(let error):
            return "PropertyList could not be serialized because of error:\n\(error.localizedDescription)"
        }
    }
}

extension AFError.ValidationFailureReason {
    var localizedDescription: String {
        switch self {
        case .missingContentType(let types):
            return "Response Content-Type was missing and acceptable content types (\(types.joined(separator: ","))) do not match \"*/*\"."
        case .unacceptableContentType(let acceptableTypes, let responseType):
            return "Response Content-Type \"\(responseType)\" does not match any acceptable types: \(acceptableTypes.joined(separator: ","))."
        case .unacceptableStatusCode(let code):
            return "Response status code was unacceptable: \(code)."
        }
    }
}

extension AFError.MultipartEncodingFailureReason {
    var localizedDescription: String {
        switch self {
        case .bodyPartURLInvalid(let url):
            return "The URL provided is not a file URL: \(url)"
        case .bodyPartFilenameInvalid(let url):
            return "The URL provided does not have a valid filename: \(url)"
        case .bodyPartFileNotReachable(let url):
            return "The URL provided is not reachable: \(url)"
        case .bodyPartFileNotReachableWithError(let url, let error):
            return "The system returned an error while checking the provided URL for reachability.\nURL: \(url)\nError: \(error)"
        case .bodyPartFileIsDirectory(let url):
            return "The URL provided is a directory: \(url)"
        case .bodyPartFileSizeNotAvailable(let url):
            return "Could not fetch the file size from the provided URL: \(url)"
        case .bodyPartFileSizeQueryFailedWithError(let url, let error):
            return "The system returned an error while attempting to fetch the file size from the provided URL.\nURL: \(url)\nError: \(error)"
        case .bodyPartInputStreamCreationFailed(let url):
            return "Failed to create an InputStream for the provided URL: \(url)"
        case .outputStreamCreationFailed(let url):
            return "Failed to create an OutputStream for URL: \(url)"
        case .outputStreamFileAlreadyExists(let url):
            return "A file already exists at the provided URL: \(url)"
        case .outputStreamURLInvalid(let url):
            return "The provided OutputStream URL is invalid: \(url)"
        case .outputStreamWriteFailed(let error):
            return "OutputStream write failed with error: \(error)"
        case .inputStreamReadFailed(let error):
            return "InputStream read failed with error: \(error)"
        }
    }
}
