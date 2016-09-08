//
//  AFError+AlamofireTests.swift
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

import Alamofire

extension AFError {

    // ParameterEncodingFailureReason

    var isMissingURLFailed: Bool {
        if case let .parameterEncodingFailed(reason) = self, reason.isMissingURL { return true }
        return false
    }

    var isJSONEncodingFailed: Bool {
        if case let .parameterEncodingFailed(reason) = self, reason.isJSONEncodingFailed { return true }
        return false
    }

    var isPropertyListEncodingFailed: Bool {
        if case let .parameterEncodingFailed(reason) = self, reason.isPropertyListEncodingFailed { return true }
        return false
    }

    // MultipartEncodingFailureReason

    var isBodyPartURLInvalid: Bool {
        if case let .multipartEncodingFailed(reason) = self, reason.isBodyPartURLInvalid { return true }
        return false
    }

    var isBodyPartFilenameInvalid: Bool {
        if case let .multipartEncodingFailed(reason) = self, reason.isBodyPartFilenameInvalid { return true }
        return false
    }

    var isBodyPartFileNotReachable: Bool {
        if case let .multipartEncodingFailed(reason) = self, reason.isBodyPartFileNotReachable { return true }
        return false
    }

    var isBodyPartFileNotReachableWithError: Bool {
        if case let .multipartEncodingFailed(reason) = self, reason.isBodyPartFileNotReachableWithError { return true }
        return false
    }

    var isBodyPartFileIsDirectory: Bool {
        if case let .multipartEncodingFailed(reason) = self, reason.isBodyPartFileIsDirectory { return true }
        return false
    }

    var isBodyPartFileSizeNotAvailable: Bool {
        if case let .multipartEncodingFailed(reason) = self, reason.isBodyPartFileSizeNotAvailable { return true }
        return false
    }

    var isBodyPartFileSizeQueryFailedWithError: Bool {
        if case let .multipartEncodingFailed(reason) = self, reason.isBodyPartFileSizeQueryFailedWithError { return true }
        return false
    }

    var isBodyPartInputStreamCreationFailed: Bool {
        if case let .multipartEncodingFailed(reason) = self, reason.isBodyPartInputStreamCreationFailed { return true }
        return false
    }

    var isOutputStreamCreationFailed: Bool {
        if case let .multipartEncodingFailed(reason) = self, reason.isOutputStreamCreationFailed { return true }
        return false
    }

    var isOutputStreamFileAlreadyExists: Bool {
        if case let .multipartEncodingFailed(reason) = self, reason.isOutputStreamFileAlreadyExists { return true }
        return false
    }

    var isOutputStreamURLInvalid: Bool {
        if case let .multipartEncodingFailed(reason) = self, reason.isOutputStreamURLInvalid { return true }
        return false
    }

    var isOutputStreamWriteFailed: Bool {
        if case let .multipartEncodingFailed(reason) = self, reason.isOutputStreamWriteFailed { return true }
        return false
    }

    var isInputStreamReadFailed: Bool {
        if case let .multipartEncodingFailed(reason) = self, reason.isInputStreamReadFailed { return true }
        return false
    }

    // ResponseSerializationFailureReason

    var isInputDataNil: Bool {
        if case let .responseSerializationFailed(reason) = self, reason.isInputDataNil { return true }
        return false
    }

    var isInputDataNilOrZeroLength: Bool {
        if case let .responseSerializationFailed(reason) = self, reason.isInputDataNilOrZeroLength { return true }
        return false
    }

    var isInputFileNil: Bool {
        if case let .responseSerializationFailed(reason) = self, reason.isInputFileNil { return true }
        return false
    }

    var isInputFileReadFailed: Bool {
        if case let .responseSerializationFailed(reason) = self, reason.isInputFileReadFailed { return true }
        return false
    }

    var isStringSerializationFailed: Bool {
        if case let .responseSerializationFailed(reason) = self, reason.isStringSerializationFailed { return true }
        return false
    }

    var isJSONSerializationFailed: Bool {
        if case let .responseSerializationFailed(reason) = self, reason.isJSONSerializationFailed { return true }
        return false
    }

    var isPropertyListSerializationFailed: Bool {
        if case let .responseSerializationFailed(reason) = self, reason.isPropertyListSerializationFailed { return true }
        return false
    }

    // ResponseValidationFailureReason

    var isDataFileNil: Bool {
        if case let .responseValidationFailed(reason) = self, reason.isDataFileNil { return true }
        return false
    }

    var isDataFileReadFailed: Bool {
        if case let .responseValidationFailed(reason) = self, reason.isDataFileReadFailed { return true }
        return false
    }

    var isMissingContentType: Bool {
        if case let .responseValidationFailed(reason) = self, reason.isMissingContentType { return true }
        return false
    }

    var isUnacceptableContentType: Bool {
        if case let .responseValidationFailed(reason) = self, reason.isUnacceptableContentType { return true }
        return false
    }

    var isUnacceptableStatusCode: Bool {
        if case let .responseValidationFailed(reason) = self, reason.isUnacceptableStatusCode { return true }
        return false
    }
}

// MARK: -

extension AFError.ParameterEncodingFailureReason {
    var isMissingURL: Bool {
        if case .missingURL = self { return true }
        return false
    }

    var isJSONEncodingFailed: Bool {
        if case .jsonEncodingFailed = self { return true }
        return false
    }

    var isPropertyListEncodingFailed: Bool {
        if case .propertyListEncodingFailed = self { return true }
        return false
    }
}

// MARK: -

extension AFError.MultipartEncodingFailureReason {
    var isBodyPartURLInvalid: Bool {
        if case .bodyPartURLInvalid = self { return true }
        return false
    }

    var isBodyPartFilenameInvalid: Bool {
        if case .bodyPartFilenameInvalid = self { return true }
        return false
    }

    var isBodyPartFileNotReachable: Bool {
        if case .bodyPartFileNotReachable = self { return true }
        return false
    }

    var isBodyPartFileNotReachableWithError: Bool {
        if case .bodyPartFileNotReachableWithError = self { return true }
        return false
    }

    var isBodyPartFileIsDirectory: Bool {
        if case .bodyPartFileIsDirectory = self { return true }
        return false
    }

    var isBodyPartFileSizeNotAvailable: Bool {
        if case .bodyPartFileSizeNotAvailable = self { return true }
        return false
    }

    var isBodyPartFileSizeQueryFailedWithError: Bool {
        if case .bodyPartFileSizeQueryFailedWithError = self { return true }
        return false
    }

    var isBodyPartInputStreamCreationFailed: Bool {
        if case .bodyPartInputStreamCreationFailed = self { return true }
        return false
    }

    var isOutputStreamCreationFailed: Bool {
        if case .outputStreamCreationFailed = self { return true }
        return false
    }

    var isOutputStreamFileAlreadyExists: Bool {
        if case .outputStreamFileAlreadyExists = self { return true }
        return false
    }

    var isOutputStreamURLInvalid: Bool {
        if case .outputStreamURLInvalid = self { return true }
        return false
    }

    var isOutputStreamWriteFailed: Bool {
        if case .outputStreamWriteFailed = self { return true }
        return false
    }

    var isInputStreamReadFailed: Bool {
        if case .inputStreamReadFailed = self { return true }
        return false
    }
}

// MARK: -

extension AFError.ResponseSerializationFailureReason {
    var isInputDataNil: Bool {
        if case .inputDataNil = self { return true }
        return false
    }

    var isInputDataNilOrZeroLength: Bool {
        if case .inputDataNilOrZeroLength = self { return true }
        return false
    }

    var isInputFileNil: Bool {
        if case .inputFileNil = self { return true }
        return false
    }

    var isInputFileReadFailed: Bool {
        if case .inputFileReadFailed = self { return true }
        return false
    }

    var isStringSerializationFailed: Bool {
        if case .stringSerializationFailed = self { return true }
        return false
    }

    var isJSONSerializationFailed: Bool {
        if case .jsonSerializationFailed = self { return true }
        return false
    }

    var isPropertyListSerializationFailed: Bool {
        if case .propertyListSerializationFailed = self { return true }
        return false
    }
}

// MARK: -

extension AFError.ResponseValidationFailureReason {
    var isDataFileNil: Bool {
        if case .dataFileNil = self { return true }
        return false
    }

    var isDataFileReadFailed: Bool {
        if case .dataFileReadFailed = self { return true }
        return false
    }

    var isMissingContentType: Bool {
        if case .missingContentType = self { return true }
        return false
    }

    var isUnacceptableContentType: Bool {
        if case .unacceptableContentType = self { return true }
        return false
    }

    var isUnacceptableStatusCode: Bool {
        if case .unacceptableStatusCode = self { return true }
        return false
    }
}
