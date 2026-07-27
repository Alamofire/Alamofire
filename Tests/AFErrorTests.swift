//
//  AFErrorTests.swift
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

import Alamofire
import Foundation
#if canImport(Security)
@preconcurrency import Security
#endif
import Testing

@Suite
struct AFErrorTests {
    @Test("Identical, payload-less cases are equal")
    func simpleCasesAreEqual() {
        #expect(AFError.explicitlyCancelled == AFError.explicitlyCancelled)
        #expect(AFError.sessionDeinitialized == AFError.sessionDeinitialized)
    }

    @Test("Different cases are never equal, even when their any Error payloads match")
    func differentCasesAreNeverEqual() {
        let error = EquatableTestError(code: 1)
        #expect(AFError.createUploadableFailed(error: error) != AFError.createURLRequestFailed(error: error))
        #expect(AFError.explicitlyCancelled != AFError.sessionDeinitialized)
    }

    @Test("Equal Equatable errors of the same concrete type make the wrapping AFError equal")
    func equatableErrorEquality() {
        #expect(AFError.createUploadableFailed(error: EquatableTestError(code: 1)) ==
            AFError.createUploadableFailed(error: EquatableTestError(code: 1)))
    }

    @Test("Unequal Equatable errors of the same concrete type make the wrapping AFError unequal")
    func equatableErrorInequality() {
        #expect(AFError.createUploadableFailed(error: EquatableTestError(code: 1)) !=
            AFError.createUploadableFailed(error: EquatableTestError(code: 2)))
    }

    @Test("Errors of different concrete types are never equal, even with matching stored properties")
    func differentConcreteErrorTypesAreUnequal() {
        #expect(AFError.createUploadableFailed(error: EquatableTestError(code: 1)) !=
            AFError.createUploadableFailed(error: OtherEquatableTestError(code: 1)))
    }

    @Test("Equatable conformance is used directly for well-known Foundation errors like URLError")
    func urlErrorUsesItsOwnEquatableConformance() {
        #expect(AFError.sessionTaskFailed(error: URLError(.notConnectedToInternet)) ==
            AFError.sessionTaskFailed(error: URLError(.notConnectedToInternet)))
        #expect(AFError.sessionTaskFailed(error: URLError(.notConnectedToInternet)) !=
            AFError.sessionTaskFailed(error: URLError(.timedOut)))
    }

    @Test("Non-Equatable, non-class errors are never considered equal, even with identical stored properties")
    func nonEquatableValueErrorsAreAlwaysUnequal() {
        // Without an `Equatable` conformance (and without reference identity, since this is a `struct`), there's no
        // reliable way to determine whether two instances represent the "same" error, so they're always unequal,
        // even here where their `message`s match.
        #expect(AFError.requestAdaptationFailed(error: NonEquatableTestError(message: "a")) !=
            AFError.requestAdaptationFailed(error: NonEquatableTestError(message: "a")))
    }

    @Test("Non-Equatable enum errors are never considered equal, regardless of case or associated value")
    func nonEquatableEnumErrorsAreAlwaysUnequal() {
        #expect(AFError.requestAdaptationFailed(error: NonEquatableTestErrorEnum.first(1)) !=
            AFError.requestAdaptationFailed(error: NonEquatableTestErrorEnum.second(1)))
        #expect(AFError.requestAdaptationFailed(error: NonEquatableTestErrorEnum.first(1)) !=
            AFError.requestAdaptationFailed(error: NonEquatableTestErrorEnum.first(1)))
    }

    @Test("Non-Equatable class errors fall back to reference identity")
    func nonEquatableClassErrorsUseReferenceIdentity() {
        let instance = NonEquatableClassError(code: 1)

        // The exact same instance always compares equal to itself...
        #expect(AFError.requestAdaptationFailed(error: instance) == AFError.requestAdaptationFailed(error: instance))
        // ...but two different instances are unequal, even with identical stored properties.
        #expect(AFError.requestAdaptationFailed(error: NonEquatableClassError(code: 1)) !=
            AFError.requestAdaptationFailed(error: NonEquatableClassError(code: 1)))
    }

    @Test("Cases with two any Error payloads require both to match independently")
    func requestRetryFailedRequiresBothErrorsToMatch() {
        let retry = EquatableTestError(code: 1)
        let original = EquatableTestError(code: 2)

        #expect(AFError.requestRetryFailed(retryError: retry, originalError: original) ==
            AFError.requestRetryFailed(retryError: retry, originalError: original))
        #expect(AFError.requestRetryFailed(retryError: retry, originalError: original) !=
            AFError.requestRetryFailed(retryError: EquatableTestError(code: 99), originalError: original))
        #expect(AFError.requestRetryFailed(retryError: retry, originalError: original) !=
            AFError.requestRetryFailed(retryError: retry, originalError: EquatableTestError(code: 99)))
    }

    @Test("downloadedFileMoveFailed compares its any Error payload alongside its plain URL properties")
    func downloadedFileMoveFailedComparesAllAssociatedValues() {
        let source = URL(string: "file:///source")!
        let destination = URL(string: "file:///destination")!
        let error = EquatableTestError(code: 1)

        #expect(AFError.downloadedFileMoveFailed(error: error, source: source, destination: destination) ==
            AFError.downloadedFileMoveFailed(error: error, source: source, destination: destination))
        #expect(AFError.downloadedFileMoveFailed(error: error, source: source, destination: destination) !=
            AFError.downloadedFileMoveFailed(error: EquatableTestError(code: 2), source: source, destination: destination))
        #expect(AFError.downloadedFileMoveFailed(error: error, source: source, destination: destination) !=
            AFError.downloadedFileMoveFailed(error: error, source: destination, destination: destination))
    }

    @Test("Optional any Error payloads treat nil as a distinct, self-equal value")
    func optionalErrorPayloadHandlesNilCorrectly() {
        #expect(AFError.sessionInvalidated(error: nil) == AFError.sessionInvalidated(error: nil))
        #expect(AFError.sessionInvalidated(error: nil) != AFError.sessionInvalidated(error: EquatableTestError(code: 1)))
        #expect(AFError.sessionInvalidated(error: EquatableTestError(code: 1)) != AFError.sessionInvalidated(error: nil))
        #expect(AFError.sessionInvalidated(error: EquatableTestError(code: 1)) ==
            AFError.sessionInvalidated(error: EquatableTestError(code: 1)))
    }

    @Test("Equal String URLConvertibles make invalidURL equal")
    func equalStringURLConvertiblesAreEqual() {
        #expect(AFError.invalidURL(url: "https://example.com") == AFError.invalidURL(url: "https://example.com"))
    }

    @Test("Different String URLConvertibles are unequal")
    func differentStringURLConvertiblesAreUnequal() {
        #expect(AFError.invalidURL(url: "https://example.com") != AFError.invalidURL(url: "https://other.com"))
    }

    @Test("Equal URL URLConvertibles make invalidURL equal")
    func equalURLURLConvertiblesAreEqual() {
        let url = URL(string: "https://example.com")!
        #expect(AFError.invalidURL(url: url) == AFError.invalidURL(url: url))
    }

    @Test("A String and a URL representing the same address are unequal, since existential comparison requires matching concrete types")
    func differentConcreteURLConvertibleTypesAreUnequalDespiteMatchingContent() {
        let string = "https://example.com"
        let url = URL(string: string)!
        #expect(AFError.invalidURL(url: string) != AFError.invalidURL(url: url))
    }

    @Test("MultipartEncodingFailureReason compares its URL and any Error payload together")
    func multipartEncodingFailureReason() {
        let url = URL(string: "file:///part")!
        let reason1 = AFError.MultipartEncodingFailureReason.bodyPartFileNotReachableWithError(atURL: url, error: EquatableTestError(code: 1))
        let reason2 = AFError.MultipartEncodingFailureReason.bodyPartFileNotReachableWithError(atURL: url, error: EquatableTestError(code: 1))
        let reason3 = AFError.MultipartEncodingFailureReason.bodyPartFileNotReachableWithError(atURL: url, error: EquatableTestError(code: 2))

        #expect(AFError.multipartEncodingFailed(reason: reason1) == AFError.multipartEncodingFailed(reason: reason2))
        #expect(AFError.multipartEncodingFailed(reason: reason1) != AFError.multipartEncodingFailed(reason: reason3))
    }

    @Test("ParameterEncodingFailureReason compares any Error payloads and distinguishes its cases")
    func parameterEncodingFailureReason() {
        #expect(AFError.ParameterEncodingFailureReason.missingURL == .missingURL)
        #expect(AFError.parameterEncodingFailed(reason: .jsonEncodingFailed(error: EquatableTestError(code: 1))) ==
            AFError.parameterEncodingFailed(reason: .jsonEncodingFailed(error: EquatableTestError(code: 1))))
        #expect(AFError.parameterEncodingFailed(reason: .jsonEncodingFailed(error: EquatableTestError(code: 1))) !=
            AFError.parameterEncodingFailed(reason: .customEncodingFailed(error: EquatableTestError(code: 1))))
    }

    @Test("ParameterEncoderFailureReason compares both its plain and any Error cases")
    func parameterEncoderFailureReason() {
        #expect(AFError.ParameterEncoderFailureReason.missingRequiredComponent(.url) == .missingRequiredComponent(.url))
        #expect(AFError.ParameterEncoderFailureReason.missingRequiredComponent(.httpMethod(rawValue: "GET")) !=
            .missingRequiredComponent(.httpMethod(rawValue: "POST")))
        #expect(AFError.parameterEncoderFailed(reason: .encoderFailed(error: EquatableTestError(code: 1))) ==
            AFError.parameterEncoderFailed(reason: .encoderFailed(error: EquatableTestError(code: 1))))
    }

    @Test("ResponseValidationFailureReason compares customValidationFailed's any Error payload")
    func responseValidationFailureReason() {
        #expect(AFError.responseValidationFailed(reason: .customValidationFailed(error: EquatableTestError(code: 1))) ==
            AFError.responseValidationFailed(reason: .customValidationFailed(error: EquatableTestError(code: 1))))
        #expect(AFError.responseValidationFailed(reason: .customValidationFailed(error: EquatableTestError(code: 1))) !=
            AFError.responseValidationFailed(reason: .customValidationFailed(error: EquatableTestError(code: 2))))
        #expect(AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 404)) ==
            AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 404)))
    }

    @Test("ResponseSerializationFailureReason compares each any Error case independently")
    func responseSerializationFailureReason() {
        #expect(AFError.responseSerializationFailed(reason: .decodingFailed(error: EquatableTestError(code: 1))) ==
            AFError.responseSerializationFailed(reason: .decodingFailed(error: EquatableTestError(code: 1))))
        #expect(AFError.responseSerializationFailed(reason: .decodingFailed(error: EquatableTestError(code: 1))) !=
            AFError.responseSerializationFailed(reason: .jsonSerializationFailed(error: EquatableTestError(code: 1))))
    }
}

// MARK: - Server Trust Failure Reason Equatable

#if canImport(Security)
@Suite("AFError ServerTrustFailureReason Equatable")
struct AFErrorServerTrustEquatableTests {
    @Test("Simple, payload-light cases compare their stored values and distinguish other cases")
    func simpleCases() {
        #expect(AFError.ServerTrustFailureReason.noRequiredEvaluator(host: "example.com") == .noRequiredEvaluator(host: "example.com"))
        #expect(AFError.ServerTrustFailureReason.noRequiredEvaluator(host: "example.com") != .noRequiredEvaluator(host: "other.com"))
        #expect(AFError.ServerTrustFailureReason.noCertificatesFound == .noCertificatesFound)
        #expect(AFError.ServerTrustFailureReason.noCertificatesFound != .noPublicKeysFound)
    }

    @Test("trustEvaluationFailed's optional any Error payload is compared, including the nil case")
    func trustEvaluationFailedOptionalError() {
        #expect(AFError.ServerTrustFailureReason.trustEvaluationFailed(error: nil) == .trustEvaluationFailed(error: nil))
        #expect(AFError.ServerTrustFailureReason.trustEvaluationFailed(error: nil) !=
            .trustEvaluationFailed(error: EquatableTestError(code: 1)))
        #expect(AFError.ServerTrustFailureReason.trustEvaluationFailed(error: EquatableTestError(code: 1)) ==
            .trustEvaluationFailed(error: EquatableTestError(code: 1)))
    }

    @Test("customEvaluationFailed compares its any Error payload")
    func customEvaluationFailed() {
        #expect(AFError.ServerTrustFailureReason.customEvaluationFailed(error: EquatableTestError(code: 1)) ==
            .customEvaluationFailed(error: EquatableTestError(code: 1)))
        #expect(AFError.ServerTrustFailureReason.customEvaluationFailed(error: EquatableTestError(code: 1)) !=
            .customEvaluationFailed(error: EquatableTestError(code: 2)))
    }
}
#endif

// MARK: - Test Fixtures

/// A trivial `Error` which also conforms to `Equatable`. Used to prove that `AFError`'s `Equatable` conformance
/// prefers exact `Equatable` comparison, when it's available, over the coarser fallbacks used for non-`Equatable`
/// errors.
private struct EquatableTestError: Error, Equatable {
    let code: Int
}

/// A second `Equatable` `Error` type, structurally identical to `EquatableTestError` but nominally distinct. Used to
/// prove that two wrapped errors are never considered equal unless they share the same concrete, dynamic type, even
/// when their stored properties match.
private struct OtherEquatableTestError: Error, Equatable {
    let code: Int
}

/// A trivial `Error` which does *not* conform to `Equatable`. When wrapped in an `AFError`, comparisons between two
/// separately constructed instances of this type are always `false`, since there's no reliable signal (no
/// `Equatable` conformance, and no reference identity, since this is a `struct`) to compare on.
private struct NonEquatableTestError: Error {
    let message: String
}

/// A non-`Equatable` `Error` enum with multiple cases. Like `NonEquatableTestError`, comparisons between two
/// separately constructed instances of this type are always `false`, regardless of case or associated value.
private enum NonEquatableTestErrorEnum: Error {
    case first(Int)
    case second(Int)
}

/// A non-`Equatable`, class-based `Error`. Since it's a reference type, comparisons between two instances of this
/// type fall back to reference identity (`===`): the exact same instance always compares equal to itself, but two
/// separate instances are considered unequal even when their stored properties match.
private final class NonEquatableClassError: Error {
    let code: Int

    init(code: Int) {
        self.code = code
    }
}
