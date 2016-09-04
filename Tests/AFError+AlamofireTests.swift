//
//  AFError+AlamofireTests.swift
//  Alamofire
//
//  Created by Jon Shier on 8/28/16.
//  Copyright © 2016 Alamofire. All rights reserved.
//

import Alamofire

extension AFError {
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

    // SerializationFailureReason

    var isInputDataNil: Bool {
        if case let .responseSerializationFailed(reason) = self, reason.isInputDataNil { return true }
        return false
    }

    var isInputDataNilOrZeroLength: Bool {
        if case let .responseSerializationFailed(reason) = self, reason.isInputDataNilOrZeroLength { return true }
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

    // ValidationFailureReason

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

extension AFError.SerializationFailureReason {
    var isInputDataNil: Bool {
        if case .inputDataNil = self { return true }
        return false
    }

    var isInputDataNilOrZeroLength: Bool {
        if case .inputDataNilOrZeroLength = self { return true }
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

extension AFError.ValidationFailureReason {
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
