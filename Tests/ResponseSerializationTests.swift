// ResponseSerializationTests.swift
//
// Copyright (c) 2014–2015 Alamofire Software Foundation (http://alamofire.org/)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Alamofire
import Foundation
import XCTest

class ResponseSerializationTestCase: BaseTestCase {

    // MARK: - Data Response Serializer Tests

    func testThatDataResponseSerializerSucceedsWhenDataIsNotNil() {
        // Given
        let serializer = Request.dataResponseSerializer()
        let data = "data".dataUsingEncoding(NSUTF8StringEncoding)!

        // When
        let result = serializer.serializeResponse(nil, nil, data)

        // Then
        XCTAssertTrue(result.isSuccess, "result is success should be true")
        XCTAssertNotNil(result.value, "result value should not be nil")
        XCTAssertNil(result.data, "result data should be nil")
        XCTAssertTrue(result.error == nil, "result error should be nil")
    }

    func testThatDataResponseSerializerFailsWhenDataIsNil() {
        // Given
        let serializer = Request.dataResponseSerializer()

        // When
        let result = serializer.serializeResponse(nil, nil, nil)

        // Then
        XCTAssertTrue(result.isFailure, "result is failure should be true")
        XCTAssertNil(result.value, "result value should be nil")
        XCTAssertNil(result.data, "result data should be nil")
        XCTAssertTrue(result.error != nil, "result error should not be nil")

        if let error = result.error as? NSError {
            XCTAssertEqual(error.domain, Error.Domain, "error domain should match expected value")
            XCTAssertEqual(error.code, Error.Code.DataSerializationFailed.rawValue, "error code should match expected value")
        } else {
            XCTFail("error should not be nil")
        }
    }

    // MARK: - String Response Serializer Tests

    func testThatStringResponseSerializerFailsWhenDataIsNil() {
        // Given
        let serializer = Request.stringResponseSerializer()

        // When
        let result = serializer.serializeResponse(nil, nil, nil)

        // Then
        XCTAssertTrue(result.isFailure, "result is failure should be true")
        XCTAssertNil(result.value, "result value should be nil")
        XCTAssertNil(result.data, "result data should be nil")
        XCTAssertTrue(result.error != nil, "result error should not be nil")

        if let error = result.error as? NSError {
            XCTAssertEqual(error.domain, Error.Domain, "error domain should match expected value")
            XCTAssertEqual(error.code, Error.Code.StringSerializationFailed.rawValue, "error code should match expected value")
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatStringResponseSerializerSucceedsWhenDataIsEmpty() {
        // Given
        let serializer = Request.stringResponseSerializer()

        // When
        let result = serializer.serializeResponse(nil, nil, NSData())

        // Then
        XCTAssertTrue(result.isSuccess, "result is success should be true")
        XCTAssertNotNil(result.value, "result value should not be nil")
        XCTAssertNil(result.data, "result data should be nil")
        XCTAssertTrue(result.error == nil, "result error should be nil")
    }

    func testThatStringResponseSerializerSucceedsWithUTF8DataAndNoProvidedEncoding() {
        let serializer = Request.stringResponseSerializer()
        let data = "data".dataUsingEncoding(NSUTF8StringEncoding)!

        // When
        let result = serializer.serializeResponse(nil, nil, data)

        // Then
        XCTAssertTrue(result.isSuccess, "result is success should be true")
        XCTAssertNotNil(result.value, "result value should not be nil")
        XCTAssertNil(result.data, "result data should be nil")
        XCTAssertTrue(result.error == nil, "result error should be nil")
    }

    func testThatStringResponseSerializerSucceedsWithUTF8DataAndUTF8ProvidedEncoding() {
        let serializer = Request.stringResponseSerializer(encoding: NSUTF8StringEncoding)
        let data = "data".dataUsingEncoding(NSUTF8StringEncoding)!

        // When
        let result = serializer.serializeResponse(nil, nil, data)

        // Then
        XCTAssertTrue(result.isSuccess, "result is success should be true")
        XCTAssertNotNil(result.value, "result value should not be nil")
        XCTAssertNil(result.data, "result data should be nil")
        XCTAssertTrue(result.error == nil, "result error should be nil")
    }

    func testThatStringResponseSerializerSucceedsWithUTF8DataUsingResponseTextEncodingName() {
        let serializer = Request.stringResponseSerializer()
        let data = "data".dataUsingEncoding(NSUTF8StringEncoding)!
        let response = NSHTTPURLResponse(
            URL: NSURL(string: "https://httpbin.org/get")!,
            statusCode: 200,
            HTTPVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "image/jpeg; charset=utf-8"]
        )

        // When
        let result = serializer.serializeResponse(nil, response, data)

        // Then
        XCTAssertTrue(result.isSuccess, "result is success should be true")
        XCTAssertNotNil(result.value, "result value should not be nil")
        XCTAssertNil(result.data, "result data should be nil")
        XCTAssertTrue(result.error == nil, "result error should be nil")
    }

    func testThatStringResponseSerializerFailsWithUTF32DataAndUTF8ProvidedEncoding() {
        // Given
        let serializer = Request.stringResponseSerializer(encoding: NSUTF8StringEncoding)
        let data = "random data".dataUsingEncoding(NSUTF32StringEncoding)!

        // When
        let result = serializer.serializeResponse(nil, nil, data)

        // Then
        XCTAssertTrue(result.isFailure, "result is failure should be true")
        XCTAssertNil(result.value, "result value should be nil")
        XCTAssertNotNil(result.data, "result data should not be nil")
        XCTAssertTrue(result.error != nil, "result error should not be nil")

        if let error = result.error as? NSError {
            XCTAssertEqual(error.domain, Error.Domain, "error domain should match expected value")
            XCTAssertEqual(error.code, Error.Code.StringSerializationFailed.rawValue, "error code should match expected value")
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatStringResponseSerializerFailsWithUTF32DataAndUTF8ResponseEncoding() {
        // Given
        let serializer = Request.stringResponseSerializer()
        let data = "random data".dataUsingEncoding(NSUTF32StringEncoding)!
        let response = NSHTTPURLResponse(
            URL: NSURL(string: "https://httpbin.org/get")!,
            statusCode: 200,
            HTTPVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "image/jpeg; charset=utf-8"]
        )

        // When
        let result = serializer.serializeResponse(nil, response, data)

        // Then
        XCTAssertTrue(result.isFailure, "result is failure should be true")
        XCTAssertNil(result.value, "result value should be nil")
        XCTAssertNotNil(result.data, "result data should not be nil")
        XCTAssertTrue(result.error != nil, "result error should not be nil")

        if let error = result.error as? NSError {
            XCTAssertEqual(error.domain, Error.Domain, "error domain should match expected value")
            XCTAssertEqual(error.code, Error.Code.StringSerializationFailed.rawValue, "error code should match expected value")
        } else {
            XCTFail("error should not be nil")
        }
    }

    // MARK: - JSON Response Serializer Tests

    func testThatJSONResponseSerializerFailsWhenDataIsNil() {
        // Given
        let serializer = Request.JSONResponseSerializer()

        // When
        let result = serializer.serializeResponse(nil, nil, nil)

        // Then
        XCTAssertTrue(result.isFailure, "result is failure should be true")
        XCTAssertNil(result.value, "result value should be nil")
        XCTAssertNil(result.data, "result data should be nil")
        XCTAssertTrue(result.error != nil, "result error should not be nil")

        if let error = result.error as? NSError {
            XCTAssertEqual(error.domain, Error.Domain, "error domain should match expected value")
            XCTAssertEqual(error.code, Error.Code.JSONSerializationFailed.rawValue, "error code should match expected value")
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatJSONResponseSerializerFailsWhenDataIsEmpty() {
        // Given
        let serializer = Request.JSONResponseSerializer()

        // When
        let result = serializer.serializeResponse(nil, nil, NSData())

        // Then
        XCTAssertTrue(result.isFailure, "result is failure should be true")
        XCTAssertNil(result.value, "result value should be nil")
        XCTAssertNotNil(result.data, "result data should not be nil")
        XCTAssertTrue(result.error != nil, "result error should not be nil")

        if let error = result.error as? NSError {
            XCTAssertEqual(error.domain, NSCocoaErrorDomain, "error domain should match expected value")
            XCTAssertEqual(error.code, 3840, "error code should match expected value")
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatJSONResponseSerializerSucceedsWhenDataIsValidJSON() {
        // Given
        let serializer = Request.stringResponseSerializer()
        let data = "{\"json\": true}".dataUsingEncoding(NSUTF8StringEncoding)!

        // When
        let result = serializer.serializeResponse(nil, nil, data)

        // Then
        XCTAssertTrue(result.isSuccess, "result is success should be true")
        XCTAssertNotNil(result.value, "result value should not be nil")
        XCTAssertNil(result.data, "result data should be nil")
        XCTAssertTrue(result.error == nil, "result error should be nil")
    }

    func testThatJSONResponseSerializerFailsWhenDataIsInvalidJSON() {
        // Given
        let serializer = Request.JSONResponseSerializer()
        let data = "definitely not valid json".dataUsingEncoding(NSUTF8StringEncoding)!

        // When
        let result = serializer.serializeResponse(nil, nil, data)

        // Then
        XCTAssertTrue(result.isFailure, "result is failure should be true")
        XCTAssertNil(result.value, "result value should be nil")
        XCTAssertNotNil(result.data, "result data should not be nil")
        XCTAssertTrue(result.error != nil, "result error should not be nil")

        if let error = result.error as? NSError {
            XCTAssertEqual(error.domain, NSCocoaErrorDomain, "error domain should match expected value")
            XCTAssertEqual(error.code, 3840, "error code should match expected value")
        } else {
            XCTFail("error should not be nil")
        }
    }

    // MARK: - Property List Response Serializer Tests

    func testThatPropertyListResponseSerializerFailsWhenDataIsNil() {
        // Given
        let serializer = Request.propertyListResponseSerializer()

        // When
        let result = serializer.serializeResponse(nil, nil, nil)

        // Then
        XCTAssertTrue(result.isFailure, "result is failure should be true")
        XCTAssertNil(result.value, "result value should be nil")
        XCTAssertNil(result.data, "result data should be nil")
        XCTAssertTrue(result.error != nil, "result error should not be nil")

        if let error = result.error as? NSError {
            XCTAssertEqual(error.domain, Error.Domain, "error domain should match expected value")
            XCTAssertEqual(error.code, Error.Code.PropertyListSerializationFailed.rawValue, "error code should match expected value")
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatPropertyListResponseSerializerFailsWhenDataIsEmpty() {
        // Given
        let serializer = Request.propertyListResponseSerializer()

        // When
        let result = serializer.serializeResponse(nil, nil, NSData())

        // Then
        XCTAssertTrue(result.isFailure, "result is failure should be true")
        XCTAssertNil(result.value, "result value should be nil")
        XCTAssertNotNil(result.data, "result data should not be nil")
        XCTAssertTrue(result.error != nil, "result error should not be nil")

        if let error = result.error as? NSError {
            XCTAssertEqual(error.domain, NSCocoaErrorDomain, "error domain should match expected value")
            XCTAssertEqual(error.code, 3840, "error code should match expected value")
        } else {
            XCTFail("error should not be nil")
        }
    }

    func testThatPropertyListResponseSerializerSucceedsWhenDataIsValidPropertyListData() {
        // Given
        let serializer = Request.propertyListResponseSerializer()
        let data = NSKeyedArchiver.archivedDataWithRootObject(["foo": "bar"])

        // When
        let result = serializer.serializeResponse(nil, nil, data)

        // Then
        XCTAssertTrue(result.isSuccess, "result is success should be true")
        XCTAssertNotNil(result.value, "result value should not be nil")
        XCTAssertNil(result.data, "result data should be nil")
        XCTAssertTrue(result.error == nil, "result error should be nil")
    }

    func testThatPropertyListResponseSerializerFailsWhenDataIsInvalidPropertyListData() {
        // Given
        let serializer = Request.JSONResponseSerializer()
        let data = "definitely not valid plist data".dataUsingEncoding(NSUTF8StringEncoding)!

        // When
        let result = serializer.serializeResponse(nil, nil, data)

        // Then
        XCTAssertTrue(result.isFailure, "result is failure should be true")
        XCTAssertNil(result.value, "result value should be nil")
        XCTAssertNotNil(result.data, "result data should not be nil")
        XCTAssertTrue(result.error != nil, "result error should not be nil")

        if let error = result.error as? NSError {
            XCTAssertEqual(error.domain, NSCocoaErrorDomain, "error domain should match expected value")
            XCTAssertEqual(error.code, 3840, "error code should match expected value")
        } else {
            XCTFail("error should not be nil")
        }
    }
}
