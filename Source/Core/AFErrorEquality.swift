//
//  AFErrorEquality.swift
//
//  Copyright (c) 2026 Alamofire Software Foundation (http://alamofire.org/)
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

/// Compares two values of statically unknown type, using a tiered strategy to produce the most precise, safest
/// comparison available:
///
/// 1. If both values share a common concrete, dynamic type which conforms to `Equatable`, that conformance is used
///    to compare them directly. This is the most precise comparison available.
/// 2. Otherwise, if that concrete type is a class, reference identity (`===`) is used. This can't produce a false
///    positive, and is reflexive: the same instance always compares equal to itself.
/// 3. Otherwise—a non-`Equatable`, non-class value, such as a `struct` or `enum` without a hand-written `==`—
///    there's no reliable signal available to compare on, so the two are considered unequal.
///
/// Both tiers are implemented as generic functions constrained to `Equatable` and `AnyObject`, respectively, so the
/// actual `==`/`===` comparisons are performed through the compiler's own generic (existential-opening) dispatch
/// rather than hand-written, manually cast comparisons; only the minimal, unavoidable dynamic checks needed to
/// select which generic implementation applies—whether `lhs` conforms to `Equatable`, and whether its dynamic type
/// is a class—are performed directly.
///
/// This is the generic building block used to give `AFError` a meaningful `Equatable` conformance even though
/// several of its associated values are typed as existentials (`any Error`, `any URLConvertible`) which don't
/// themselves conform to `Equatable`.
@inline(__always)
private func isEqual(_ lhs: Any, _ rhs: Any) -> Bool {
    guard type(of: lhs) == type(of: rhs) else { return false }

    if let lhs = lhs as? any Equatable {
        return _isEqualEquatable(lhs, rhs)
    }

    return (lhs as AnyObject) === (rhs as AnyObject)
}

extension Error {
    @inline(__always)
    func isEqual(to other: any Error) -> Bool {
        _isEqualError(self, other)
    }
}

extension Equatable {
    @inline(__always)
    func isEqual(to other: Any) -> Bool {
        _isEqualEquatable(self, other)
    }
}

@inline(__always)
func _isEqualError<E: Error>(_ lhs: E, _ rhs: any Error) -> Bool {
    guard type(of: lhs) == type(of: rhs) else { return false }

    guard let rhs = rhs as? E else { return false }

    guard let lhs = lhs as? (any Equatable) else {
        return (lhs as AnyObject) === (rhs as AnyObject)
    }

    return _isEqualEquatable(lhs, rhs)
}

@inline(__always)
func _isEqualEquatable<E: Equatable>(_ lhs: E, _ rhs: Any) -> Bool {
    guard let rhs = rhs as? E else { return false }

    return lhs == rhs
}

/// Compares two optional `Error`s for equality, treating two `nil` values as equal and any mismatch of `nil` and
/// non-`nil` as unequal.
@inline(__always)
private func isEqual(_ lhs: (any Error)?, _ rhs: (any Error)?) -> Bool {
    switch (lhs, rhs) {
    case (.none, .none): true
    case let (lhs?, rhs?): lhs.isEqual(to: rhs)
    default: false
    }
}

extension AFError {
    public static func ==(lhs: AFError, rhs: AFError) -> Bool {
        switch (lhs, rhs) {
        case let (.createUploadableFailed(lhsError), .createUploadableFailed(rhsError)):
            return lhsError.isEqual(to: rhsError)
        case let (.createURLRequestFailed(lhsError), .createURLRequestFailed(rhsError)):
            return lhsError.isEqual(to: rhsError)
        case let (.downloadedFileMoveFailed(lhsError, lhsSource, lhsDestination),
                  .downloadedFileMoveFailed(rhsError, rhsSource, rhsDestination)):
            return lhsError.isEqual(to: rhsError) && lhsSource == rhsSource && lhsDestination == rhsDestination
        case (.explicitlyCancelled, .explicitlyCancelled):
            return true
        case let (.invalidURL(lhsURL), .invalidURL(rhsURL)):
            return Alamofire.isEqual(lhsURL, rhsURL)
        case let (.multipartEncodingFailed(lhsReason), .multipartEncodingFailed(rhsReason)):
            return lhsReason == rhsReason
        case let (.parameterEncodingFailed(lhsReason), .parameterEncodingFailed(rhsReason)):
            return lhsReason == rhsReason
        case let (.parameterEncoderFailed(lhsReason), .parameterEncoderFailed(rhsReason)):
            return lhsReason == rhsReason
        case let (.requestAdaptationFailed(lhsError), .requestAdaptationFailed(rhsError)):
            return lhsError.isEqual(to: rhsError)
        case let (.requestRetryFailed(lhsRetryError, lhsOriginalError), .requestRetryFailed(rhsRetryError, rhsOriginalError)):
            return lhsRetryError.isEqual(to: rhsRetryError) && lhsOriginalError.isEqual(to: rhsOriginalError)
        case let (.responseValidationFailed(lhsReason), .responseValidationFailed(rhsReason)):
            return lhsReason == rhsReason
        case let (.responseSerializationFailed(lhsReason), .responseSerializationFailed(rhsReason)):
            return lhsReason == rhsReason
        #if canImport(Security)
        case let (.serverTrustEvaluationFailed(lhsReason), .serverTrustEvaluationFailed(rhsReason)):
            return lhsReason == rhsReason
        #endif
        case (.sessionDeinitialized, .sessionDeinitialized):
            return true
        case let (.sessionInvalidated(lhsError), .sessionInvalidated(rhsError)):
            return Alamofire.isEqual(lhsError, rhsError)
        case let (.sessionTaskFailed(lhsError), .sessionTaskFailed(rhsError)):
            return lhsError.isEqual(to: rhsError)
        case let (.urlRequestValidationFailed(lhsReason), .urlRequestValidationFailed(rhsReason)):
            return lhsReason == rhsReason
        default:
            return false
        }
    }
}

extension AFError.MultipartEncodingFailureReason {
    public static func ==(lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case let (.bodyPartURLInvalid(lhsURL), .bodyPartURLInvalid(rhsURL)):
            lhsURL == rhsURL
        case let (.bodyPartFilenameInvalid(lhsURL), .bodyPartFilenameInvalid(rhsURL)):
            lhsURL == rhsURL
        case let (.bodyPartFileNotReachable(lhsURL), .bodyPartFileNotReachable(rhsURL)):
            lhsURL == rhsURL
        case let (.bodyPartFileNotReachableWithError(lhsURL, lhsError), .bodyPartFileNotReachableWithError(rhsURL, rhsError)):
            lhsURL == rhsURL && lhsError.isEqual(to: rhsError)
        case let (.bodyPartFileIsDirectory(lhsURL), .bodyPartFileIsDirectory(rhsURL)):
            lhsURL == rhsURL
        case let (.bodyPartFileSizeNotAvailable(lhsURL), .bodyPartFileSizeNotAvailable(rhsURL)):
            lhsURL == rhsURL
        case let (.bodyPartFileSizeQueryFailedWithError(lhsURL, lhsError), .bodyPartFileSizeQueryFailedWithError(rhsURL, rhsError)):
            lhsURL == rhsURL && lhsError.isEqual(to: rhsError)
        case let (.bodyPartInputStreamCreationFailed(lhsURL), .bodyPartInputStreamCreationFailed(rhsURL)):
            lhsURL == rhsURL
        case let (.outputStreamCreationFailed(lhsURL), .outputStreamCreationFailed(rhsURL)):
            lhsURL == rhsURL
        case let (.outputStreamFileAlreadyExists(lhsURL), .outputStreamFileAlreadyExists(rhsURL)):
            lhsURL == rhsURL
        case let (.outputStreamURLInvalid(lhsURL), .outputStreamURLInvalid(rhsURL)):
            lhsURL == rhsURL
        case let (.outputStreamWriteFailed(lhsError), .outputStreamWriteFailed(rhsError)):
            lhsError.isEqual(to: rhsError)
        case let (.inputStreamReadFailed(lhsError), .inputStreamReadFailed(rhsError)):
            lhsError.isEqual(to: rhsError)
        default:
            false
        }
    }
}

extension AFError.ParameterEncodingFailureReason {
    public static func ==(lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.missingURL, .missingURL):
            true
        case let (.jsonEncodingFailed(lhsError), .jsonEncodingFailed(rhsError)):
            lhsError.isEqual(to: rhsError)
        case let (.customEncodingFailed(lhsError), .customEncodingFailed(rhsError)):
            lhsError.isEqual(to: rhsError)
        default:
            false
        }
    }
}

extension AFError.ParameterEncoderFailureReason {
    public static func ==(lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case let (.missingRequiredComponent(lhsComponent), .missingRequiredComponent(rhsComponent)):
            lhsComponent == rhsComponent
        case let (.encoderFailed(lhsError), .encoderFailed(rhsError)):
            lhsError.isEqual(to: rhsError)
        default:
            false
        }
    }
}

extension AFError.ResponseValidationFailureReason {
    public static func ==(lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.dataFileNil, .dataFileNil):
            true
        case let (.dataFileReadFailed(lhsURL), .dataFileReadFailed(rhsURL)):
            lhsURL == rhsURL
        case let (.missingContentType(lhsTypes), .missingContentType(rhsTypes)):
            lhsTypes == rhsTypes
        case let (.unacceptableContentType(lhsTypes, lhsContentType), .unacceptableContentType(rhsTypes, rhsContentType)):
            lhsTypes == rhsTypes && lhsContentType == rhsContentType
        case let (.unacceptableStatusCode(lhsCode), .unacceptableStatusCode(rhsCode)):
            lhsCode == rhsCode
        case let (.customValidationFailed(lhsError), .customValidationFailed(rhsError)):
            lhsError.isEqual(to: rhsError)
        default:
            false
        }
    }
}

extension AFError.ResponseSerializationFailureReason {
    public static func ==(lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.inputDataNilOrZeroLength, .inputDataNilOrZeroLength):
            true
        case (.inputFileNil, .inputFileNil):
            true
        case let (.inputFileReadFailed(lhsURL), .inputFileReadFailed(rhsURL)):
            lhsURL == rhsURL
        case let (.stringSerializationFailed(lhsEncoding), .stringSerializationFailed(rhsEncoding)):
            lhsEncoding == rhsEncoding
        case let (.jsonSerializationFailed(lhsError), .jsonSerializationFailed(rhsError)):
            lhsError.isEqual(to: rhsError)
        case let (.decodingFailed(lhsError), .decodingFailed(rhsError)):
            lhsError.isEqual(to: rhsError)
        case let (.customSerializationFailed(lhsError), .customSerializationFailed(rhsError)):
            lhsError.isEqual(to: rhsError)
        case let (.invalidEmptyResponse(lhsType), .invalidEmptyResponse(rhsType)):
            lhsType == rhsType
        default:
            false
        }
    }
}

#if canImport(Security)
extension AFError.ServerTrustFailureReason {
    public static func ==(lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case let (.noRequiredEvaluator(lhsHost), .noRequiredEvaluator(rhsHost)):
            lhsHost == rhsHost
        case (.noCertificatesFound, .noCertificatesFound):
            true
        case (.noPublicKeysFound, .noPublicKeysFound):
            true
        case let (.policyApplicationFailed(lhsTrust, lhsPolicy, lhsStatus), .policyApplicationFailed(rhsTrust, rhsPolicy, rhsStatus)):
            lhsTrust == rhsTrust && lhsPolicy == rhsPolicy && lhsStatus == rhsStatus
        case let (.settingAnchorCertificatesFailed(lhsStatus, lhsCertificates), .settingAnchorCertificatesFailed(rhsStatus, rhsCertificates)):
            lhsStatus == rhsStatus && lhsCertificates == rhsCertificates
        case (.revocationPolicyCreationFailed, .revocationPolicyCreationFailed):
            true
        case let (.trustEvaluationFailed(lhsError), .trustEvaluationFailed(rhsError)):
            Alamofire.isEqual(lhsError, rhsError)
        case let (.defaultEvaluationFailed(lhsOutput), .defaultEvaluationFailed(rhsOutput)):
            lhsOutput == rhsOutput
        case let (.hostValidationFailed(lhsOutput), .hostValidationFailed(rhsOutput)):
            lhsOutput == rhsOutput
        case let (.revocationCheckFailed(lhsOutput, lhsOptions), .revocationCheckFailed(rhsOutput, rhsOptions)):
            lhsOutput == rhsOutput && lhsOptions == rhsOptions
        case let (.certificatePinningFailed(lhsHost, lhsTrust, lhsPinnedCertificates, lhsServerCertificates),
                  .certificatePinningFailed(rhsHost, rhsTrust, rhsPinnedCertificates, rhsServerCertificates)):
            lhsHost == rhsHost
                && lhsTrust == rhsTrust
                && lhsPinnedCertificates == rhsPinnedCertificates
                && lhsServerCertificates == rhsServerCertificates
        case let (.publicKeyPinningFailed(lhsHost, lhsTrust, lhsPinnedKeys, lhsServerKeys),
                  .publicKeyPinningFailed(rhsHost, rhsTrust, rhsPinnedKeys, rhsServerKeys)):
            lhsHost == rhsHost && lhsTrust == rhsTrust && lhsPinnedKeys == rhsPinnedKeys && lhsServerKeys == rhsServerKeys
        case let (.customEvaluationFailed(lhsError), .customEvaluationFailed(rhsError)):
            lhsError.isEqual(to: rhsError)
        default:
            false
        }
    }
}
#endif
