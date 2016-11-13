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

private func httpURLResponse(forStatusCode statusCode: Int, headers: HTTPHeaders = [:]) -> HTTPURLResponse {
    let url = URL(string: "https://httpbin.org/get")!
    return HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: headers)!
}

// MARK: -

class DataResponseSerializationTestCase: BaseTestCase {

    // MARK: Properties

    private let error = AFError.responseSerializationFailed(reason: .inputDataNil)

    // MARK: Tests - Data Response Serializer

    func testThatDataResponseSerializerSucceedsWhenDataIsNotNil() {
        // Given
        let serializer = DataRequest.dataResponseSerializer()
        let data = "data".data(using: .utf8)!

        // When
        let result = serializer.serializeResponse(nil, nil, data, nil)

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)
    }

    func testThatDataResponseSerializerFailsWhenDataIsNil() {
        // Given
        let serializer = DataRequest.dataResponseSerializer()

        // When
        let result = serializer.serializeResponse(nil, nil, nil, nil)

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

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
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error as? AFError {
            XCTAssertTrue(error.isInputDataNil)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatDataResponseSerializerFailsWhenDataIsNilWithNonEmptyResponseStatusCode() {
        // Given
        let serializer = DataRequest.dataResponseSerializer()
        let response = httpURLResponse(forStatusCode: 200)

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

    func testThatDataResponseSerializerSucceedsWhenDataIsNilWithEmptyResponseStatusCode() {
        // Given
        let serializer = DataRequest.dataResponseSerializer()
        let response = httpURLResponse(forStatusCode: 204)

        // When
        let result = serializer.serializeResponse(nil, response, nil, nil)

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)

        if let data = result.value {
            XCTAssertEqual(data.count, 0)
        }
    }

    // MARK: Tests - String Response Serializer

    func testThatStringResponseSerializerFailsWhenDataIsNil() {
        // Given
        let serializer = DataRequest.stringResponseSerializer()

        // When
        let result = serializer.serializeResponse(nil, nil, nil, nil)

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

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
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)
    }

    func testThatStringResponseSerializerSucceedsWithUTF8DataAndNoProvidedEncoding() {
        let serializer = DataRequest.stringResponseSerializer()
        let data = "data".data(using: .utf8)!

        // When
        let result = serializer.serializeResponse(nil, nil, data, nil)

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)
    }

    func testThatStringResponseSerializerSucceedsWithUTF8DataAndUTF8ProvidedEncoding() {
        let serializer = DataRequest.stringResponseSerializer(encoding: .utf8)
        let data = "data".data(using: .utf8)!

        // When
        let result = serializer.serializeResponse(nil, nil, data, nil)

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)
    }

    func testThatStringResponseSerializerSucceedsWithUTF8DataUsingResponseTextEncodingName() {
        let serializer = DataRequest.stringResponseSerializer()
        let data = "data".data(using: .utf8)!
        let response = httpURLResponse(forStatusCode: 200, headers: ["Content-Type": "image/jpeg; charset=utf-8"])

        // When
        let result = serializer.serializeResponse(nil, response, data, nil)

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)
    }

    func testThatStringResponseSerializerFailsWithUTF32DataAndUTF8ProvidedEncoding() {
        // Given
        let serializer = DataRequest.stringResponseSerializer(encoding: .utf8)
        let data = "random data".data(using: .utf32)!

        // When
        let result = serializer.serializeResponse(nil, nil, data, nil)

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error as? AFError, let failedEncoding = error.failedStringEncoding {
            XCTAssertTrue(error.isStringSerializationFailed)
            XCTAssertEqual(failedEncoding, .utf8)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatStringResponseSerializerFailsWithUTF32DataAndUTF8ResponseEncoding() {
        // Given
        let serializer = DataRequest.stringResponseSerializer()
        let data = "random data".data(using: .utf32)!
        let response = httpURLResponse(forStatusCode: 200, headers: ["Content-Type": "image/jpeg; charset=utf-8"])

        // When
        let result = serializer.serializeResponse(nil, response, data, nil)

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error as? AFError, let failedEncoding = error.failedStringEncoding {
            XCTAssertTrue(error.isStringSerializationFailed)
            XCTAssertEqual(failedEncoding, .utf8)
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
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error as? AFError {
            XCTAssertTrue(error.isInputDataNil)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatStringResponseSerializerFailsWhenDataIsNilWithNonEmptyResponseStatusCode() {
        // Given
        let serializer = DataRequest.stringResponseSerializer()
        let response = httpURLResponse(forStatusCode: 200)

        // When
        let result = serializer.serializeResponse(nil, response, nil, nil)

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error as? AFError {
            XCTAssertTrue(error.isInputDataNil)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatStringResponseSerializerSucceedsWhenDataIsNilWithEmptyResponseStatusCode() {
        // Given
        let serializer = DataRequest.stringResponseSerializer()
        let response = httpURLResponse(forStatusCode: 205)

        // When
        let result = serializer.serializeResponse(nil, response, nil, nil)

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)

        if let string = result.value {
            XCTAssertEqual(string, "")
        }
    }

    // MARK: Tests - JSON Response Serializer

    func testThatJSONResponseSerializerFailsWhenDataIsNil() {
        // Given
        let serializer = DataRequest.jsonResponseSerializer()

        // When
        let result = serializer.serializeResponse(nil, nil, nil, nil)

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

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
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error as? AFError {
            XCTAssertTrue(error.isInputDataNilOrZeroLength)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatJSONResponseSerializerSucceedsWhenDataIsValidJSON() {
        // Given
        let serializer = DataRequest.jsonResponseSerializer()
        let data = "{\"json\": true}".data(using: .utf8)!

        // When
        let result = serializer.serializeResponse(nil, nil, data, nil)

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)
    }

    func testThatJSONResponseSerializerFailsWhenDataIsInvalidJSON() {
        // Given
        let serializer = DataRequest.jsonResponseSerializer()
        let data = "definitely not valid json".data(using: .utf8)!

        // When
        let result = serializer.serializeResponse(nil, nil, data, nil)

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

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
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error as? AFError {
            XCTAssertTrue(error.isInputDataNil)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatJSONResponseSerializerFailsWhenDataIsNilWithNonEmptyResponseStatusCode() {
        // Given
        let serializer = DataRequest.jsonResponseSerializer()
        let response = httpURLResponse(forStatusCode: 200)

        // When
        let result = serializer.serializeResponse(nil, response, nil, nil)

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error as? AFError {
            XCTAssertTrue(error.isInputDataNilOrZeroLength)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatJSONResponseSerializerSucceedsWhenDataIsNilWithEmptyResponseStatusCode() {
        // Given
        let serializer = DataRequest.jsonResponseSerializer()
        let response = httpURLResponse(forStatusCode: 204)

        // When
        let result = serializer.serializeResponse(nil, response, nil, nil)

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)

        if let json = result.value as? NSNull {
            XCTAssertEqual(json, NSNull())
        }
    }

    // MARK: Tests - Property List Response Serializer

    func testThatPropertyListResponseSerializerFailsWhenDataIsNil() {
        // Given
        let serializer = DataRequest.propertyListResponseSerializer()

        // When
        let result = serializer.serializeResponse(nil, nil, nil, nil)

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

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
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

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
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)
    }

    func testThatPropertyListResponseSerializerFailsWhenDataIsInvalidPropertyListData() {
        // Given
        let serializer = DataRequest.propertyListResponseSerializer()
        let data = "definitely not valid plist data".data(using: .utf8)!

        // When
        let result = serializer.serializeResponse(nil, nil, data, nil)

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

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
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error as? AFError {
            XCTAssertTrue(error.isInputDataNil)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatPropertyListResponseSerializerFailsWhenDataIsNilWithNonEmptyResponseStatusCode() {
        // Given
        let serializer = DataRequest.propertyListResponseSerializer()
        let response = httpURLResponse(forStatusCode: 200)

        // When
        let result = serializer.serializeResponse(nil, response, nil, nil)

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error as? AFError {
            XCTAssertTrue(error.isInputDataNilOrZeroLength)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatPropertyListResponseSerializerSucceedsWhenDataIsNilWithEmptyResponseStatusCode() {
        // Given
        let serializer = DataRequest.propertyListResponseSerializer()
        let response = httpURLResponse(forStatusCode: 205)

        // When
        let result = serializer.serializeResponse(nil, response, nil, nil)

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)

        if let plist = result.value as? NSNull {
            XCTAssertEqual(plist, NSNull())
        }
    }
}

// MARK: -

class DownloadResponseSerializationTestCase: BaseTestCase {

    // MARK: Properties

    private let error = AFError.responseSerializationFailed(reason: .inputFileNil)

    private var jsonEmptyDataFileURL: URL { return url(forResource: "empty_data", withExtension: "json") }
    private var jsonValidDataFileURL: URL { return url(forResource: "valid_data", withExtension: "json") }
    private var jsonInvalidDataFileURL: URL { return url(forResource: "invalid_data", withExtension: "json") }

    private var plistEmptyDataFileURL: URL { return url(forResource: "empty", withExtension: "data") }
    private var plistValidDataFileURL: URL { return url(forResource: "valid", withExtension: "data") }
    private var plistInvalidDataFileURL: URL { return url(forResource: "invalid", withExtension: "data") }

    private var stringEmptyDataFileURL: URL { return url(forResource: "empty_string", withExtension: "txt") }
    private var stringUTF8DataFileURL: URL { return url(forResource: "utf8_string", withExtension: "txt") }
    private var stringUTF32DataFileURL: URL { return url(forResource: "utf32_string", withExtension: "txt") }

    private var invalidFileURL: URL { return URL(fileURLWithPath: "/this/file/does/not/exist.txt") }

    // MARK: Tests - Data Response Serializer

    func testThatDataResponseSerializerSucceedsWhenFileDataIsNotNil() {
        // Given
        let serializer = DownloadRequest.dataResponseSerializer()

        // When
        let result = serializer.serializeResponse(nil, nil, jsonValidDataFileURL, nil)

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)
    }

    func testThatDataResponseSerializerSucceedsWhenFileDataIsNil() {
        // Given
        let serializer = DownloadRequest.dataResponseSerializer()

        // When
        let result = serializer.serializeResponse(nil, nil, jsonEmptyDataFileURL, nil)

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)
    }

    func testThatDataResponseSerializerFailsWhenFileURLIsNil() {
        // Given
        let serializer = DownloadRequest.dataResponseSerializer()

        // When
        let result = serializer.serializeResponse(nil, nil, nil, nil)

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error as? AFError {
            XCTAssertTrue(error.isInputFileNil)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatDataResponseSerializerFailsWhenFileURLIsInvalid() {
        // Given
        let serializer = DownloadRequest.dataResponseSerializer()

        // When
        let result = serializer.serializeResponse(nil, nil, invalidFileURL, nil)

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error as? AFError {
            XCTAssertTrue(error.isInputFileReadFailed)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatDataResponseSerializerFailsWhenErrorIsNotNil() {
        // Given
        let serializer = DownloadRequest.dataResponseSerializer()

        // When
        let result = serializer.serializeResponse(nil, nil, nil, error)

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error as? AFError {
            XCTAssertTrue(error.isInputFileNil)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatDataResponseSerializerFailsWhenFileURLIsNilWithNonEmptyResponseStatusCode() {
        // Given
        let serializer = DownloadRequest.dataResponseSerializer()
        let response = httpURLResponse(forStatusCode: 200)

        // When
        let result = serializer.serializeResponse(nil, response, nil, nil)

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error as? AFError {
            XCTAssertTrue(error.isInputFileNil)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatDataResponseSerializerSucceedsWhenDataIsNilWithEmptyResponseStatusCode() {
        // Given
        let serializer = DataRequest.dataResponseSerializer()
        let response = httpURLResponse(forStatusCode: 205)

        // When
        let result = serializer.serializeResponse(nil, response, nil, nil)

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)

        if let data = result.value {
            XCTAssertEqual(data.count, 0)
        }
    }

    // MARK: Tests - String Response Serializer

    func testThatStringResponseSerializerFailsWhenFileURLIsNil() {
        // Given
        let serializer = DownloadRequest.stringResponseSerializer()

        // When
        let result = serializer.serializeResponse(nil, nil, nil, nil)

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error as? AFError {
            XCTAssertTrue(error.isInputFileNil)
        } else {
            XCTFail("error should not be nil")
        }
    }


    func testThatStringResponseSerializerFailsWhenFileURLIsInvalid() {
        // Given
        let serializer = DownloadRequest.stringResponseSerializer()

        // When
        let result = serializer.serializeResponse(nil, nil, invalidFileURL, nil)

        // Then
        XCTAssertEqual(result.isSuccess, false)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error as? AFError {
            XCTAssertTrue(error.isInputFileReadFailed)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatStringResponseSerializerSucceedsWhenFileDataIsEmpty() {
        // Given
        let serializer = DownloadRequest.stringResponseSerializer()

        // When
        let result = serializer.serializeResponse(nil, nil, stringEmptyDataFileURL, nil)

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)
    }

    func testThatStringResponseSerializerSucceedsWithUTF8DataAndNoProvidedEncoding() {
        let serializer = DownloadRequest.stringResponseSerializer()

        // When
        let result = serializer.serializeResponse(nil, nil, stringUTF8DataFileURL, nil)

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)
    }

    func testThatStringResponseSerializerSucceedsWithUTF8DataAndUTF8ProvidedEncoding() {
        let serializer = DownloadRequest.stringResponseSerializer(encoding: .utf8)

        // When
        let result = serializer.serializeResponse(nil, nil, stringUTF8DataFileURL, nil)

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)
    }

    func testThatStringResponseSerializerSucceedsWithUTF8DataUsingResponseTextEncodingName() {
        let serializer = DownloadRequest.stringResponseSerializer()
        let response = httpURLResponse(forStatusCode: 200, headers: ["Content-Type": "image/jpeg; charset=utf-8"])

        // When
        let result = serializer.serializeResponse(nil, response, stringUTF8DataFileURL, nil)

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)
    }

    func testThatStringResponseSerializerFailsWithUTF32DataAndUTF8ProvidedEncoding() {
        // Given
        let serializer = DownloadRequest.stringResponseSerializer(encoding: .utf8)

        // When
        let result = serializer.serializeResponse(nil, nil, stringUTF32DataFileURL, nil)

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error as? AFError, let failedEncoding = error.failedStringEncoding {
            XCTAssertTrue(error.isStringSerializationFailed)
            XCTAssertEqual(failedEncoding, .utf8)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatStringResponseSerializerFailsWithUTF32DataAndUTF8ResponseEncoding() {
        // Given
        let serializer = DownloadRequest.stringResponseSerializer()
        let response = httpURLResponse(forStatusCode: 200, headers: ["Content-Type": "image/jpeg; charset=utf-8"])

        // When
        let result = serializer.serializeResponse(nil, response, stringUTF32DataFileURL, nil)

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error as? AFError, let failedEncoding = error.failedStringEncoding {
            XCTAssertTrue(error.isStringSerializationFailed)
            XCTAssertEqual(failedEncoding, .utf8)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatStringResponseSerializerFailsWhenErrorIsNotNil() {
        // Given
        let serializer = DownloadRequest.stringResponseSerializer()

        // When
        let result = serializer.serializeResponse(nil, nil, nil, error)

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error as? AFError {
            XCTAssertTrue(error.isInputFileNil)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatStringResponseSerializerFailsWhenDataIsNilWithNonEmptyResponseStatusCode() {
        // Given
        let serializer = DataRequest.stringResponseSerializer()
        let response = httpURLResponse(forStatusCode: 200)

        // When
        let result = serializer.serializeResponse(nil, response, nil, nil)

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error as? AFError {
            XCTAssertTrue(error.isInputDataNil)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatStringResponseSerializerSucceedsWhenDataIsNilWithEmptyResponseStatusCode() {
        // Given
        let serializer = DataRequest.stringResponseSerializer()
        let response = httpURLResponse(forStatusCode: 204)

        // When
        let result = serializer.serializeResponse(nil, response, nil, nil)

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
        let serializer = DownloadRequest.jsonResponseSerializer()

        // When
        let result = serializer.serializeResponse(nil, nil, nil, nil)

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error as? AFError {
            XCTAssertTrue(error.isInputFileNil)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatJSONResponseSerializerFailsWhenFileURLIsInvalid() {
        // Given
        let serializer = DownloadRequest.jsonResponseSerializer()

        // When
        let result = serializer.serializeResponse(nil, nil, invalidFileURL, nil)

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error as? AFError {
            XCTAssertTrue(error.isInputFileReadFailed)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatJSONResponseSerializerFailsWhenFileDataIsEmpty() {
        // Given
        let serializer = DownloadRequest.jsonResponseSerializer()

        // When
        let result = serializer.serializeResponse(nil, nil, jsonEmptyDataFileURL, nil)

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error as? AFError {
            XCTAssertTrue(error.isInputDataNilOrZeroLength)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatJSONResponseSerializerSucceedsWhenDataIsValidJSON() {
        // Given
        let serializer = DownloadRequest.jsonResponseSerializer()

        // When
        let result = serializer.serializeResponse(nil, nil, jsonValidDataFileURL, nil)

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)
    }

    func testThatJSONResponseSerializerFailsWhenDataIsInvalidJSON() {
        // Given
        let serializer = DownloadRequest.jsonResponseSerializer()

        // When
        let result = serializer.serializeResponse(nil, nil, jsonInvalidDataFileURL, nil)

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error as? AFError, let underlyingError = error.underlyingError as? CocoaError {
            XCTAssertTrue(error.isJSONSerializationFailed)
            XCTAssertEqual(underlyingError.errorCode, 3840)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatJSONResponseSerializerFailsWhenErrorIsNotNil() {
        // Given
        let serializer = DownloadRequest.jsonResponseSerializer()

        // When
        let result = serializer.serializeResponse(nil, nil, nil, error)

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error as? AFError {
            XCTAssertTrue(error.isInputFileNil)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatJSONResponseSerializerFailsWhenDataIsNilWithNonEmptyResponseStatusCode() {
        // Given
        let serializer = DataRequest.jsonResponseSerializer()
        let response = httpURLResponse(forStatusCode: 200)

        // When
        let result = serializer.serializeResponse(nil, response, nil, nil)

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error as? AFError {
            XCTAssertTrue(error.isInputDataNilOrZeroLength)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatJSONResponseSerializerSucceedsWhenDataIsNilWithEmptyResponseStatusCode() {
        // Given
        let serializer = DataRequest.jsonResponseSerializer()
        let response = httpURLResponse(forStatusCode: 205)

        // When
        let result = serializer.serializeResponse(nil, response, nil, nil)

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)

        if let json = result.value as? NSNull {
            XCTAssertEqual(json, NSNull())
        }
    }

    // MARK: Tests - Property List Response Serializer

    func testThatPropertyListResponseSerializerFailsWhenFileURLIsNil() {
        // Given
        let serializer = DownloadRequest.propertyListResponseSerializer()

        // When
        let result = serializer.serializeResponse(nil, nil, nil, nil)

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error as? AFError {
            XCTAssertTrue(error.isInputFileNil)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatPropertyListResponseSerializerFailsWhenFileURLIsInvalid() {
        // Given
        let serializer = DownloadRequest.propertyListResponseSerializer()

        // When
        let result = serializer.serializeResponse(nil, nil, invalidFileURL, nil)

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error as? AFError {
            XCTAssertTrue(error.isInputFileReadFailed)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatPropertyListResponseSerializerFailsWhenFileDataIsEmpty() {
        // Given
        let serializer = DownloadRequest.propertyListResponseSerializer()

        // When
        let result = serializer.serializeResponse(nil, nil, plistEmptyDataFileURL, nil)

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error as? AFError {
            XCTAssertTrue(error.isInputDataNilOrZeroLength)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatPropertyListResponseSerializerSucceedsWhenFileDataIsValidPropertyListData() {
        // Given
        let serializer = DownloadRequest.propertyListResponseSerializer()

        // When
        let result = serializer.serializeResponse(nil, nil, plistValidDataFileURL, nil)

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)
    }

    func testThatPropertyListResponseSerializerFailsWhenDataIsInvalidPropertyListData() {
        // Given
        let serializer = DownloadRequest.propertyListResponseSerializer()

        // When
        let result = serializer.serializeResponse(nil, nil, plistInvalidDataFileURL, nil)

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error as? AFError, let underlyingError = error.underlyingError as? CocoaError {
            XCTAssertTrue(error.isPropertyListSerializationFailed)
            XCTAssertEqual(underlyingError.errorCode, 3840)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatPropertyListResponseSerializerFailsWhenErrorIsNotNil() {
        // Given
        let serializer = DownloadRequest.propertyListResponseSerializer()

        // When
        let result = serializer.serializeResponse(nil, nil, nil, error)

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error as? AFError {
            XCTAssertTrue(error.isInputFileNil)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatPropertyListResponseSerializerFailsWhenDataIsNilWithNonEmptyResponseStatusCode() {
        // Given
        let serializer = DataRequest.propertyListResponseSerializer()
        let response = httpURLResponse(forStatusCode: 200)

        // When
        let result = serializer.serializeResponse(nil, response, nil, nil)

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertNil(result.value)
        XCTAssertNotNil(result.error)

        if let error = result.error as? AFError {
            XCTAssertTrue(error.isInputDataNilOrZeroLength)
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatPropertyListResponseSerializerSucceedsWhenDataIsNilWith204ResponseStatusCode() {
        // Given
        let serializer = DataRequest.propertyListResponseSerializer()
        let response = httpURLResponse(forStatusCode: 204)

        // When
        let result = serializer.serializeResponse(nil, response, nil, nil)

        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.value)
        XCTAssertNil(result.error)

        if let plist = result.value as? NSNull {
            XCTAssertEqual(plist, NSNull(), "plist should be equal to NSNull")
        }
    }
}
