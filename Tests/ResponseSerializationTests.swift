//
//  ResponseSerializationTests.swift
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

import Alamofire
import Foundation
import XCTest

final class DataResponseSerializationTestCase: BaseTestCase {

    // MARK: Properties

    private let error = AFError.responseSerializationFailed(reason: .inputDataNilOrZeroLength)

    // MARK: DataResponseSerializer

    func testThatDataResponseSerializerSucceedsWhenDataIsNotNil() {
        // Given
        let serializer = DataResponseSerializer()
        let data = Data("data".utf8)

        // When
        let result = AFResult { try serializer.serialize(request: nil, response: nil, data: data, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)
    }

    func testThatDataResponseSerializerFailsWhenDataIsNil() {
        // Given
        let serializer = DataResponseSerializer()

        // When
        let result = AFResult { try serializer.serialize(request: nil, response: nil, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error?.asAFError {
            XCTAssertTrue(error.isInputDataNilOrZeroLength)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatDataResponseSerializerFailsWhenErrorIsNotNil() {
        // Given
        let serializer = DataResponseSerializer()

        // When
        let result = AFResult { try serializer.serialize(request: nil, response: nil, data: nil, error: error) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error?.asAFError {
            XCTAssertTrue(error.isInputDataNilOrZeroLength)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatDataResponseSerializerFailsWhenDataIsNilWithNonEmptyResponseStatusCode() {
        // Given
        let serializer = DataResponseSerializer()
        let response = HTTPURLResponse(statusCode: 200)

        // When
        let result = AFResult { try serializer.serialize(request: nil, response: response, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure, "result is failure should be true")
        XCTAssertNil(result.value, "result value should be nil")
        XCTAssertNotNil(result.error, "result error should not be nil")

        if let error = result.error?.asAFError {
            XCTAssertTrue(error.isInputDataNilOrZeroLength)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatDataResponseSerializerSucceedsWhenDataIsNilWithGETRequestAnd204ResponseStatusCode() {
        // Given
        let serializer = DataResponseSerializer()
        let request = URLRequest.make(method: .get)
        let response = HTTPURLResponse(statusCode: 204)

        // When
        let result = AFResult { try serializer.serialize(request: request, response: response, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)

        if let data = result.value {
            XCTAssertEqual(data.count, 0)
        }
    }

    func testThatDataResponseSerializerSucceedsWhenDataIsNilWithGETRequestAnd205ResponseStatusCode() {
        // Given
        let serializer = DataResponseSerializer()
        let request = URLRequest.make(method: .get)
        let response = HTTPURLResponse(statusCode: 205)

        // When
        let result = AFResult { try serializer.serialize(request: request, response: response, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)

        if let data = result.value {
            XCTAssertEqual(data.count, 0)
        }
    }

    func testThatDataResponseSerializerSucceedsWhenDataIsNilWithHEADRequestAnd200ResponseStatusCode() {
        // Given
        let serializer = DataResponseSerializer()
        let request = URLRequest.make(method: .head)
        let response = HTTPURLResponse(statusCode: 200)

        // When
        let result = AFResult { try serializer.serialize(request: request, response: response, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)

        if let data = result.value {
            XCTAssertEqual(data.count, 0)
        }
    }

    // MARK: StringResponseSerializer

    func testThatStringResponseSerializerFailsWhenDataIsNil() {
        // Given
        let serializer = DataResponseSerializer()

        // When
        let result = AFResult { try serializer.serialize(request: nil, response: nil, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error?.asAFError {
            XCTAssertTrue(error.isInputDataNilOrZeroLength)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatStringResponseSerializerFailsWhenDataIsEmpty() {
        // Given
        let serializer = StringResponseSerializer()

        // When
        let result = AFResult { try serializer.serialize(request: nil, response: nil, data: Data(), error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error?.asAFError {
            XCTAssertTrue(error.isInputDataNilOrZeroLength)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatStringResponseSerializerSucceedsWithUTF8DataAndNoProvidedEncoding() {
        let serializer = StringResponseSerializer()
        let data = Data("data".utf8)

        // When
        let result = AFResult { try serializer.serialize(request: nil, response: nil, data: data, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)
    }

    func testThatStringResponseSerializerSucceedsWithUTF8DataAndUTF8ProvidedEncoding() {
        let serializer = StringResponseSerializer(encoding: .utf8)
        let data = Data("data".utf8)

        // When
        let result = AFResult { try serializer.serialize(request: nil, response: nil, data: data, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)
    }

    func testThatStringResponseSerializerSucceedsWithUTF8DataUsingResponseTextEncodingName() {
        let serializer = StringResponseSerializer()
        let data = Data("data".utf8)
        let response = HTTPURLResponse(statusCode: 200, headers: ["Content-Type": "image/jpeg; charset=utf-8"])

        // When
        let result = AFResult { try serializer.serialize(request: nil, response: response, data: data, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)
    }

    func testThatStringResponseSerializerFailsWithUTF32DataAndUTF8ProvidedEncoding() {
        // Given
        let serializer = StringResponseSerializer(encoding: .utf8)
        let data = "random data".data(using: .utf32)!

        // When
        let result = AFResult { try serializer.serialize(request: nil, response: nil, data: data, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error?.asAFError, let failedEncoding = error.failedStringEncoding {
            XCTAssertTrue(error.isStringSerializationFailed)
            XCTAssertEqual(failedEncoding, .utf8)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatStringResponseSerializerFailsWithUTF32DataAndUTF8ResponseEncoding() {
        // Given
        let serializer = StringResponseSerializer()
        let data = "random data".data(using: .utf32)!
        let response = HTTPURLResponse(statusCode: 200, headers: ["Content-Type": "image/jpeg; charset=utf-8"])

        // When
        let result = AFResult { try serializer.serialize(request: nil, response: response, data: data, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error?.asAFError, let failedEncoding = error.failedStringEncoding {
            XCTAssertTrue(error.isStringSerializationFailed)
            XCTAssertEqual(failedEncoding, .utf8)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatStringResponseSerializerFailsWhenErrorIsNotNil() {
        // Given
        let serializer = StringResponseSerializer()

        // When
        let result = AFResult { try serializer.serialize(request: nil, response: nil, data: nil, error: error) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error?.asAFError {
            XCTAssertTrue(error.isInputDataNilOrZeroLength)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatStringResponseSerializerFailsWhenDataIsNilWithNonEmptyResponseStatusCode() {
        // Given
        let serializer = StringResponseSerializer()
        let response = HTTPURLResponse(statusCode: 200)

        // When
        let result = AFResult { try serializer.serialize(request: nil, response: response, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error?.asAFError {
            XCTAssertTrue(error.isInputDataNilOrZeroLength)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatStringResponseSerializerSucceedsWhenDataIsNilWithGETRequestAnd204ResponseStatusCode() {
        // Given
        let serializer = StringResponseSerializer()
        let request = URLRequest.make(method: .get)
        let response = HTTPURLResponse(statusCode: 204)

        // When
        let result = AFResult { try serializer.serialize(request: request, response: response, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)

        if let string = result.value {
            XCTAssertEqual(string, "")
        }
    }

    func testThatStringResponseSerializerSucceedsWhenDataIsNilWithGETRequestAnd205ResponseStatusCode() {
        // Given
        let serializer = StringResponseSerializer()
        let request = URLRequest.make(method: .get)
        let response = HTTPURLResponse(statusCode: 205)

        // When
        let result = AFResult { try serializer.serialize(request: request, response: response, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)

        if let string = result.value {
            XCTAssertEqual(string, "")
        }
    }

    func testThatStringResponseSerializerSucceedsWhenDataIsNilWithHEADRequestAnd200ResponseStatusCode() {
        // Given
        let serializer = StringResponseSerializer()
        let request = URLRequest.make(method: .head)
        let response = HTTPURLResponse(statusCode: 200)

        // When
        let result = AFResult { try serializer.serialize(request: request, response: response, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)

        if let string = result.value {
            XCTAssertEqual(string, "")
        }
    }

    // MARK: JSONResponseSerializer

    func testThatJSONResponseSerializerFailsWhenDataIsNil() {
        // Given
        let serializer = JSONResponseSerializer()

        // When
        let result = AFResult { try serializer.serialize(request: nil, response: nil, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error?.asAFError {
            XCTAssertTrue(error.isInputDataNilOrZeroLength)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatJSONResponseSerializerFailsWhenDataIsEmpty() {
        // Given
        let serializer = JSONResponseSerializer()

        // When
        let result = AFResult { try serializer.serialize(request: nil, response: nil, data: Data(), error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error?.asAFError {
            XCTAssertTrue(error.isInputDataNilOrZeroLength)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatJSONResponseSerializerSucceedsWhenDataIsValidJSON() {
        // Given
        let serializer = JSONResponseSerializer()
        let data = Data("{\"json\": true}".utf8)

        // When
        let result = AFResult { try serializer.serialize(request: nil, response: nil, data: data, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)
    }

    func testThatJSONResponseSerializerFailsWhenDataIsInvalidJSON() {
        // Given
        let serializer = JSONResponseSerializer()
        let data = Data("definitely not valid json".utf8)

        // When
        let result = AFResult { try serializer.serialize(request: nil, response: nil, data: data, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error?.asAFError, let underlyingError = error.underlyingError as? CocoaError {
            XCTAssertTrue(error.isJSONSerializationFailed)
            XCTAssertEqual(underlyingError.errorCode, 3840)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatJSONResponseSerializerFailsWhenErrorIsNotNil() {
        // Given
        let serializer = JSONResponseSerializer()

        // When
        let result = AFResult { try serializer.serialize(request: nil, response: nil, data: nil, error: error) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error?.asAFError {
            XCTAssertTrue(error.isInputDataNilOrZeroLength)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatJSONResponseSerializerFailsWhenDataIsNilWithNonEmptyResponseStatusCode() {
        // Given
        let serializer = JSONResponseSerializer()
        let response = HTTPURLResponse(statusCode: 200)

        // When
        let result = AFResult { try serializer.serialize(request: nil, response: response, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error?.asAFError {
            XCTAssertTrue(error.isInputDataNilOrZeroLength)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatJSONResponseSerializerSucceedsWhenDataIsNilWithGETRequestAnd204ResponseStatusCode() {
        // Given
        let serializer = JSONResponseSerializer()
        let request = URLRequest.make(method: .get)
        let response = HTTPURLResponse(statusCode: 204)

        // When
        let result = AFResult { try serializer.serialize(request: request, response: response, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)

        if let json = result.value as? NSNull {
            XCTAssertEqual(json, NSNull())
        } else {
            XCTFail("json should not be nil")
        }
    }

    func testThatJSONResponseSerializerSucceedsWhenDataIsNilWithGETRequestAnd205ResponseStatusCode() {
        // Given
        let serializer = JSONResponseSerializer()
        let request = URLRequest.make(method: .get)
        let response = HTTPURLResponse(statusCode: 205)

        // When
        let result = AFResult { try serializer.serialize(request: request, response: response, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)

        if let json = result.value as? NSNull {
            XCTAssertEqual(json, NSNull())
        } else {
            XCTFail("json should not be nil")
        }
    }

    func testThatJSONResponseSerializerSucceedsWhenDataIsNilWithHEADRequestAnd200ResponseStatusCode() {
        // Given
        let serializer = JSONResponseSerializer()
        let request = URLRequest.make(method: .head)
        let response = HTTPURLResponse(statusCode: 200)

        // When
        let result = AFResult { try serializer.serialize(request: request, response: response, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)

        if let json = result.value as? NSNull {
            XCTAssertEqual(json, NSNull())
        } else {
            XCTFail("json should not be nil")
        }
    }
}

// MARK: -

// used by testThatDecodableResponseSerializerSucceedsWhenDataIsNilWithEmptyResponseConformingTypeAndEmptyResponseStatusCode
extension Bool: EmptyResponse {
    public static func emptyValue() -> Bool {
        return true
    }
}

final class DecodableResponseSerializerTests: BaseTestCase {
    private let error = AFError.responseSerializationFailed(reason: .inputDataNilOrZeroLength)

    struct DecodableValue: Decodable, EmptyResponse {
        static func emptyValue() -> DecodableValue {
            return DecodableValue(string: "")
        }

        let string: String
    }

    func testThatDecodableResponseSerializerFailsWhenDataIsNil() {
        // Given
        let serializer = DecodableResponseSerializer<DecodableValue>()

        // When
        let result = AFResult { try serializer.serialize(request: nil, response: nil, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error?.asAFError {
            XCTAssertTrue(error.isInputDataNilOrZeroLength)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatDecodableResponseSerializerFailsWhenDataIsEmpty() {
        // Given
        let serializer = DecodableResponseSerializer<DecodableValue>()

        // When
        let result = AFResult { try serializer.serialize(request: nil, response: nil, data: Data(), error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error?.asAFError {
            XCTAssertTrue(error.isInputDataNilOrZeroLength)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatDecodableResponseSerializerSucceedsWhenDataIsValidJSON() {
        // Given
        let data = Data("{\"string\":\"string\"}".utf8)
        let serializer = DecodableResponseSerializer<DecodableValue>()

        // When
        let result = AFResult { try serializer.serialize(request: nil, response: nil, data: data, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertEqual(result.value?.string, "string")
        XCTAssertNil(result.error)
    }

    func testThatDecodableResponseSerializerFailsWhenDataIsInvalidRepresentation() {
        // Given
        let serializer = DecodableResponseSerializer<DecodableValue>()
        let data = Data("definitely not valid".utf8)

        // When
        let result = AFResult { try serializer.serialize(request: nil, response: nil, data: data, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)
    }

    func testThatDecodableResponseSerializerFailsWhenErrorIsNotNil() {
        // Given
        let serializer = DecodableResponseSerializer<DecodableValue>()

        // When
        let result = AFResult { try serializer.serialize(request: nil, response: nil, data: nil, error: error) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error?.asAFError {
            XCTAssertTrue(error.isInputDataNilOrZeroLength)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatDecodableResponseSerializerFailsWhenDataIsNilWithNonEmptyResponseStatusCode() {
        // Given
        let serializer = DecodableResponseSerializer<DecodableValue>()
        let response = HTTPURLResponse(statusCode: 200)

        // When
        let result = AFResult { try serializer.serialize(request: nil, response: response, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error?.asAFError {
            XCTAssertTrue(error.isInputDataNilOrZeroLength)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatDecodableResponseSerializerSucceedsWhenDataIsNilWithEmptyResponseStatusCode() {
        // Given
        let serializer = DecodableResponseSerializer<DecodableValue>()
        let response = HTTPURLResponse(statusCode: 204)

        // When
        let result = AFResult { try serializer.serialize(request: nil, response: response, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)
    }

   func testThatDecodableResponseSerializerSucceedsWhenDataIsNilWithEmptyTypeAndEmptyResponseStatusCode() {
        // Given
        let serializer = DecodableResponseSerializer<Empty>()
        let response = HTTPURLResponse(statusCode: 204)

        // When
        let result = AFResult { try serializer.serialize(request: nil, response: response, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)
    }

    func testThatDecodableResponseSerializerSucceedsWhenDataIsNilWithGETRequestAnd204ResponseStatusCode() {
        // Given
        let serializer = DecodableResponseSerializer<Empty>()
        let request = URLRequest.make(method: .get)
        let response = HTTPURLResponse(statusCode: 204)

        // When
        let result = AFResult { try serializer.serialize(request: request, response: response, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)
    }

    func testThatDecodableResponseSerializerSucceedsWhenDataIsNilWithGETRequestAnd205ResponseStatusCode() {
        // Given
        let serializer = DecodableResponseSerializer<Empty>()
        let request = URLRequest.make(method: .get)
        let response = HTTPURLResponse(statusCode: 205)

        // When
        let result = AFResult { try serializer.serialize(request: request, response: response, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)
    }

    func testThatDecodableResponseSerializerSucceedsWhenDataIsNilWithHEADRequestAnd200ResponseStatusCode() {
        // Given
        let serializer = DecodableResponseSerializer<Empty>()
        let request = URLRequest.make(method: .head)
        let response = HTTPURLResponse(statusCode: 200)

        // When
        let result = AFResult { try serializer.serialize(request: request, response: response, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)
    }

    func testThatDecodableResponseSerializerSucceedsWhenDataIsNilWithEmptyResponseConformingTypeAndEmptyResponseStatusCode() {
        // Given
        let serializer = DecodableResponseSerializer<Bool>()
        let response = HTTPURLResponse(statusCode: 204)

        // When
        let result = AFResult { try serializer.serialize(request: nil, response: response, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)
    }

    func testThatDecodableResponseSerializerFailsWhenDataIsNilWithEmptyResponseNonconformingTypeAndEmptyResponseStatusCode() {
        // Given
        let serializer = DecodableResponseSerializer<Int>()
        let response = HTTPURLResponse(statusCode: 204)

        // When
        let result = AFResult { try serializer.serialize(request: nil, response: response, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error?.asAFError {
            XCTAssertTrue(error.isInvalidEmptyResponse)
        } else {
            XCTFail("error should not be nil")
        }
    }
}

// MARK: -

final class DownloadResponseSerializationTestCase: BaseTestCase {

    // MARK: Properties

    private let error = AFError.responseSerializationFailed(reason: .inputFileNil)

    private var jsonEmptyDataFileURL: URL { return url(forResource: "empty_data", withExtension: "json") }
    private var jsonValidDataFileURL: URL { return url(forResource: "valid_data", withExtension: "json") }
    private var jsonInvalidDataFileURL: URL { return url(forResource: "invalid_data", withExtension: "json") }

    private var stringEmptyDataFileURL: URL { return url(forResource: "empty_string", withExtension: "txt") }
    private var stringUTF8DataFileURL: URL { return url(forResource: "utf8_string", withExtension: "txt") }
    private var stringUTF32DataFileURL: URL { return url(forResource: "utf32_string", withExtension: "txt") }

    private var invalidFileURL: URL { return URL(fileURLWithPath: "/this/file/does/not/exist.txt") }

    // MARK: Tests - Data Response Serializer

    func testThatDataResponseSerializerSucceedsWhenFileDataIsNotNil() {
        // Given
        let serializer = DataResponseSerializer()

        // When
        let result = AFResult { try serializer.serializeDownload(request: nil, response: nil, fileURL: jsonValidDataFileURL, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)
    }

    func testThatDataResponseSerializerFailsWhenFileDataIsEmpty() {
        // Given
        let serializer = DataResponseSerializer()

        // When
        let result = AFResult { try serializer.serializeDownload(request: nil, response: nil, fileURL: jsonEmptyDataFileURL, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error?.asAFError {
            XCTAssertTrue(error.isInputDataNilOrZeroLength)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatDataResponseSerializerFailsWhenFileURLIsNil() {
        // Given
        let serializer = DataResponseSerializer()

        // When
        let result = AFResult { try serializer.serializeDownload(request: nil, response: nil, fileURL: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error?.asAFError {
            XCTAssertTrue(error.isInputFileNil)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatDataResponseSerializerFailsWhenFileURLIsInvalid() {
        // Given
        let serializer = DataResponseSerializer()

        // When
        let result = AFResult { try serializer.serializeDownload(request: nil, response: nil, fileURL: invalidFileURL, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error?.asAFError {
            XCTAssertTrue(error.isInputFileReadFailed)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatDataResponseSerializerFailsWhenErrorIsNotNil() {
        // Given
        let serializer = DataResponseSerializer()

        // When
        let result = AFResult { try serializer.serializeDownload(request: nil, response: nil, fileURL: nil, error: error) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error?.asAFError {
            XCTAssertTrue(error.isInputFileNil)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatDataResponseSerializerFailsWhenFileURLIsNilWithNonEmptyResponseStatusCode() {
        // Given
        let serializer = DataResponseSerializer()
        let response = HTTPURLResponse(statusCode: 200)

        // When
        let result = AFResult { try serializer.serializeDownload(request: nil, response: response, fileURL: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error?.asAFError {
            XCTAssertTrue(error.isInputFileNil)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatDataResponseSerializerSucceedsWhenDataIsNilWithEmptyResponseStatusCode() {
        // Given
        let serializer = DataResponseSerializer()
        let response = HTTPURLResponse(statusCode: 205)

        // When
        let result = AFResult { try serializer.serializeDownload(request: nil, response: response, fileURL: jsonEmptyDataFileURL, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)

        if let data = result.value {
            XCTAssertEqual(data.count, 0)
        } else {
            XCTFail("data should not be nil")
        }
    }

    // MARK: Tests - String Response Serializer

    func testThatStringResponseSerializerFailsWhenFileURLIsNil() {
        // Given
        let serializer = StringResponseSerializer()

        // When
        let result = AFResult { try serializer.serializeDownload(request: nil, response: nil, fileURL: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error?.asAFError {
            XCTAssertTrue(error.isInputFileNil)
        } else {
            XCTFail("error should not be nil")
        }
    }


    func testThatStringResponseSerializerFailsWhenFileURLIsInvalid() {
        // Given
        let serializer = StringResponseSerializer()

        // When
        let result = AFResult { try serializer.serializeDownload(request: nil, response: nil, fileURL: invalidFileURL, error: nil) }

        // Then
        XCTAssertEqual(result.isSuccess, false)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error?.asAFError {
            XCTAssertTrue(error.isInputFileReadFailed)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatStringResponseSerializerFailsWhenFileDataIsEmpty() {
        // Given
        let serializer = StringResponseSerializer()

        // When
        let result = AFResult { try serializer.serializeDownload(request: nil, response: nil, fileURL: stringEmptyDataFileURL, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error?.asAFError {
            XCTAssertTrue(error.isInputDataNilOrZeroLength)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatStringResponseSerializerSucceedsWithUTF8DataAndNoProvidedEncoding() {
        // Given
        let serializer = StringResponseSerializer()

        // When
        let result = AFResult { try serializer.serializeDownload(request: nil, response: nil, fileURL: stringUTF8DataFileURL, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)
    }

    func testThatStringResponseSerializerSucceedsWithUTF8DataAndUTF8ProvidedEncoding() {
        // Given
        let serializer = StringResponseSerializer(encoding: .utf8)

        // When
        let result = AFResult { try serializer.serializeDownload(request: nil, response: nil, fileURL: stringUTF8DataFileURL, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)
    }

    func testThatStringResponseSerializerSucceedsWithUTF8DataUsingResponseTextEncodingName() {
        // Given
        let serializer = StringResponseSerializer()
        let response = HTTPURLResponse(statusCode: 200, headers: ["Content-Type": "image/jpeg; charset=utf-8"])

        // When
        let result = AFResult { try serializer.serializeDownload(request: nil, response: response, fileURL: stringUTF8DataFileURL, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)
    }

    func testThatStringResponseSerializerFailsWithUTF32DataAndUTF8ProvidedEncoding() {
        // Given
        let serializer = StringResponseSerializer(encoding: .utf8)

        // When
        let result = AFResult { try serializer.serializeDownload(request: nil, response: nil, fileURL: stringUTF32DataFileURL, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error?.asAFError, let failedEncoding = error.failedStringEncoding {
            XCTAssertTrue(error.isStringSerializationFailed)
            XCTAssertEqual(failedEncoding, .utf8)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatStringResponseSerializerFailsWithUTF32DataAndUTF8ResponseEncoding() {
        // Given
        let serializer = StringResponseSerializer()
        let response = HTTPURLResponse(statusCode: 200, headers: ["Content-Type": "image/jpeg; charset=utf-8"])

        // When
        let result = AFResult { try serializer.serializeDownload(request: nil, response: response, fileURL: stringUTF32DataFileURL, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error?.asAFError, let failedEncoding = error.failedStringEncoding {
            XCTAssertTrue(error.isStringSerializationFailed)
            XCTAssertEqual(failedEncoding, .utf8)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatStringResponseSerializerFailsWhenErrorIsNotNil() {
        // Given
        let serializer = StringResponseSerializer()

        // When
        let result = AFResult { try serializer.serializeDownload(request: nil, response: nil, fileURL: nil, error: error) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error?.asAFError {
            XCTAssertTrue(error.isInputFileNil)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatStringResponseSerializerFailsWhenDataIsNilWithNonEmptyResponseStatusCode() {
        // Given
        let serializer = StringResponseSerializer()
        let response = HTTPURLResponse(statusCode: 200)

        // When
        let result = AFResult { try serializer.serializeDownload(request: nil, response: response, fileURL: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error?.asAFError {
            XCTAssertTrue(error.isInputFileNil)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatStringResponseSerializerSucceedsWhenDataIsNilWithEmptyResponseStatusCode() {
        // Given
        let serializer = StringResponseSerializer()
        let response = HTTPURLResponse(statusCode: 204)

        // When
        let result = AFResult { try serializer.serializeDownload(request: nil, response: response, fileURL: stringEmptyDataFileURL, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)

        if let string = result.value {
            XCTAssertEqual(string, "")
        }
    }

    // MARK: Tests - JSON Response Serializer

    func testThatJSONResponseSerializerFailsWhenFileURLIsNil() {
        // Given
        let serializer = JSONResponseSerializer()

        // When
        let result = AFResult { try serializer.serializeDownload(request: nil, response: nil, fileURL: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error?.asAFError {
            XCTAssertTrue(error.isInputFileNil)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatJSONResponseSerializerFailsWhenFileURLIsInvalid() {
        // Given
        let serializer = JSONResponseSerializer()

        // When
        let result = AFResult { try serializer.serializeDownload(request: nil, response: nil, fileURL: invalidFileURL, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error?.asAFError {
            XCTAssertTrue(error.isInputFileReadFailed)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatJSONResponseSerializerFailsWhenFileDataIsEmpty() {
        // Given
        let serializer = JSONResponseSerializer()

        // When
        let result = AFResult { try serializer.serializeDownload(request: nil, response: nil, fileURL: jsonEmptyDataFileURL, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error?.asAFError {
            XCTAssertTrue(error.isInputDataNilOrZeroLength)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatJSONResponseSerializerSucceedsWhenDataIsValidJSON() {
        // Given
        let serializer = JSONResponseSerializer()

        // When
        let result = AFResult { try serializer.serializeDownload(request: nil, response: nil, fileURL: jsonValidDataFileURL, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)
    }

    func testThatJSONResponseSerializerFailsWhenDataIsInvalidJSON() {
        // Given
        let serializer = JSONResponseSerializer()

        // When
        let result = AFResult { try serializer.serializeDownload(request: nil, response: nil, fileURL: jsonInvalidDataFileURL, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error?.asAFError, let underlyingError = error.underlyingError as? CocoaError {
            XCTAssertTrue(error.isJSONSerializationFailed)
            XCTAssertEqual(underlyingError.errorCode, 3840)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatJSONResponseSerializerFailsWhenErrorIsNotNil() {
        // Given
        let serializer = JSONResponseSerializer()

        // When
        let result = AFResult { try serializer.serializeDownload(request: nil, response: nil, fileURL: nil, error: error) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error?.asAFError {
            XCTAssertTrue(error.isInputFileNil)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatJSONResponseSerializerFailsWhenDataIsNilWithNonEmptyResponseStatusCode() {
        // Given
        let serializer = JSONResponseSerializer()
        let response = HTTPURLResponse(statusCode: 200)

        // When
        let result = AFResult { try serializer.serializeDownload(request: nil, response: response, fileURL: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error?.asAFError {
            XCTAssertTrue(error.isInputFileNil)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatJSONResponseSerializerSucceedsWhenDataIsNilWithEmptyResponseStatusCode() {
        // Given
        let serializer = JSONResponseSerializer()
        let response = HTTPURLResponse(statusCode: 205)

        // When
        let result = AFResult { try serializer.serializeDownload(request: nil, response: response, fileURL: jsonEmptyDataFileURL, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)

        if let json = result.value as? NSNull {
            XCTAssertEqual(json, NSNull())
        }
    }
}

final class CustomResponseSerializerTestCases: BaseTestCase {
    func testThatCustomResponseSerializersCanBeWrittenWithoutCompilerIssues() {
        // Given
        final class UselessResponseSerializer: ResponseSerializer {
            func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) throws -> Data? {
                return data
            }
        }
        let serializer = UselessResponseSerializer()
        let expectation = self.expectation(description: "request should finish")
        var data: Data?

        // When
        AF.request(URLRequest.makeHTTPBinRequest()).response(responseSerializer: serializer) { (response) in
            data = response.data
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(data)
    }
}

extension HTTPURLResponse {
    convenience init(statusCode: Int, headers: HTTPHeaders? = nil) {
        let url = URL(string: "https://httpbin.org/get")!
        self.init(url: url, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: headers?.dictionary)!
    }
}
