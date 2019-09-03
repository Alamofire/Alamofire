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
        let result = Result { try serializer.serialize(request: nil, response: nil, data: data, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.success)
        XCTAssertNil(result.failure)
    }

    func testThatDataResponseSerializerFailsWhenDataIsNil() {
        // Given
        let serializer = DataResponseSerializer()

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.success)
        XCTAssertNotNil(result.failure)
        XCTAssertEqual(result.failure?.asAFError?.isInputDataNilOrZeroLength, true)
    }

    func testThatDataResponseSerializerFailsWhenErrorIsNotNil() {
        // Given
        let serializer = DataResponseSerializer()

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: nil, error: error) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.success)
        XCTAssertNotNil(result.failure)
        XCTAssertEqual(result.failure?.asAFError?.isInputDataNilOrZeroLength, true)
    }

    func testThatDataResponseSerializerFailsWhenDataIsNilWithNonEmptyResponseStatusCode() {
        // Given
        let serializer = DataResponseSerializer()
        let response = HTTPURLResponse(statusCode: 200)

        // When
        let result = Result { try serializer.serialize(request: nil, response: response, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure, "result is failure should be true")
        XCTAssertNil(result.success, "result value should be nil")
        XCTAssertNotNil(result.failure, "result error should not be nil")
        XCTAssertEqual(result.failure?.asAFError?.isInputDataNilOrZeroLength, true)
    }

    func testThatDataResponseSerializerSucceedsWhenDataIsNilWithGETRequestAnd204ResponseStatusCode() {
        // Given
        let serializer = DataResponseSerializer()
        let request = URLRequest.make(method: .get)
        let response = HTTPURLResponse(statusCode: 204)

        // When
        let result = Result { try serializer.serialize(request: request, response: response, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.success)
        XCTAssertNil(result.failure)
        XCTAssertEqual(result.success?.count, 0)
    }

    func testThatDataResponseSerializerSucceedsWhenDataIsNilWithGETRequestAnd205ResponseStatusCode() {
        // Given
        let serializer = DataResponseSerializer()
        let request = URLRequest.make(method: .get)
        let response = HTTPURLResponse(statusCode: 205)

        // When
        let result = Result { try serializer.serialize(request: request, response: response, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.success)
        XCTAssertNil(result.failure)
        XCTAssertEqual(result.success?.count, 0)
    }

    func testThatDataResponseSerializerSucceedsWhenDataIsNilWithHEADRequestAnd200ResponseStatusCode() {
        // Given
        let serializer = DataResponseSerializer()
        let request = URLRequest.make(method: .head)
        let response = HTTPURLResponse(statusCode: 200)

        // When
        let result = Result { try serializer.serialize(request: request, response: response, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.success)
        XCTAssertNil(result.failure)
        XCTAssertEqual(result.success?.count, 0)
    }

    // MARK: StringResponseSerializer

    func testThatStringResponseSerializerFailsWhenDataIsNil() {
        // Given
        let serializer = DataResponseSerializer()

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.success)
        XCTAssertNotNil(result.failure)
        XCTAssertEqual(result.failure?.asAFError?.isInputDataNilOrZeroLength, true)
    }

    func testThatStringResponseSerializerFailsWhenDataIsEmpty() {
        // Given
        let serializer = StringResponseSerializer()

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: Data(), error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.success)
        XCTAssertNotNil(result.failure)
        XCTAssertEqual(result.failure?.asAFError?.isInputDataNilOrZeroLength, true)
    }

    func testThatStringResponseSerializerSucceedsWithUTF8DataAndNoProvidedEncoding() {
        let serializer = StringResponseSerializer()
        let data = Data("data".utf8)

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: data, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.success)
        XCTAssertNil(result.failure)
    }

    func testThatStringResponseSerializerSucceedsWithUTF8DataAndUTF8ProvidedEncoding() {
        let serializer = StringResponseSerializer(encoding: .utf8)
        let data = Data("data".utf8)

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: data, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.success)
        XCTAssertNil(result.failure)
    }

    func testThatStringResponseSerializerSucceedsWithUTF8DataUsingResponseTextEncodingName() {
        let serializer = StringResponseSerializer()
        let data = Data("data".utf8)
        let response = HTTPURLResponse(statusCode: 200, headers: ["Content-Type": "image/jpeg; charset=utf-8"])

        // When
        let result = Result { try serializer.serialize(request: nil, response: response, data: data, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.success)
        XCTAssertNil(result.failure)
    }

    func testThatStringResponseSerializerFailsWithUTF32DataAndUTF8ProvidedEncoding() {
        // Given
        let serializer = StringResponseSerializer(encoding: .utf8)
        let data = "random data".data(using: .utf32)!

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: data, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.success)
        XCTAssertNotNil(result.failure)
        XCTAssertEqual(result.failure?.asAFError?.isStringSerializationFailed, true)
        XCTAssertEqual(result.failure?.asAFError?.failedStringEncoding, .utf8)
    }

    func testThatStringResponseSerializerFailsWithUTF32DataAndUTF8ResponseEncoding() {
        // Given
        let serializer = StringResponseSerializer()
        let data = "random data".data(using: .utf32)!
        let response = HTTPURLResponse(statusCode: 200, headers: ["Content-Type": "image/jpeg; charset=utf-8"])

        // When
        let result = Result { try serializer.serialize(request: nil, response: response, data: data, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.success)
        XCTAssertNotNil(result.failure)
        XCTAssertEqual(result.failure?.asAFError?.isStringSerializationFailed, true)
        XCTAssertEqual(result.failure?.asAFError?.failedStringEncoding, .utf8)
    }

    func testThatStringResponseSerializerFailsWhenErrorIsNotNil() {
        // Given
        let serializer = StringResponseSerializer()

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: nil, error: error) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.success)
        XCTAssertNotNil(result.failure)
        XCTAssertEqual(result.failure?.asAFError?.isInputDataNilOrZeroLength, true)
    }

    func testThatStringResponseSerializerFailsWhenDataIsNilWithNonEmptyResponseStatusCode() {
        // Given
        let serializer = StringResponseSerializer()
        let response = HTTPURLResponse(statusCode: 200)

        // When
        let result = Result { try serializer.serialize(request: nil, response: response, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.success)
        XCTAssertNotNil(result.failure)
        XCTAssertEqual(result.failure?.asAFError?.isInputDataNilOrZeroLength, true)
    }

    func testThatStringResponseSerializerSucceedsWhenDataIsNilWithGETRequestAnd204ResponseStatusCode() {
        // Given
        let serializer = StringResponseSerializer()
        let request = URLRequest.make(method: .get)
        let response = HTTPURLResponse(statusCode: 204)

        // When
        let result = Result { try serializer.serialize(request: request, response: response, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.success)
        XCTAssertNil(result.failure)
        XCTAssertEqual(result.success, "")
    }

    func testThatStringResponseSerializerSucceedsWhenDataIsNilWithGETRequestAnd205ResponseStatusCode() {
        // Given
        let serializer = StringResponseSerializer()
        let request = URLRequest.make(method: .get)
        let response = HTTPURLResponse(statusCode: 205)

        // When
        let result = Result { try serializer.serialize(request: request, response: response, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.success)
        XCTAssertNil(result.failure)
        XCTAssertEqual(result.success, "")
    }

    func testThatStringResponseSerializerSucceedsWhenDataIsNilWithHEADRequestAnd200ResponseStatusCode() {
        // Given
        let serializer = StringResponseSerializer()
        let request = URLRequest.make(method: .head)
        let response = HTTPURLResponse(statusCode: 200)

        // When
        let result = Result { try serializer.serialize(request: request, response: response, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.success)
        XCTAssertNil(result.failure)
        XCTAssertEqual(result.success, "")
    }

    // MARK: JSONResponseSerializer

    func testThatJSONResponseSerializerFailsWhenDataIsNil() {
        // Given
        let serializer = JSONResponseSerializer()

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.success)
        XCTAssertNotNil(result.failure)
        XCTAssertEqual(result.failure?.asAFError?.isInputDataNilOrZeroLength, true)
    }

    func testThatJSONResponseSerializerFailsWhenDataIsEmpty() {
        // Given
        let serializer = JSONResponseSerializer()

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: Data(), error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.success)
        XCTAssertNotNil(result.failure)
        XCTAssertEqual(result.failure?.asAFError?.isInputDataNilOrZeroLength, true)
    }

    func testThatJSONResponseSerializerSucceedsWhenDataIsValidJSON() {
        // Given
        let serializer = JSONResponseSerializer()
        let data = Data("{\"json\": true}".utf8)

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: data, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.success)
        XCTAssertNil(result.failure)
    }

    func testThatJSONResponseSerializerFailsWhenDataIsInvalidJSON() {
        // Given
        let serializer = JSONResponseSerializer()
        let data = Data("definitely not valid json".utf8)

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: data, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.success)
        XCTAssertNotNil(result.failure)
        XCTAssertEqual(result.failure?.asAFError?.isJSONSerializationFailed, true)
        XCTAssertEqual((result.failure?.asAFError?.underlyingError as? CocoaError)?.code, .propertyListReadCorrupt)
    }

    func testThatJSONResponseSerializerFailsWhenErrorIsNotNil() {
        // Given
        let serializer = JSONResponseSerializer()

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: nil, error: error) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.success)
        XCTAssertNotNil(result.failure)
        XCTAssertEqual(result.failure?.asAFError?.isInputDataNilOrZeroLength, true)
    }

    func testThatJSONResponseSerializerFailsWhenDataIsNilWithNonEmptyResponseStatusCode() {
        // Given
        let serializer = JSONResponseSerializer()
        let response = HTTPURLResponse(statusCode: 200)

        // When
        let result = Result { try serializer.serialize(request: nil, response: response, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.success)
        XCTAssertNotNil(result.failure)
        XCTAssertEqual(result.failure?.asAFError?.isInputDataNilOrZeroLength, true)
    }

    func testThatJSONResponseSerializerSucceedsWhenDataIsNilWithGETRequestAnd204ResponseStatusCode() {
        // Given
        let serializer = JSONResponseSerializer()
        let request = URLRequest.make(method: .get)
        let response = HTTPURLResponse(statusCode: 204)

        // When
        let result = Result { try serializer.serialize(request: request, response: response, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.success)
        XCTAssertNil(result.failure)
        XCTAssertEqual(result.success as? NSNull, NSNull())
    }

    func testThatJSONResponseSerializerSucceedsWhenDataIsNilWithGETRequestAnd205ResponseStatusCode() {
        // Given
        let serializer = JSONResponseSerializer()
        let request = URLRequest.make(method: .get)
        let response = HTTPURLResponse(statusCode: 205)

        // When
        let result = Result { try serializer.serialize(request: request, response: response, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.success)
        XCTAssertNil(result.failure)
        XCTAssertEqual(result.success as? NSNull, NSNull())
    }

    func testThatJSONResponseSerializerSucceedsWhenDataIsNilWithHEADRequestAnd200ResponseStatusCode() {
        // Given
        let serializer = JSONResponseSerializer()
        let request = URLRequest.make(method: .head)
        let response = HTTPURLResponse(statusCode: 200)

        // When
        let result = Result { try serializer.serialize(request: request, response: response, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.success)
        XCTAssertNil(result.failure)
        XCTAssertEqual(result.success as? NSNull, NSNull())
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
        let result = Result { try serializer.serialize(request: nil, response: nil, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.success)
        XCTAssertNotNil(result.failure)
        XCTAssertEqual(result.failure?.asAFError?.isInputDataNilOrZeroLength, true)
    }

    func testThatDecodableResponseSerializerFailsWhenDataIsEmpty() {
        // Given
        let serializer = DecodableResponseSerializer<DecodableValue>()

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: Data(), error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.success)
        XCTAssertNotNil(result.failure)
        XCTAssertEqual(result.failure?.asAFError?.isInputDataNilOrZeroLength, true)
    }

    func testThatDecodableResponseSerializerSucceedsWhenDataIsValidJSON() {
        // Given
        let data = Data("{\"string\":\"string\"}".utf8)
        let serializer = DecodableResponseSerializer<DecodableValue>()

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: data, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.success)
        XCTAssertEqual(result.success?.string, "string")
        XCTAssertNil(result.failure)
    }

    func testThatDecodableResponseSerializerFailsWhenDataIsInvalidRepresentation() {
        // Given
        let serializer = DecodableResponseSerializer<DecodableValue>()
        let data = Data("definitely not valid".utf8)

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: data, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.success)
        XCTAssertNotNil(result.failure)
    }

    func testThatDecodableResponseSerializerFailsWhenErrorIsNotNil() {
        // Given
        let serializer = DecodableResponseSerializer<DecodableValue>()

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: nil, error: error) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.success)
        XCTAssertNotNil(result.failure)
        XCTAssertEqual(result.failure?.asAFError?.isInputDataNilOrZeroLength, true)
    }

    func testThatDecodableResponseSerializerFailsWhenDataIsNilWithNonEmptyResponseStatusCode() {
        // Given
        let serializer = DecodableResponseSerializer<DecodableValue>()
        let response = HTTPURLResponse(statusCode: 200)

        // When
        let result = Result { try serializer.serialize(request: nil, response: response, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.success)
        XCTAssertNotNil(result.failure)
        XCTAssertEqual(result.failure?.asAFError?.isInputDataNilOrZeroLength, true)
    }

    func testThatDecodableResponseSerializerSucceedsWhenDataIsNilWithEmptyResponseStatusCode() {
        // Given
        let serializer = DecodableResponseSerializer<DecodableValue>()
        let response = HTTPURLResponse(statusCode: 204)

        // When
        let result = Result { try serializer.serialize(request: nil, response: response, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.success)
        XCTAssertNil(result.failure)
    }

    func testThatDecodableResponseSerializerSucceedsWhenDataIsNilWithEmptyTypeAndEmptyResponseStatusCode() {
        // Given
        let serializer = DecodableResponseSerializer<Empty>()
        let response = HTTPURLResponse(statusCode: 204)

        // When
        let result = Result { try serializer.serialize(request: nil, response: response, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.success)
        XCTAssertNil(result.failure)
    }

    func testThatDecodableResponseSerializerSucceedsWhenDataIsNilWithGETRequestAnd204ResponseStatusCode() {
        // Given
        let serializer = DecodableResponseSerializer<Empty>()
        let request = URLRequest.make(method: .get)
        let response = HTTPURLResponse(statusCode: 204)

        // When
        let result = Result { try serializer.serialize(request: request, response: response, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.success)
        XCTAssertNil(result.failure)
    }

    func testThatDecodableResponseSerializerSucceedsWhenDataIsNilWithGETRequestAnd205ResponseStatusCode() {
        // Given
        let serializer = DecodableResponseSerializer<Empty>()
        let request = URLRequest.make(method: .get)
        let response = HTTPURLResponse(statusCode: 205)

        // When
        let result = Result { try serializer.serialize(request: request, response: response, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.success)
        XCTAssertNil(result.failure)
    }

    func testThatDecodableResponseSerializerSucceedsWhenDataIsNilWithHEADRequestAnd200ResponseStatusCode() {
        // Given
        let serializer = DecodableResponseSerializer<Empty>()
        let request = URLRequest.make(method: .head)
        let response = HTTPURLResponse(statusCode: 200)

        // When
        let result = Result { try serializer.serialize(request: request, response: response, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.success)
        XCTAssertNil(result.failure)
    }

    func testThatDecodableResponseSerializerSucceedsWhenDataIsNilWithEmptyResponseConformingTypeAndEmptyResponseStatusCode() {
        // Given
        let serializer = DecodableResponseSerializer<Bool>()
        let response = HTTPURLResponse(statusCode: 204)

        // When
        let result = Result { try serializer.serialize(request: nil, response: response, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.success)
        XCTAssertNil(result.failure)
    }

    func testThatDecodableResponseSerializerFailsWhenDataIsNilWithEmptyResponseNonconformingTypeAndEmptyResponseStatusCode() {
        // Given
        let serializer = DecodableResponseSerializer<Int>()
        let response = HTTPURLResponse(statusCode: 204)

        // When
        let result = Result { try serializer.serialize(request: nil, response: response, data: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.success)
        XCTAssertNotNil(result.failure)
        XCTAssertEqual(result.failure?.asAFError?.isInvalidEmptyResponse, true)
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
        let result = Result { try serializer.serializeDownload(request: nil, response: nil, fileURL: jsonValidDataFileURL, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.success)
        XCTAssertNil(result.failure)
    }

    func testThatDataResponseSerializerFailsWhenFileDataIsEmpty() {
        // Given
        let serializer = DataResponseSerializer()

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: nil, fileURL: jsonEmptyDataFileURL, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.success)
        XCTAssertNotNil(result.failure)
        XCTAssertEqual(result.failure?.asAFError?.isInputDataNilOrZeroLength, true)
    }

    func testThatDataResponseSerializerFailsWhenFileURLIsNil() {
        // Given
        let serializer = DataResponseSerializer()

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: nil, fileURL: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.success)
        XCTAssertNotNil(result.failure)
        XCTAssertEqual(result.failure?.asAFError?.isInputFileNil, true)
    }

    func testThatDataResponseSerializerFailsWhenFileURLIsInvalid() {
        // Given
        let serializer = DataResponseSerializer()

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: nil, fileURL: invalidFileURL, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.success)
        XCTAssertNotNil(result.failure)
        XCTAssertEqual(result.failure?.asAFError?.isInputFileReadFailed, true)
    }

    func testThatDataResponseSerializerFailsWhenErrorIsNotNil() {
        // Given
        let serializer = DataResponseSerializer()

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: nil, fileURL: nil, error: error) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.success)
        XCTAssertNotNil(result.failure)
        XCTAssertEqual(result.failure?.asAFError?.isInputFileNil, true)
    }

    func testThatDataResponseSerializerFailsWhenFileURLIsNilWithNonEmptyResponseStatusCode() {
        // Given
        let serializer = DataResponseSerializer()
        let response = HTTPURLResponse(statusCode: 200)

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: response, fileURL: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.success)
        XCTAssertNotNil(result.failure)
        XCTAssertEqual(result.failure?.asAFError?.isInputFileNil, true)
    }

    func testThatDataResponseSerializerSucceedsWhenDataIsNilWithEmptyResponseStatusCode() {
        // Given
        let serializer = DataResponseSerializer()
        let response = HTTPURLResponse(statusCode: 205)

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: response, fileURL: jsonEmptyDataFileURL, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.success)
        XCTAssertNil(result.failure)
        XCTAssertEqual(result.success?.count, 0)
    }

    // MARK: Tests - String Response Serializer

    func testThatStringResponseSerializerFailsWhenFileURLIsNil() {
        // Given
        let serializer = StringResponseSerializer()

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: nil, fileURL: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.success)
        XCTAssertNotNil(result.failure)
        XCTAssertEqual(result.failure?.asAFError?.isInputFileNil, true)
    }

    func testThatStringResponseSerializerFailsWhenFileURLIsInvalid() {
        // Given
        let serializer = StringResponseSerializer()

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: nil, fileURL: invalidFileURL, error: nil) }

        // Then
        XCTAssertEqual(result.isSuccess, false)
        XCTAssertNil(result.success)
        XCTAssertNotNil(result.failure)
        XCTAssertEqual(result.failure?.asAFError?.isInputFileReadFailed, true)
    }

    func testThatStringResponseSerializerFailsWhenFileDataIsEmpty() {
        // Given
        let serializer = StringResponseSerializer()

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: nil, fileURL: stringEmptyDataFileURL, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.success)
        XCTAssertNotNil(result.failure)
        XCTAssertEqual(result.failure?.asAFError?.isInputDataNilOrZeroLength, true)
    }

    func testThatStringResponseSerializerSucceedsWithUTF8DataAndNoProvidedEncoding() {
        // Given
        let serializer = StringResponseSerializer()

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: nil, fileURL: stringUTF8DataFileURL, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.success)
        XCTAssertNil(result.failure)
    }

    func testThatStringResponseSerializerSucceedsWithUTF8DataAndUTF8ProvidedEncoding() {
        // Given
        let serializer = StringResponseSerializer(encoding: .utf8)

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: nil, fileURL: stringUTF8DataFileURL, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.success)
        XCTAssertNil(result.failure)
    }

    func testThatStringResponseSerializerSucceedsWithUTF8DataUsingResponseTextEncodingName() {
        // Given
        let serializer = StringResponseSerializer()
        let response = HTTPURLResponse(statusCode: 200, headers: ["Content-Type": "image/jpeg; charset=utf-8"])

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: response, fileURL: stringUTF8DataFileURL, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.success)
        XCTAssertNil(result.failure)
    }

    func testThatStringResponseSerializerFailsWithUTF32DataAndUTF8ProvidedEncoding() {
        // Given
        let serializer = StringResponseSerializer(encoding: .utf8)

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: nil, fileURL: stringUTF32DataFileURL, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.success)
        XCTAssertNotNil(result.failure)
        XCTAssertEqual(result.failure?.asAFError?.isStringSerializationFailed, true)
        XCTAssertEqual(result.failure?.asAFError?.failedStringEncoding, .utf8)
    }

    func testThatStringResponseSerializerFailsWithUTF32DataAndUTF8ResponseEncoding() {
        // Given
        let serializer = StringResponseSerializer()
        let response = HTTPURLResponse(statusCode: 200, headers: ["Content-Type": "image/jpeg; charset=utf-8"])

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: response, fileURL: stringUTF32DataFileURL, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.success)
        XCTAssertNotNil(result.failure)
        XCTAssertEqual(result.failure?.asAFError?.isStringSerializationFailed, true)
        XCTAssertEqual(result.failure?.asAFError?.failedStringEncoding, .utf8)
    }

    func testThatStringResponseSerializerFailsWhenErrorIsNotNil() {
        // Given
        let serializer = StringResponseSerializer()

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: nil, fileURL: nil, error: error) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.success)
        XCTAssertNotNil(result.failure)
        XCTAssertEqual(result.failure?.asAFError?.isInputFileNil, true)
    }

    func testThatStringResponseSerializerFailsWhenDataIsNilWithNonEmptyResponseStatusCode() {
        // Given
        let serializer = StringResponseSerializer()
        let response = HTTPURLResponse(statusCode: 200)

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: response, fileURL: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.success)
        XCTAssertNotNil(result.failure)
        XCTAssertEqual(result.failure?.asAFError?.isInputFileNil, true)
    }

    func testThatStringResponseSerializerSucceedsWhenDataIsNilWithEmptyResponseStatusCode() {
        // Given
        let serializer = StringResponseSerializer()
        let response = HTTPURLResponse(statusCode: 204)

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: response, fileURL: stringEmptyDataFileURL, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.success)
        XCTAssertNil(result.failure)
        XCTAssertEqual(result.success, "")
    }

    // MARK: Tests - JSON Response Serializer

    func testThatJSONResponseSerializerFailsWhenFileURLIsNil() {
        // Given
        let serializer = JSONResponseSerializer()

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: nil, fileURL: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.success)
        XCTAssertNotNil(result.failure)
        XCTAssertEqual(result.failure?.asAFError?.isInputFileNil, true)
    }

    func testThatJSONResponseSerializerFailsWhenFileURLIsInvalid() {
        // Given
        let serializer = JSONResponseSerializer()

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: nil, fileURL: invalidFileURL, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.success)
        XCTAssertNotNil(result.failure)
        XCTAssertEqual(result.failure?.asAFError?.isInputFileReadFailed, true)
    }

    func testThatJSONResponseSerializerFailsWhenFileDataIsEmpty() {
        // Given
        let serializer = JSONResponseSerializer()

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: nil, fileURL: jsonEmptyDataFileURL, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.success)
        XCTAssertNotNil(result.failure)
        XCTAssertEqual(result.failure?.asAFError?.isInputDataNilOrZeroLength, true)
    }

    func testThatJSONResponseSerializerSucceedsWhenDataIsValidJSON() {
        // Given
        let serializer = JSONResponseSerializer()

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: nil, fileURL: jsonValidDataFileURL, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.success)
        XCTAssertNil(result.failure)
    }

    func testThatJSONResponseSerializerFailsWhenDataIsInvalidJSON() {
        // Given
        let serializer = JSONResponseSerializer()

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: nil, fileURL: jsonInvalidDataFileURL, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.success)
        XCTAssertNotNil(result.failure)
        XCTAssertEqual(result.failure?.asAFError?.isJSONSerializationFailed, true)
        XCTAssertEqual((result.failure?.asAFError?.underlyingError as? CocoaError)?.code, .propertyListReadCorrupt)
    }

    func testThatJSONResponseSerializerFailsWhenErrorIsNotNil() {
        // Given
        let serializer = JSONResponseSerializer()

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: nil, fileURL: nil, error: error) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.success)
        XCTAssertNotNil(result.failure)
        XCTAssertEqual(result.failure?.asAFError?.isInputFileNil, true)
    }

    func testThatJSONResponseSerializerFailsWhenDataIsNilWithNonEmptyResponseStatusCode() {
        // Given
        let serializer = JSONResponseSerializer()
        let response = HTTPURLResponse(statusCode: 200)

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: response, fileURL: nil, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.success)
        XCTAssertNotNil(result.failure)
        XCTAssertEqual(result.failure?.asAFError?.isInputFileNil, true)
    }

    func testThatJSONResponseSerializerSucceedsWhenDataIsNilWithEmptyResponseStatusCode() {
        // Given
        let serializer = JSONResponseSerializer()
        let response = HTTPURLResponse(statusCode: 205)

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: response, fileURL: jsonEmptyDataFileURL, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.success)
        XCTAssertNil(result.failure)

        XCTAssertEqual(result.success as? NSNull, NSNull())
    }
}

final class CustomResponseSerializerTests: BaseTestCase {
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
        AF.request(URLRequest.makeHTTPBinRequest()).response(responseSerializer: serializer) { response in
            data = response.data
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(data)
    }
}

final class DataPreprocessorSerializationTests: BaseTestCase {
    struct DropFirst: DataPreprocessor {
        func preprocess(_ data: Data) throws -> Data {
            return data.dropFirst()
        }
    }

    struct Throwing: DataPreprocessor {
        struct Error: Swift.Error {}

        func preprocess(_ data: Data) throws -> Data {
            throw Error()
        }
    }

    func testThatDataResponseSerializerProperlyCallsSuccessfulDataPreprocessor() {
        // Given
        let preprocessor = DropFirst()
        let serializer = DataResponseSerializer(dataPreprocessor: preprocessor)
        let data = Data("abcd".utf8)

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: data, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(result.success, Data("bcd".utf8))
        XCTAssertNil(result.failure)
    }

    func testThatDataResponseSerializerProperlyReceivesErrorFromFailingDataPreprocessor() {
        // Given
        let preprocessor = Throwing()
        let serializer = DataResponseSerializer(dataPreprocessor: preprocessor)
        let data = Data("abcd".utf8)

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: data, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.success)
        XCTAssertNotNil(result.failure)
    }

    func testThatStringResponseSerializerProperlyCallsSuccessfulDataPreprocessor() {
        // Given
        let preprocessor = DropFirst()
        let serializer = StringResponseSerializer(dataPreprocessor: preprocessor)
        let data = Data("abcd".utf8)

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: data, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(result.success, "bcd")
        XCTAssertNil(result.failure)
    }

    func testThatStringResponseSerializerProperlyReceivesErrorFromFailingDataPreprocessor() {
        // Given
        let preprocessor = Throwing()
        let serializer = StringResponseSerializer(dataPreprocessor: preprocessor)
        let data = Data("abcd".utf8)

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: data, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.success)
        XCTAssertNotNil(result.failure)
    }

    func testThatJSONResponseSerializerProperlyCallsSuccessfulDataPreprocessor() {
        // Given
        let preprocessor = DropFirst()
        let serializer = JSONResponseSerializer(dataPreprocessor: preprocessor)
        let data = Data("1\"abcd\"".utf8)

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: data, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(result.success as? String, "abcd")
        XCTAssertNil(result.failure)
    }

    func testThatJSONResponseSerializerProperlyReceivesErrorFromFailingDataPreprocessor() {
        // Given
        let preprocessor = Throwing()
        let serializer = JSONResponseSerializer(dataPreprocessor: preprocessor)
        let data = Data("1\"abcd\"".utf8)

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: data, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.success)
        XCTAssertNotNil(result.failure)
    }

    func testThatDecodableResponseSerializerProperlyCallsSuccessfulDataPreprocessor() {
        // Given
        let preprocessor = DropFirst()
        let serializer = DecodableResponseSerializer<DecodableResponseSerializerTests.DecodableValue>(dataPreprocessor: preprocessor)
        let data = Data("1{\"string\":\"string\"}".utf8)

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: data, error: nil) }

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(result.success?.string, "string")
        XCTAssertNil(result.failure)
    }

    func testThatDecodableResponseSerializerProperlyReceivesErrorFromFailingDataPreprocessor() {
        // Given
        let preprocessor = Throwing()
        let serializer = DecodableResponseSerializer<DecodableResponseSerializerTests.DecodableValue>(dataPreprocessor: preprocessor)
        let data = Data("1{\"string\":\"string\"}".utf8)

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: data, error: nil) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.success)
        XCTAssertNotNil(result.failure)
    }
}

final class DataPreprocessorTests: BaseTestCase {
    func testThatPassthroughPreprocessorPassesDataThrough() {
        // Given
        let preprocessor = PassthroughPreprocessor()
        let data = Data("data".utf8)

        // When
        let result = Result { try preprocessor.preprocess(data) }

        // Then
        XCTAssertEqual(data, result.success, "Preprocessed data should equal original data.")
    }

    func testThatGoogleXSSIPreprocessorProperlyPreprocessesData() {
        // Given
        let preprocessor = GoogleXSSIPreprocessor()
        let data = Data(")]}',\nabcd".utf8)

        // When
        let result = Result { try preprocessor.preprocess(data) }

        // Then
        XCTAssertEqual(result.success.map { String(decoding: $0, as: UTF8.self) }, "abcd")
    }

    func testThatGoogleXSSIPreprocessorDoesNotChangeDataIfPrefixDoesNotMatch() {
        // Given
        let preprocessor = GoogleXSSIPreprocessor()
        let data = Data("abcd".utf8)

        // When
        let result = Result { try preprocessor.preprocess(data) }

        // Then
        XCTAssertEqual(result.success.map { String(decoding: $0, as: UTF8.self) }, "abcd")
    }
}

extension HTTPURLResponse {
    convenience init(statusCode: Int, headers: HTTPHeaders? = nil) {
        let url = URL(string: "https://httpbin.org/get")!
        self.init(url: url, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: headers?.dictionary)!
    }
}
