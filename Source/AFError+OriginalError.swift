//
//  AFError+OriginalError.swift
//
//  Copyright (c) 2014-2020 Alamofire Software Foundation (http://alamofire.org/)
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

public extension AFError {
    
    var originalError: Error? {
        switch self {
        case .createUploadableFailed(let error): return error
        case .createURLRequestFailed(let error): return error
        case .downloadedFileMoveFailed(let error, _, _): return error
        case .explicitlyCancelled: return nil
        case .invalidURL: return nil
        case .multipartEncodingFailed(let reason): return reason.originalError
        case .parameterEncoderFailed(let reason): return reason.originalError
        case .parameterEncodingFailed(let reason): return reason.originalError
        case .requestAdaptationFailed(let error): return error
        case .requestRetryFailed(_, let originalError): return originalError
        case .responseValidationFailed(let reason): return reason.originalError
        case .responseSerializationFailed(let reason): return reason.originalError
        case .serverTrustEvaluationFailed(let reason): return reason.originalError
        case .sessionDeinitialized: return nil
        case .sessionInvalidated(let error): return error
        case .sessionTaskFailed(let error): return error
        case .urlRequestValidationFailed(let reason): return reason.originalError
        }
    }
}

public extension AFError.MultipartEncodingFailureReason {
    
    var originalError: Error? {
        switch self {
        case .bodyPartURLInvalid: return nil
        case .bodyPartFilenameInvalid: return nil
        case .bodyPartFileNotReachable: return nil
        case .bodyPartFileNotReachableWithError(_, let error): return error
        case .bodyPartFileIsDirectory: return nil
        case .bodyPartFileSizeNotAvailable: return nil
        case .bodyPartFileSizeQueryFailedWithError(_, let error): return error
        case .bodyPartInputStreamCreationFailed: return nil
        case .outputStreamCreationFailed: return nil
        case .outputStreamFileAlreadyExists: return nil
        case .outputStreamURLInvalid: return nil
        case .outputStreamWriteFailed(let error): return error
        case .inputStreamReadFailed(let error): return error
        }
    }
}

public extension AFError.ParameterEncoderFailureReason {
    
    var originalError: Error? {
        switch self {
        case .missingRequiredComponent: return nil
        case .encoderFailed(let error): return error
        }
    }
}

public extension AFError.ParameterEncodingFailureReason {
    
    var originalError: Error? {
        switch self {
        case .missingURL: return nil
        case .jsonEncodingFailed(let error): return error
        case .customEncodingFailed(let error): return error
        }
    }
}

public extension AFError.ResponseValidationFailureReason {
    
    var originalError: Error? {
        switch self {
        case .dataFileNil: return nil
        case .dataFileReadFailed: return nil
        case .missingContentType: return nil
        case .unacceptableContentType: return nil
        case .unacceptableStatusCode: return nil
        case .customValidationFailed(let error): return error
        }
    }
}

public extension AFError.ResponseSerializationFailureReason {
    
    var originalError: Error? {
        switch self {
        case .inputDataNilOrZeroLength: return nil
        case .inputFileNil: return nil
        case .inputFileReadFailed: return nil
        case .stringSerializationFailed: return nil
        case .jsonSerializationFailed(let error): return error
        case .decodingFailed(let error): return error
        case .customSerializationFailed(let error): return error
        case .invalidEmptyResponse: return nil
        }
    }
}

public extension AFError.ServerTrustFailureReason {
    
    var originalError: Error? {
        switch self {
        case .noRequiredEvaluator: return nil
        case .noCertificatesFound: return nil
        case .noPublicKeysFound: return nil
        case .policyApplicationFailed: return nil
        case .settingAnchorCertificatesFailed: return nil
        case .revocationPolicyCreationFailed: return nil
        case .trustEvaluationFailed(let error): return error
        case .defaultEvaluationFailed: return nil
        case .hostValidationFailed: return nil
        case .revocationCheckFailed: return nil
        case .certificatePinningFailed: return nil
        case .publicKeyPinningFailed: return nil
        case .customEvaluationFailed(let error): return error
        }
    }
}

public extension AFError.URLRequestValidationFailureReason {
    
    var originalError: Error? {
        switch self {
        case .bodyDataInGETRequest: return nil
        }
    }
}
