//
//  ResponseSerializationTests.swift
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
import Foundation
import XCTest

class ResponseSerializationTestCase: BaseTestCase {
    // MARK: - Properties

    let error = AFError.responseSerializationFailed(reason: .inputDataNil)

    // MARK: - Tests - Data Response Serializer

    func testThatDataResponseSerializerSucceedsWhenDataIsNotNil() {
        // Given
        let serializer = DataRequest.dataResponseSerializer()
        let data = "data".data(using: String.Encoding.utf8)!

        // When
        let result = serializer.serializeResponse(nil, nil, data, nil)

        // Then
        XCTAssertTrue(result.isSuccess, "result is success should be true")
        XCTAssertNotNil(result.value, "result value should not be nil")
        XCTAssertNil(result.error, "result error should be nil")
    }

    func testThatDataResponseSerializerFailsWhenDataIsNil() {
        // Given
        let serializer = DataRequest.dataResponseSerializer()

        // When
        let result = serializer.serializeResponse(nil, nil, nil, nil)

        // Then
        XCTAssertTrue(result.isFailure, "result is failure should be true")
        XCTAssertNil(result.value, "result value should be nil")
        XCTAssertNotNil(result.error, "result error should not be nil")

        if let error = result.error as? AFError {
            XCTAssertTrue(error.isInputDataNil)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatDataResponseSerializerFailsWhenErrorIsNotNil() {
        // Given
        let serializer = DataRequest.dataResponseSerializer()

        // When
        let result = serializer.serializeResponse(nil, nil, nil, error)

        // Then
        XCTAssertTrue(result.isFailure, "result is failure should be true")
        XCTAssertNil(result.value, "result value should be nil")
        XCTAssertNotNil(result.error, "result error should not be nil")

        if let error = result.error as? AFError {
            XCTAssertTrue(error.isInputDataNil)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatDataResponseSerializerFailsWhenDataIsNilWithNon204ResponseStatusCode() {
        // Given
        let serializer = DataRequest.dataResponseSerializer()
        let url = URL(string: "https://httpbin.org/get")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)

        // When
        let result = serializer.serializeResponse(nil, response, nil, nil)

        // Then
        XCTAssertTrue(result.isFailure, "result is failure should be true")
        XCTAssertNil(result.value, "result value should be nil")
        XCTAssertNotNil(result.error, "result error should not be nil")

        if let error = result.error as? AFError {
            XCTAssertTrue(error.isInputDataNil)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatDataResponseSerializerSucceedsWhenDataIsNilWith204ResponseStatusCode() {
        // Given
        let serializer = DataRequest.dataResponseSerializer()
        let url = URL(string: "https://httpbin.org/get")!
        let response = HTTPURLResponse(url: url, statusCode: 204, httpVersion: "HTTP/1.1", headerFields: nil)

        // When
        let result = serializer.serializeResponse(nil, response, nil, nil)

        // Then
        XCTAssertTrue(result.isSuccess, "result is success should be true")
        XCTAssertNotNil(result.value, "result value should not be nil")
        XCTAssertNil(result.error, "result error should be nil")

        if let data = result.value {
            XCTAssertEqual(data.count, 0, "data length should be zero")
        }
    }

    // MARK: - Tests - String Response Serializer

    func testThatStringResponseSerializerFailsWhenDataIsNil() {
        // Given
        let serializer = DataRequest.stringResponseSerializer()

        // When
        let result = serializer.serializeResponse(nil, nil, nil, nil)

        // Then
        XCTAssertTrue(result.isFailure, "result is failure should be true")
        XCTAssertNil(result.value, "result value should be nil")
        XCTAssertNotNil(result.error, "result error should not be nil")

        if let error = result.error as? AFError {
            XCTAssertTrue(error.isInputDataNil)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatStringResponseSerializerSucceedsWhenDataIsEmpty() {
        // Given
        let serializer = DataRequest.stringResponseSerializer()

        // When
        let result = serializer.serializeResponse(nil, nil, Data(), nil)

        // Then
        XCTAssertTrue(result.isSuccess, "result is success should be true")
        XCTAssertNotNil(result.value, "result value should not be nil")
        XCTAssertNil(result.error, "result error should be nil")
    }

    func testThatStringResponseSerializerSucceedsWithUTF8DataAndNoProvidedEncoding() {
        let serializer = DataRequest.stringResponseSerializer()
        let data = "data".data(using: String.Encoding.utf8)!

        // When
        let result = serializer.serializeResponse(nil, nil, data, nil)

        // Then
        XCTAssertTrue(result.isSuccess, "result is success should be true")
        XCTAssertNotNil(result.value, "result value should not be nil")
        XCTAssertNil(result.error, "result error should be nil")
    }

    func testThatStringResponseSerializerSucceedsWithUTF8DataAndUTF8ProvidedEncoding() {
        let serializer = DataRequest.stringResponseSerializer(encoding: String.Encoding.utf8)
        let data = "data".data(using: String.Encoding.utf8)!

        // When
        let result = serializer.serializeResponse(nil, nil, data, nil)

        // Then
        XCTAssertTrue(result.isSuccess, "result is success should be true")
        XCTAssertNotNil(result.value, "result value should not be nil")
        XCTAssertNil(result.error, "result error should be nil")
    }

    func testThatStringResponseSerializerSucceedsWithUTF8DataUsingResponseTextEncodingName() {
        let serializer = DataRequest.stringResponseSerializer()
        let data = "data".data(using: String.Encoding.utf8)!
        let response = HTTPURLResponse(
            url: URL(string: "https://httpbin.org/get")!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "image/jpeg; charset=utf-8"]
        )

        // When
        let result = serializer.serializeResponse(nil, response, data, nil)

        // Then
        XCTAssertTrue(result.isSuccess, "result is success should be true")
        XCTAssertNotNil(result.value, "result value should not be nil")
        XCTAssertNil(result.error, "result error should be nil")
    }

    func testThatStringResponseSerializerFailsWithUTF32DataAndUTF8ProvidedEncoding() {
        // Given
        let serializer = DataRequest.stringResponseSerializer(encoding: String.Encoding.utf8)
        let data = "random data".data(using: String.Encoding.utf32)!

        // When
        let result = serializer.serializeResponse(nil, nil, data, nil)

        // Then
        XCTAssertTrue(result.isFailure, "result is failure should be true")
        XCTAssertNil(result.value, "result value should be nil")
        XCTAssertNotNil(result.error, "result error should not be nil")

        if let error = result.error as? AFError, let failedEncoding = error.failedStringEncoding {
            XCTAssertTrue(error.isStringSerializationFailed)
            XCTAssertEqual(failedEncoding, String.Encoding.utf8)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatStringResponseSerializerFailsWithUTF32DataAndUTF8ResponseEncoding() {
        // Given
        let serializer = DataRequest.stringResponseSerializer()
        let data = "random data".data(using: String.Encoding.utf32)!
        let response = HTTPURLResponse(
            url: URL(string: "https://httpbin.org/get")!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "image/jpeg; charset=utf-8"]
        )

        // When
        let result = serializer.serializeResponse(nil, response, data, nil)

        // Then
        XCTAssertTrue(result.isFailure, "result is failure should be true")
        XCTAssertNil(result.value, "result value should be nil")
        XCTAssertNotNil(result.error, "result error should not be nil")

        if let error = result.error as? AFError, let failedEncoding = error.failedStringEncoding {
            XCTAssertTrue(error.isStringSerializationFailed)
            XCTAssertEqual(failedEncoding, String.Encoding.utf8)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatStringResponseSerializerFailsWhenErrorIsNotNil() {
        // Given
        let serializer = DataRequest.stringResponseSerializer()

        // When
        let result = serializer.serializeResponse(nil, nil, nil, error)

        // Then
        XCTAssertTrue(result.isFailure, "result is failure should be true")
        XCTAssertNil(result.value, "result value should be nil")
        XCTAssertNotNil(result.error, "result error should not be nil")

        if let error = result.error as? AFError {
            XCTAssertTrue(error.isInputDataNil)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatStringResponseSerializerFailsWhenDataIsNilWithNon204ResponseStatusCode() {
        // Given
        let serializer = DataRequest.stringResponseSerializer()
        let url = URL(string: "https://httpbin.org/get")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)

        // When
        let result = serializer.serializeResponse(nil, response, nil, nil)

        // Then
        XCTAssertTrue(result.isFailure, "result is failure should be true")
        XCTAssertNil(result.value, "result value should be nil")
        XCTAssertNotNil(result.error, "result error should not be nil")

        if let error = result.error as? AFError {
            XCTAssertTrue(error.isInputDataNil)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatStringResponseSerializerSucceedsWhenDataIsNilWith204ResponseStatusCode() {
        // Given
        let serializer = DataRequest.stringResponseSerializer()
        let url = URL(string: "https://httpbin.org/get")!
        let response = HTTPURLResponse(url: url, statusCode: 204, httpVersion: "HTTP/1.1", headerFields: nil)

        // When
        let result = serializer.serializeResponse(nil, response, nil, nil)

        // Then
        XCTAssertTrue(result.isSuccess, "result is success should be true")
        XCTAssertNotNil(result.value, "result value should not be nil")
        XCTAssertNil(result.error, "result error should be nil")

        if let string = result.value {
            XCTAssertEqual(string, "", "string should be equal to empty string")
        }
    }

    // MARK: - Tests - JSON Response Serializer

    func testThatJSONResponseSerializerFailsWhenDataIsNil() {
        // Given
        let serializer = DataRequest.jsonResponseSerializer()

        // When
        let result = serializer.serializeResponse(nil, nil, nil, nil)

        // Then
        XCTAssertTrue(result.isFailure, "result is failure should be true")
        XCTAssertNil(result.value, "result value should be nil")
        XCTAssertNotNil(result.error, "result error should not be nil")

        if let error = result.error as? AFError {
            XCTAssertTrue(error.isInputDataNilOrZeroLength)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatJSONResponseSerializerFailsWhenDataIsEmpty() {
        // Given
        let serializer = DataRequest.jsonResponseSerializer()

        // When
        let result = serializer.serializeResponse(nil, nil, Data(), nil)

        // Then
        XCTAssertTrue(result.isFailure, "result is failure should be true")
        XCTAssertNil(result.value, "result value should be nil")
        XCTAssertNotNil(result.error, "result error should not be nil")

        if let error = result.error as? AFError {
            XCTAssertTrue(error.isInputDataNilOrZeroLength)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatJSONResponseSerializerSucceedsWhenDataIsValidJSON() {
        // Given
        let serializer = DataRequest.jsonResponseSerializer()
        let data = "{\"json\": true}".data(using: String.Encoding.utf8)!

        // When
        let result = serializer.serializeResponse(nil, nil, data, nil)

        // Then
        XCTAssertTrue(result.isSuccess, "result is success should be true")
        XCTAssertNotNil(result.value, "result value should not be nil")
        XCTAssertNil(result.error, "result error should be nil")
    }

    func testThatJSONResponseSerializerFailsWhenDataIsInvalidJSON() {
        // Given
        let serializer = DataRequest.jsonResponseSerializer()
        let data = "definitely not valid json".data(using: String.Encoding.utf8)!

        // When
        let result = serializer.serializeResponse(nil, nil, data, nil)

        // Then
        XCTAssertTrue(result.isFailure, "result is failure should be true")
        XCTAssertNil(result.value, "result value should be nil")
        XCTAssertNotNil(result.error, "result error should not be nil")

        if let error = result.error as? AFError, let underlyingError = error.underlyingError as? CocoaError {
            XCTAssertTrue(error.isJSONSerializationFailed)
            XCTAssertEqual(underlyingError.errorCode, 3840)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatJSONResponseSerializerFailsWhenErrorIsNotNil() {
        // Given
        let serializer = DataRequest.jsonResponseSerializer()

        // When
        let result = serializer.serializeResponse(nil, nil, nil, error)

        // Then
        XCTAssertTrue(result.isFailure, "result is failure should be true")
        XCTAssertNil(result.value, "result value should be nil")
        XCTAssertNotNil(result.error, "result error should not be nil")

        if let error = result.error as? AFError {
            XCTAssertTrue(error.isInputDataNil)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatJSONResponseSerializerFailsWhenDataIsNilWithNon204ResponseStatusCode() {
        // Given
        let serializer = DataRequest.jsonResponseSerializer()
        let url = URL(string: "https://httpbin.org/get")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)

        // When
        let result = serializer.serializeResponse(nil, response, nil, nil)

        // Then
        XCTAssertTrue(result.isFailure, "result is failure should be true")
        XCTAssertNil(result.value, "result value should be nil")
        XCTAssertNotNil(result.error, "result error should not be nil")

        if let error = result.error as? AFError {
            XCTAssertTrue(error.isInputDataNilOrZeroLength)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatJSONResponseSerializerSucceedsWhenDataIsNilWith204ResponseStatusCode() {
        // Given
        let serializer = DataRequest.jsonResponseSerializer()
        let url = URL(string: "https://httpbin.org/get")!
        let response = HTTPURLResponse(url: url, statusCode: 204, httpVersion: "HTTP/1.1", headerFields: nil)

        // When
        let result = serializer.serializeResponse(nil, response, nil, nil)

        // Then
        XCTAssertTrue(result.isSuccess, "result is success should be true")
        XCTAssertNotNil(result.value, "result value should not be nil")
        XCTAssertNil(result.error, "result error should be nil")

        if let json = result.value as? NSNull {
            XCTAssertEqual(json, NSNull(), "json should be equal to NSNull")
        }
    }

    // MARK: - Tests - Property List Response Serializer

    func testThatPropertyListResponseSerializerFailsWhenDataIsNil() {
        // Given
        let serializer = DataRequest.propertyListResponseSerializer()

        // When
        let result = serializer.serializeResponse(nil, nil, nil, nil)

        // Then
        XCTAssertTrue(result.isFailure, "result is failure should be true")
        XCTAssertNil(result.value, "result value should be nil")
        XCTAssertNotNil(result.error, "result error should not be nil")

        if let error = result.error as? AFError {
            XCTAssertTrue(error.isInputDataNilOrZeroLength)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatPropertyListResponseSerializerFailsWhenDataIsEmpty() {
        // Given
        let serializer = DataRequest.propertyListResponseSerializer()

        // When
        let result = serializer.serializeResponse(nil, nil, Data(), nil)

        // Then
        XCTAssertTrue(result.isFailure, "result is failure should be true")
        XCTAssertNil(result.value, "result value should be nil")
        XCTAssertNotNil(result.error, "result error should not be nil")

        if let error = result.error as? AFError {
            XCTAssertTrue(error.isInputDataNilOrZeroLength)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatPropertyListResponseSerializerSucceedsWhenDataIsValidPropertyListData() {
        // Given
        let serializer = DataRequest.propertyListResponseSerializer()
        let data = NSKeyedArchiver.archivedData(withRootObject: ["foo": "bar"])

        // When
        let result = serializer.serializeResponse(nil, nil, data, nil)

        // Then
        XCTAssertTrue(result.isSuccess, "result is success should be true")
        XCTAssertNotNil(result.value, "result value should not be nil")
        XCTAssertNil(result.error, "result error should be nil")
    }

    func testThatPropertyListResponseSerializerFailsWhenDataIsInvalidPropertyListData() {
        // Given
        let serializer = DataRequest.propertyListResponseSerializer()
        let data = "definitely not valid plist data".data(using: String.Encoding.utf8)!

        // When
        let result = serializer.serializeResponse(nil, nil, data, nil)

        // Then
        XCTAssertTrue(result.isFailure, "result is failure should be true")
        XCTAssertNil(result.value, "result value should be nil")
        XCTAssertNotNil(result.error, "result error should not be nil")

        if let error = result.error as? AFError, let underlyingError = error.underlyingError as? CocoaError {
            XCTAssertTrue(error.isPropertyListSerializationFailed)
            XCTAssertEqual(underlyingError.errorCode, 3840)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatPropertyListResponseSerializerFailsWhenErrorIsNotNil() {
        // Given
        let serializer = DataRequest.propertyListResponseSerializer()

        // When
        let result = serializer.serializeResponse(nil, nil, nil, error)

        // Then
        XCTAssertTrue(result.isFailure, "result is failure should be true")
        XCTAssertNil(result.value, "result value should be nil")
        XCTAssertNotNil(result.error, "result error should not be nil")

        if let error = result.error as? AFError {
            XCTAssertTrue(error.isInputDataNil)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatPropertyListResponseSerializerFailsWhenDataIsNilWithNon204ResponseStatusCode() {
        // Given
        let serializer = DataRequest.propertyListResponseSerializer()
        let url = URL(string: "https://httpbin.org/get")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)

        // When
        let result = serializer.serializeResponse(nil, response, nil, nil)

        // Then
        XCTAssertTrue(result.isFailure, "result is failure should be true")
        XCTAssertNil(result.value, "result value should be nil")
        XCTAssertNotNil(result.error, "result error should not be nil")

        if let error = result.error as? AFError {
            XCTAssertTrue(error.isInputDataNilOrZeroLength)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatPropertyListResponseSerializerSucceedsWhenDataIsNilWith204ResponseStatusCode() {
        // Given
        let serializer = DataRequest.propertyListResponseSerializer()
        let url = URL(string: "https://httpbin.org/get")!
        let response = HTTPURLResponse(url: url, statusCode: 204, httpVersion: "HTTP/1.1", headerFields: nil)

        // When
        let result = serializer.serializeResponse(nil, response, nil, nil)

        // Then
        XCTAssertTrue(result.isSuccess, "result is success should be true")
        XCTAssertNotNil(result.value, "result value should not be nil")
        XCTAssertNil(result.error, "result error should be nil")

        if let plist = result.value as? NSNull {
            XCTAssertEqual(plist, NSNull(), "plist should be equal to NSNull")
        }
    }
}
