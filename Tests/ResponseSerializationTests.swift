//
//  ResponseSerializationTests.swift
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

import Alamofire
import Foundation
import Testing
import XCTest

@Suite
struct DataResponseSerializationTestCase {
    // MARK: Properties

    private let error = AFError.responseSerializationFailed(reason: .inputDataNilOrZeroLength)

    // MARK: DataResponseSerializer

    @Test
    func dataResponseSerializerSucceedsWhenDataIsNotNil() {
        // Given
        let serializer = DataResponseSerializer()
        let data = Data("data".utf8)

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: data, error: nil) }

        // Then
        #expect(result.isSuccess)
        #expect(result.success != nil)
        #expect(result.failure == nil)
    }

    @Test
    func dataResponseSerializerFailsWhenDataIsNil() {
        // Given
        let serializer = DataResponseSerializer()

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: nil, error: nil) }

        // Then
        #expect(result.isFailure)
        #expect(result.success == nil)
        #expect(result.failure != nil)
        #expect(result.failure?.asAFError?.isInputDataNilOrZeroLength == true)
    }

    @Test
    func dataResponseSerializerFailsWhenErrorIsNotNil() {
        // Given
        let serializer = DataResponseSerializer()

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: nil, error: error) }

        // Then
        #expect(result.isFailure)
        #expect(result.success == nil)
        #expect(result.failure != nil)
        #expect(result.failure?.asAFError?.isInputDataNilOrZeroLength == true)
    }

    @Test
    func dataResponseSerializerFailsWhenDataIsNilWithNonEmptyResponseStatusCode() {
        // Given
        let serializer = DataResponseSerializer()
        let response = HTTPURLResponse(statusCode: 200)

        // When
        let result = Result { try serializer.serialize(request: nil, response: response, data: nil, error: nil) }

        // Then
        #expect(result.isFailure, "result is failure should be true")
        #expect(result.success == nil, "result value should be nil")
        #expect(result.failure != nil, "result error should not be nil")
        #expect(result.failure?.asAFError?.isInputDataNilOrZeroLength == true)
    }

    @Test
    func dataResponseSerializerSucceedsWhenDataIsNilWithGETRequestAnd204ResponseStatusCode() {
        // Given
        let serializer = DataResponseSerializer()
        let request = Endpoint().urlRequest
        let response = HTTPURLResponse(statusCode: 204)

        // When
        let result = Result { try serializer.serialize(request: request, response: response, data: nil, error: nil) }

        // Then
        #expect(result.isSuccess)
        #expect(result.success != nil)
        #expect(result.failure == nil)
        #expect(result.success?.isEmpty == true)
    }

    @Test
    func dataResponseSerializerSucceedsWhenDataIsNilWithGETRequestAnd205ResponseStatusCode() {
        // Given
        let serializer = DataResponseSerializer()
        let request = Endpoint().urlRequest
        let response = HTTPURLResponse(statusCode: 205)

        // When
        let result = Result { try serializer.serialize(request: request, response: response, data: nil, error: nil) }

        // Then
        #expect(result.isSuccess)
        #expect(result.success != nil)
        #expect(result.failure == nil)
        #expect(result.success?.isEmpty == true)
    }

    @Test
    func dataResponseSerializerSucceedsWhenDataIsNilWithHEADRequestAnd200ResponseStatusCode() {
        // Given
        let serializer = DataResponseSerializer()
        let request = Endpoint(method: .head).urlRequest
        let response = HTTPURLResponse(statusCode: 200)

        // When
        let result = Result { try serializer.serialize(request: request, response: response, data: nil, error: nil) }

        // Then
        #expect(result.isSuccess)
        #expect(result.success != nil)
        #expect(result.failure == nil)
        #expect(result.success?.isEmpty == true)
    }

    // MARK: StringResponseSerializer

    @Test
    func stringResponseSerializerFailsWhenDataIsNil() {
        // Given
        let serializer = DataResponseSerializer()

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: nil, error: nil) }

        // Then
        #expect(result.isFailure)
        #expect(result.success == nil)
        #expect(result.failure != nil)
        #expect(result.failure?.asAFError?.isInputDataNilOrZeroLength == true)
    }

    @Test
    func stringResponseSerializerFailsWhenDataIsEmpty() {
        // Given
        let serializer = StringResponseSerializer()

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: Data(), error: nil) }

        // Then
        #expect(result.isFailure)
        #expect(result.success == nil)
        #expect(result.failure != nil)
        #expect(result.failure?.asAFError?.isInputDataNilOrZeroLength == true)
    }

    @Test
    func stringResponseSerializerSucceedsWithUTF8DataAndNoProvidedEncoding() {
        let serializer = StringResponseSerializer()
        let data = Data("data".utf8)

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: data, error: nil) }

        // Then
        #expect(result.isSuccess)
        #expect(result.success != nil)
        #expect(result.failure == nil)
    }

    @Test
    func stringResponseSerializerSucceedsWithUTF8DataAndUTF8ProvidedEncoding() {
        let serializer = StringResponseSerializer(encoding: .utf8)
        let data = Data("data".utf8)

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: data, error: nil) }

        // Then
        #expect(result.isSuccess)
        #expect(result.success != nil)
        #expect(result.failure == nil)
    }

    @Test
    func stringResponseSerializerSucceedsWithUTF8DataUsingResponseTextEncodingName() {
        let serializer = StringResponseSerializer()
        let data = Data("data".utf8)
        let response = HTTPURLResponse(statusCode: 200, headers: ["Content-Type": "image/jpeg; charset=utf-8"])

        // When
        let result = Result { try serializer.serialize(request: nil, response: response, data: data, error: nil) }

        // Then
        #expect(result.isSuccess)
        #expect(result.success != nil)
        #expect(result.failure == nil)
    }

    @Test
    func stringResponseSerializerFailsWithUTF32DataAndUTF8ProvidedEncoding() {
        // Given
        let serializer = StringResponseSerializer(encoding: .utf8)
        let data = "random data".data(using: .utf32)!

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: data, error: nil) }

        // Then
        #expect(result.isFailure)
        #expect(result.success == nil)
        #expect(result.failure != nil)
        #expect(result.failure?.asAFError?.isStringSerializationFailed == true)
        #expect(result.failure?.asAFError?.failedStringEncoding == .utf8)
    }

    @Test
    func stringResponseSerializerFailsWithUTF32DataAndUTF8ResponseEncoding() {
        // Given
        let serializer = StringResponseSerializer()
        let data = "random data".data(using: .utf32)!
        let response = HTTPURLResponse(statusCode: 200, headers: ["Content-Type": "image/jpeg; charset=utf-8"])

        // When
        let result = Result { try serializer.serialize(request: nil, response: response, data: data, error: nil) }

        // Then
        #expect(result.isFailure)
        #expect(result.success == nil)
        #expect(result.failure != nil)
        #expect(result.failure?.asAFError?.isStringSerializationFailed == true)
        #expect(result.failure?.asAFError?.failedStringEncoding == .utf8)
    }

    @Test
    func stringResponseSerializerFailsWhenErrorIsNotNil() {
        // Given
        let serializer = StringResponseSerializer()

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: nil, error: error) }

        // Then
        #expect(result.isFailure)
        #expect(result.success == nil)
        #expect(result.failure != nil)
        #expect(result.failure?.asAFError?.isInputDataNilOrZeroLength == true)
    }

    @Test
    func stringResponseSerializerFailsWhenDataIsNilWithNonEmptyResponseStatusCode() {
        // Given
        let serializer = StringResponseSerializer()
        let response = HTTPURLResponse(statusCode: 200)

        // When
        let result = Result { try serializer.serialize(request: nil, response: response, data: nil, error: nil) }

        // Then
        #expect(result.isFailure)
        #expect(result.success == nil)
        #expect(result.failure != nil)
        #expect(result.failure?.asAFError?.isInputDataNilOrZeroLength == true)
    }

    @Test
    func stringResponseSerializerSucceedsWhenDataIsNilWithGETRequestAnd204ResponseStatusCode() {
        // Given
        let serializer = StringResponseSerializer()
        let request = Endpoint().urlRequest
        let response = HTTPURLResponse(statusCode: 204)

        // When
        let result = Result { try serializer.serialize(request: request, response: response, data: nil, error: nil) }

        // Then
        #expect(result.isSuccess)
        #expect(result.success != nil)
        #expect(result.failure == nil)
        #expect(result.success == "")
    }

    @Test
    func stringResponseSerializerSucceedsWhenDataIsNilWithGETRequestAnd205ResponseStatusCode() {
        // Given
        let serializer = StringResponseSerializer()
        let request = Endpoint().urlRequest
        let response = HTTPURLResponse(statusCode: 205)

        // When
        let result = Result { try serializer.serialize(request: request, response: response, data: nil, error: nil) }

        // Then
        #expect(result.isSuccess)
        #expect(result.success != nil)
        #expect(result.failure == nil)
        #expect(result.success == "")
    }

    @Test
    func stringResponseSerializerSucceedsWhenDataIsNilWithHEADRequestAnd200ResponseStatusCode() {
        // Given
        let serializer = StringResponseSerializer()
        let request = Endpoint(method: .head).urlRequest
        let response = HTTPURLResponse(statusCode: 200)

        // When
        let result = Result { try serializer.serialize(request: request, response: response, data: nil, error: nil) }

        // Then
        #expect(result.isSuccess)
        #expect(result.success != nil)
        #expect(result.failure == nil)
        #expect(result.success == "")
    }

    // MARK: JSONResponseSerializer

    @Test
    @available(*, deprecated)
    func jsonResponseSerializerFailsWhenDataIsNil() {
        // Given
        let serializer = JSONResponseSerializer()

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: nil, error: nil) }

        // Then
        #expect(result.isFailure)
        #expect(result.success == nil)
        #expect(result.failure != nil)
        #expect(result.failure?.asAFError?.isInputDataNilOrZeroLength == true)
    }

    @Test
    @available(*, deprecated)
    func jsonResponseSerializerFailsWhenDataIsEmpty() {
        // Given
        let serializer = JSONResponseSerializer()

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: Data(), error: nil) }

        // Then
        #expect(result.isFailure)
        #expect(result.success == nil)
        #expect(result.failure != nil)
        #expect(result.failure?.asAFError?.isInputDataNilOrZeroLength == true)
    }

    @Test
    @available(*, deprecated)
    func jsonResponseSerializerSucceedsWhenDataIsValidJSON() {
        // Given
        let serializer = JSONResponseSerializer()
        let data = Data("{\"json\": true}".utf8)

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: data, error: nil) }

        // Then
        #expect(result.isSuccess)
        #expect(result.success != nil)
        #expect(result.failure == nil)
    }

    @Test
    @available(*, deprecated)
    func jsonResponseSerializerFailsWhenDataIsInvalidJSON() {
        // Given
        let serializer = JSONResponseSerializer()
        let data = Data("definitely not valid json".utf8)

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: data, error: nil) }

        // Then
        #expect(result.isFailure)
        #expect(result.success == nil)
        #expect(result.failure != nil)
        #expect(result.failure?.asAFError?.isJSONSerializationFailed == true)
        #expect((result.failure?.asAFError?.underlyingError as? CocoaError)?.code == .propertyListReadCorrupt)
    }

    @Test
    @available(*, deprecated)
    func jsonResponseSerializerFailsWhenErrorIsNotNil() {
        // Given
        let serializer = JSONResponseSerializer()

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: nil, error: error) }

        // Then
        #expect(result.isFailure)
        #expect(result.success == nil)
        #expect(result.failure != nil)
        #expect(result.failure?.asAFError?.isInputDataNilOrZeroLength == true)
    }

    @Test
    @available(*, deprecated)
    func jsonResponseSerializerFailsWhenDataIsNilWithNonEmptyResponseStatusCode() {
        // Given
        let serializer = JSONResponseSerializer()
        let response = HTTPURLResponse(statusCode: 200)

        // When
        let result = Result { try serializer.serialize(request: nil, response: response, data: nil, error: nil) }

        // Then
        #expect(result.isFailure)
        #expect(result.success == nil)
        #expect(result.failure != nil)
        #expect(result.failure?.asAFError?.isInputDataNilOrZeroLength == true)
    }

    @Test
    @available(*, deprecated)
    func jsonResponseSerializerSucceedsWhenDataIsNilWithGETRequestAnd204ResponseStatusCode() {
        // Given
        let serializer = JSONResponseSerializer()
        let request = Endpoint().urlRequest
        let response = HTTPURLResponse(statusCode: 204)

        // When
        let result = Result { try serializer.serialize(request: request, response: response, data: nil, error: nil) }

        // Then
        #expect(result.isSuccess)
        #expect(result.success != nil)
        #expect(result.failure == nil)
        #expect(result.success as? NSNull == NSNull())
    }

    @Test
    @available(*, deprecated)
    func jsonResponseSerializerSucceedsWhenDataIsNilWithGETRequestAnd205ResponseStatusCode() {
        // Given
        let serializer = JSONResponseSerializer()
        let request = Endpoint().urlRequest
        let response = HTTPURLResponse(statusCode: 205)

        // When
        let result = Result { try serializer.serialize(request: request, response: response, data: nil, error: nil) }

        // Then
        #expect(result.isSuccess)
        #expect(result.success != nil)
        #expect(result.failure == nil)
        #expect(result.success as? NSNull == NSNull())
    }

    @Test
    @available(*, deprecated)
    func jsonResponseSerializerSucceedsWhenDataIsNilWithHEADRequestAnd200ResponseStatusCode() {
        // Given
        let serializer = JSONResponseSerializer()
        let request = Endpoint(method: .head).urlRequest
        let response = HTTPURLResponse(statusCode: 200)

        // When
        let result = Result { try serializer.serialize(request: request, response: response, data: nil, error: nil) }

        // Then
        #expect(result.isSuccess)
        #expect(result.success != nil)
        #expect(result.failure == nil)
        #expect(result.success as? NSNull == NSNull())
    }
}

@Suite
struct StaticSerializationTests {
    func consumeDownloadResponseSerializer<Serializer: DownloadResponseSerializerProtocol>(_ responseSerializer: Serializer) {
        _ = responseSerializer
    }

    func consumeStreamSerializer<Serializer: DataStreamSerializer>(_ serializer: Serializer) {
        _ = serializer
    }

    func consumeResponseSerializer<Serializer: ResponseSerializer>(_ responseSerializer: Serializer) {
        _ = responseSerializer
    }

    @Test
    func urlSerializerCanBeCreatedStaticallyFromProtocol() {
        // Given, When, Then
        consumeDownloadResponseSerializer(.url)
    }

    @Test
    func dataSerializerCanBeCreatedStaticallyFromProtocol() {
        // Given, When, Then
        consumeResponseSerializer(.data())
    }

    @Test
    func stringSerializerCanBeCreatedStaticallyFromProtocol() {
        // Given, When, Then
        consumeResponseSerializer(.string())
    }

    @Test
    func decodableSerializerCanBeCreatedStaticallyFromProtocol() {
        // Given, When, Then
        consumeResponseSerializer(.decodable(of: TestResponse.self))
    }

    @Test
    func passthroughStreamSerializerCanBeCreatedStaticallyFromProtocol() {
        // Given, When, Then
        consumeStreamSerializer(.passthrough)
    }

    @Test
    func stringStreamSerializerCanBeCreatedStaticallyFromProtocol() {
        // Given, When, Then
        consumeStreamSerializer(.string)
    }

    @Test
    func decodableStreamSerializerCanBeCreatedStaticallyFromProtocol() {
        // Given, When, Then
        consumeStreamSerializer(.decodable(of: TestResponse.self))
    }
}

// MARK: -

@Suite
struct URLResponseSerializerTests {
    @Test
    func urlResponseSerializerProducesURLOnSuccess() {
        // Given
        let serializer = URLResponseSerializer()
        let request = Endpoint().urlRequest
        let response = HTTPURLResponse(statusCode: 200)
        let url = URL(fileURLWithPath: "/")

        // When
        let result = Result { try serializer.serializeDownload(request: request,
                                                               response: response,
                                                               fileURL: url,
                                                               error: nil) }

        // Then
        #expect(result.success == url)
    }

    @Test
    func urlResponseSerializerProducesErrorFromIncomingErrors() {
        // Given
        let serializer = URLResponseSerializer()
        let request = Endpoint().urlRequest
        let response = HTTPURLResponse(statusCode: 200)
        let error = AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 404))

        // When
        let result = Result { try serializer.serializeDownload(request: request,
                                                               response: response,
                                                               fileURL: nil,
                                                               error: error) }

        // Then
        #expect(result.failure?.localizedDescription == error.localizedDescription)
    }

    @Test
    func urlResponseSerializerProducesInputFileNilErrorWhenNoURL() {
        // Given
        let serializer = URLResponseSerializer()
        let request = Endpoint().urlRequest
        let response = HTTPURLResponse(statusCode: 200)

        // When
        let result = Result { try serializer.serializeDownload(request: request,
                                                               response: response,
                                                               fileURL: nil,
                                                               error: nil) }

        // Then
        #expect(result.failure?.asAFError?.isInputFileNil == true)
    }
}

// MARK: -

// used by testThatDecodableResponseSerializerSucceedsWhenDataIsNilWithEmptyResponseConformingTypeAndEmptyResponseStatusCode
extension Swift.Bool: Alamofire.EmptyResponse {
    public static func emptyValue() -> Bool {
        true
    }
}

@Suite
struct DecodableResponseSerializerTests {
    private let error = AFError.responseSerializationFailed(reason: .inputDataNilOrZeroLength)

    struct DecodableValue: Decodable, EmptyResponse {
        static func emptyValue() -> DecodableValue {
            DecodableValue(string: "")
        }

        let string: String
    }

    @Test
    func decodableResponseSerializerFailsWhenDataIsNil() {
        // Given
        let serializer = DecodableResponseSerializer<DecodableValue>()

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: nil, error: nil) }

        // Then
        #expect(result.isFailure)
        #expect(result.success == nil)
        #expect(result.failure != nil)
        #expect(result.failure?.asAFError?.isInputDataNilOrZeroLength == true)
    }

    @Test
    func decodableResponseSerializerFailsWhenDataIsEmpty() {
        // Given
        let serializer = DecodableResponseSerializer<DecodableValue>()

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: Data(), error: nil) }

        // Then
        #expect(result.isFailure)
        #expect(result.success == nil)
        #expect(result.failure != nil)
        #expect(result.failure?.asAFError?.isInputDataNilOrZeroLength == true)
    }

    @Test
    func decodableResponseSerializerSucceedsWhenDataIsValidJSON() {
        // Given
        let data = Data("{\"string\":\"string\"}".utf8)
        let serializer = DecodableResponseSerializer<DecodableValue>()

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: data, error: nil) }

        // Then
        #expect(result.isSuccess)
        #expect(result.success != nil)
        #expect(result.success?.string == "string")
        #expect(result.failure == nil)
    }

    @Test
    func decodableResponseSerializerFailsWhenDataIsInvalidRepresentation() {
        // Given
        let serializer = DecodableResponseSerializer<DecodableValue>()
        let data = Data("definitely not valid".utf8)

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: data, error: nil) }

        // Then
        #expect(result.isFailure)
        #expect(result.success == nil)
        #expect(result.failure != nil)
    }

    @Test
    func decodableResponseSerializerFailsWhenErrorIsNotNil() {
        // Given
        let serializer = DecodableResponseSerializer<DecodableValue>()

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: nil, error: error) }

        // Then
        #expect(result.isFailure)
        #expect(result.success == nil)
        #expect(result.failure != nil)
        #expect(result.failure?.asAFError?.isInputDataNilOrZeroLength == true)
    }

    @Test
    func decodableResponseSerializerFailsWhenDataIsNilWithNonEmptyResponseStatusCode() {
        // Given
        let serializer = DecodableResponseSerializer<DecodableValue>()
        let response = HTTPURLResponse(statusCode: 200)

        // When
        let result = Result { try serializer.serialize(request: nil, response: response, data: nil, error: nil) }

        // Then
        #expect(result.isFailure)
        #expect(result.success == nil)
        #expect(result.failure != nil)
        #expect(result.failure?.asAFError?.isInputDataNilOrZeroLength == true)
    }

    @Test
    func decodableResponseSerializerSucceedsWhenDataIsNilWithEmptyResponseStatusCode() {
        // Given
        let serializer = DecodableResponseSerializer<DecodableValue>()
        let response = HTTPURLResponse(statusCode: 204)

        // When
        let result = Result { try serializer.serialize(request: nil, response: response, data: nil, error: nil) }

        // Then
        #expect(result.isSuccess)
        #expect(result.success != nil)
        #expect(result.failure == nil)
    }

    @Test
    func decodableResponseSerializerSucceedsWhenDataIsNilWithEmptyTypeAndEmptyResponseStatusCode() {
        // Given
        let serializer = DecodableResponseSerializer<Empty>()
        let response = HTTPURLResponse(statusCode: 204)

        // When
        let result = Result { try serializer.serialize(request: nil, response: response, data: nil, error: nil) }

        // Then
        #expect(result.isSuccess)
        #expect(result.success == Empty.value)
        #expect(result.failure == nil)
    }

    @Test
    func decodableResponseSerializerSucceedsWhenDataIsNilWithGETRequestAnd204ResponseStatusCode() {
        // Given
        let serializer = DecodableResponseSerializer<Empty>()
        let request = Endpoint().urlRequest
        let response = HTTPURLResponse(statusCode: 204)

        // When
        let result = Result { try serializer.serialize(request: request, response: response, data: nil, error: nil) }

        // Then
        #expect(result.isSuccess)
        #expect(result.success == Empty.value)
        #expect(result.failure == nil)
    }

    @Test
    func decodableResponseSerializerSucceedsWhenDataIsNilWithGETRequestAnd205ResponseStatusCode() {
        // Given
        let serializer = DecodableResponseSerializer<Empty>()
        let request = Endpoint().urlRequest
        let response = HTTPURLResponse(statusCode: 205)

        // When
        let result = Result { try serializer.serialize(request: request, response: response, data: nil, error: nil) }

        // Then
        #expect(result.isSuccess)
        #expect(result.success == Empty.value)
        #expect(result.failure == nil)
    }

    @Test
    func decodableResponseSerializerSucceedsWhenDataIsNilWithHEADRequestAnd200ResponseStatusCode() {
        // Given
        let serializer = DecodableResponseSerializer<Empty>()
        let request = Endpoint(method: .head).urlRequest
        let response = HTTPURLResponse(statusCode: 200)

        // When
        let result = Result { try serializer.serialize(request: request, response: response, data: nil, error: nil) }

        // Then
        #expect(result.isSuccess)
        #expect(result.success == Empty.value)
        #expect(result.failure == nil)
    }

    @Test
    func decodableResponseSerializerSucceedsWhenDataIsNilWithEmptyResponseConformingTypeAndEmptyResponseStatusCode() {
        // Given
        let serializer = DecodableResponseSerializer<Bool>()
        let response = HTTPURLResponse(statusCode: 204)

        // When
        let result = Result { try serializer.serialize(request: nil, response: response, data: nil, error: nil) }

        // Then
        #expect(result.isSuccess)
        #expect(result.success != nil)
        #expect(result.failure == nil)
    }

    @Test
    func decodableResponseSerializerFailsWhenDataIsNilWithEmptyResponseNonconformingTypeAndEmptyResponseStatusCode() {
        // Given
        let serializer = DecodableResponseSerializer<Int>()
        let response = HTTPURLResponse(statusCode: 204)

        // When
        let result = Result { try serializer.serialize(request: nil, response: response, data: nil, error: nil) }

        // Then
        #expect(result.isFailure)
        #expect(result.success == nil)
        #expect(result.failure != nil)
        #expect(result.failure?.asAFError?.isInvalidEmptyResponse == true)
    }
}

// MARK: -

@Suite
struct DownloadResponseSerializationTestCase {
    // MARK: Properties

    private let error = AFError.responseSerializationFailed(reason: .inputFileNil)

    private var jsonEmptyDataFileURL: URL { url(forResource: "empty_data", withExtension: "json") }
    private var jsonValidDataFileURL: URL { url(forResource: "valid_data", withExtension: "json") }
    private var jsonInvalidDataFileURL: URL { url(forResource: "invalid_data", withExtension: "json") }

    private var stringEmptyDataFileURL: URL { url(forResource: "empty_string", withExtension: "txt") }
    private var stringUTF8DataFileURL: URL { url(forResource: "utf8_string", withExtension: "txt") }
    private var stringUTF32DataFileURL: URL { url(forResource: "utf32_string", withExtension: "txt") }

    private var invalidFileURL: URL { URL(fileURLWithPath: "/this/file/does/not/exist.txt") }

    // MARK: Tests - Data Response Serializer

    @Test
    func dataResponseSerializerSucceedsWhenFileDataIsNotNil() {
        // Given
        let serializer = DataResponseSerializer()

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: nil, fileURL: jsonValidDataFileURL, error: nil) }

        // Then
        #expect(result.isSuccess)
        #expect(result.success != nil)
        #expect(result.failure == nil)
    }

    @Test
    func dataResponseSerializerFailsWhenFileDataIsEmpty() {
        // Given
        let serializer = DataResponseSerializer()

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: nil, fileURL: jsonEmptyDataFileURL, error: nil) }

        // Then
        #expect(result.isFailure)
        #expect(result.success == nil)
        #expect(result.failure != nil)
        #expect(result.failure?.asAFError?.isInputDataNilOrZeroLength == true)
    }

    @Test
    func dataResponseSerializerFailsWhenFileURLIsNil() {
        // Given
        let serializer = DataResponseSerializer()

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: nil, fileURL: nil, error: nil) }

        // Then
        #expect(result.isFailure)
        #expect(result.success == nil)
        #expect(result.failure != nil)
        #expect(result.failure?.asAFError?.isInputFileNil == true)
    }

    @Test
    func dataResponseSerializerFailsWhenFileURLIsInvalid() {
        // Given
        let serializer = DataResponseSerializer()

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: nil, fileURL: invalidFileURL, error: nil) }

        // Then
        #expect(result.isFailure)
        #expect(result.success == nil)
        #expect(result.failure != nil)
        #expect(result.failure?.asAFError?.isInputFileReadFailed == true)
    }

    @Test
    func dataResponseSerializerFailsWhenErrorIsNotNil() {
        // Given
        let serializer = DataResponseSerializer()

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: nil, fileURL: nil, error: error) }

        // Then
        #expect(result.isFailure)
        #expect(result.success == nil)
        #expect(result.failure != nil)
        #expect(result.failure?.asAFError?.isInputFileNil == true)
    }

    @Test
    func dataResponseSerializerFailsWhenFileURLIsNilWithNonEmptyResponseStatusCode() {
        // Given
        let serializer = DataResponseSerializer()
        let response = HTTPURLResponse(statusCode: 200)

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: response, fileURL: nil, error: nil) }

        // Then
        #expect(result.isFailure)
        #expect(result.success == nil)
        #expect(result.failure != nil)
        #expect(result.failure?.asAFError?.isInputFileNil == true)
    }

    @Test
    func dataResponseSerializerSucceedsWhenDataIsNilWithEmptyResponseStatusCode() {
        // Given
        let serializer = DataResponseSerializer()
        let response = HTTPURLResponse(statusCode: 205)

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: response, fileURL: jsonEmptyDataFileURL, error: nil) }

        // Then
        #expect(result.isSuccess)
        #expect(result.success != nil)
        #expect(result.failure == nil)
        #expect(result.success?.isEmpty == true)
    }

    // MARK: Tests - String Response Serializer

    @Test
    func stringResponseSerializerFailsWhenFileURLIsNil() {
        // Given
        let serializer = StringResponseSerializer()

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: nil, fileURL: nil, error: nil) }

        // Then
        #expect(result.isFailure)
        #expect(result.success == nil)
        #expect(result.failure != nil)
        #expect(result.failure?.asAFError?.isInputFileNil == true)
    }

    @Test
    func stringResponseSerializerFailsWhenFileURLIsInvalid() {
        // Given
        let serializer = StringResponseSerializer()

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: nil, fileURL: invalidFileURL, error: nil) }

        // Then
        #expect(result.isSuccess == false)
        #expect(result.success == nil)
        #expect(result.failure != nil)
        #expect(result.failure?.asAFError?.isInputFileReadFailed == true)
    }

    @Test
    func stringResponseSerializerFailsWhenFileDataIsEmpty() {
        // Given
        let serializer = StringResponseSerializer()

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: nil, fileURL: stringEmptyDataFileURL, error: nil) }

        // Then
        #expect(result.isFailure)
        #expect(result.success == nil)
        #expect(result.failure != nil)
        #expect(result.failure?.asAFError?.isInputDataNilOrZeroLength == true)
    }

    @Test
    func stringResponseSerializerSucceedsWithUTF8DataAndNoProvidedEncoding() {
        // Given
        let serializer = StringResponseSerializer()

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: nil, fileURL: stringUTF8DataFileURL, error: nil) }

        // Then
        #expect(result.isSuccess)
        #expect(result.success != nil)
        #expect(result.failure == nil)
    }

    @Test
    func stringResponseSerializerSucceedsWithUTF8DataAndUTF8ProvidedEncoding() {
        // Given
        let serializer = StringResponseSerializer(encoding: .utf8)

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: nil, fileURL: stringUTF8DataFileURL, error: nil) }

        // Then
        #expect(result.isSuccess)
        #expect(result.success != nil)
        #expect(result.failure == nil)
    }

    @Test
    func stringResponseSerializerSucceedsWithUTF8DataUsingResponseTextEncodingName() {
        // Given
        let serializer = StringResponseSerializer()
        let response = HTTPURLResponse(statusCode: 200, headers: ["Content-Type": "image/jpeg; charset=utf-8"])

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: response, fileURL: stringUTF8DataFileURL, error: nil) }

        // Then
        #expect(result.isSuccess)
        #expect(result.success != nil)
        #expect(result.failure == nil)
    }

    @Test
    func stringResponseSerializerFailsWithUTF32DataAndUTF8ProvidedEncoding() {
        // Given
        let serializer = StringResponseSerializer(encoding: .utf8)

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: nil, fileURL: stringUTF32DataFileURL, error: nil) }

        // Then
        #expect(result.isFailure)
        #expect(result.success == nil)
        #expect(result.failure != nil)
        #expect(result.failure?.asAFError?.isStringSerializationFailed == true)
        #expect(result.failure?.asAFError?.failedStringEncoding == .utf8)
    }

    @Test
    func stringResponseSerializerFailsWithUTF32DataAndUTF8ResponseEncoding() {
        // Given
        let serializer = StringResponseSerializer()
        let response = HTTPURLResponse(statusCode: 200, headers: ["Content-Type": "image/jpeg; charset=utf-8"])

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: response, fileURL: stringUTF32DataFileURL, error: nil) }

        // Then
        #expect(result.isFailure)
        #expect(result.success == nil)
        #expect(result.failure != nil)
        #expect(result.failure?.asAFError?.isStringSerializationFailed == true)
        #expect(result.failure?.asAFError?.failedStringEncoding == .utf8)
    }

    @Test
    func stringResponseSerializerFailsWhenErrorIsNotNil() {
        // Given
        let serializer = StringResponseSerializer()

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: nil, fileURL: nil, error: error) }

        // Then
        #expect(result.isFailure)
        #expect(result.success == nil)
        #expect(result.failure != nil)
        #expect(result.failure?.asAFError?.isInputFileNil == true)
    }

    @Test
    func stringResponseSerializerFailsWhenDataIsNilWithNonEmptyResponseStatusCode() {
        // Given
        let serializer = StringResponseSerializer()
        let response = HTTPURLResponse(statusCode: 200)

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: response, fileURL: nil, error: nil) }

        // Then
        #expect(result.isFailure)
        #expect(result.success == nil)
        #expect(result.failure != nil)
        #expect(result.failure?.asAFError?.isInputFileNil == true)
    }

    @Test
    func stringResponseSerializerSucceedsWhenDataIsNilWithEmptyResponseStatusCode() {
        // Given
        let serializer = StringResponseSerializer()
        let response = HTTPURLResponse(statusCode: 204)

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: response, fileURL: stringEmptyDataFileURL, error: nil) }

        // Then
        #expect(result.isSuccess)
        #expect(result.success != nil)
        #expect(result.failure == nil)
        #expect(result.success == "")
    }

    // MARK: Tests - JSON Response Serializer

    @Test
    @available(*, deprecated)
    func jsonResponseSerializerFailsWhenFileURLIsNil() {
        // Given
        let serializer = JSONResponseSerializer()

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: nil, fileURL: nil, error: nil) }

        // Then
        #expect(result.isFailure)
        #expect(result.success == nil)
        #expect(result.failure != nil)
        #expect(result.failure?.asAFError?.isInputFileNil == true)
    }

    @Test
    @available(*, deprecated)
    func jsonResponseSerializerFailsWhenFileURLIsInvalid() {
        // Given
        let serializer = JSONResponseSerializer()

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: nil, fileURL: invalidFileURL, error: nil) }

        // Then
        #expect(result.isFailure)
        #expect(result.success == nil)
        #expect(result.failure != nil)
        #expect(result.failure?.asAFError?.isInputFileReadFailed == true)
    }

    @Test
    @available(*, deprecated)
    func jsonResponseSerializerFailsWhenFileDataIsEmpty() {
        // Given
        let serializer = JSONResponseSerializer()

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: nil, fileURL: jsonEmptyDataFileURL, error: nil) }

        // Then
        #expect(result.isFailure)
        #expect(result.success == nil)
        #expect(result.failure != nil)
        #expect(result.failure?.asAFError?.isInputDataNilOrZeroLength == true)
    }

    @Test
    @available(*, deprecated)
    func jsonResponseSerializerSucceedsWhenDataIsValidJSON() {
        // Given
        let serializer = JSONResponseSerializer()

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: nil, fileURL: jsonValidDataFileURL, error: nil) }

        // Then
        #expect(result.isSuccess)
        #expect(result.success != nil)
        #expect(result.failure == nil)
    }

    @Test
    @available(*, deprecated)
    func jsonResponseSerializerFailsWhenDataIsInvalidJSON() {
        // Given
        let serializer = JSONResponseSerializer()

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: nil, fileURL: jsonInvalidDataFileURL, error: nil) }

        // Then
        #expect(result.isFailure)
        #expect(result.success == nil)
        #expect(result.failure != nil)
        #expect(result.failure?.asAFError?.isJSONSerializationFailed == true)
        #expect((result.failure?.asAFError?.underlyingError as? CocoaError)?.code == .propertyListReadCorrupt)
    }

    @Test
    @available(*, deprecated)
    func jsonResponseSerializerFailsWhenErrorIsNotNil() {
        // Given
        let serializer = JSONResponseSerializer()

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: nil, fileURL: nil, error: error) }

        // Then
        #expect(result.isFailure)
        #expect(result.success == nil)
        #expect(result.failure != nil)
        #expect(result.failure?.asAFError?.isInputFileNil == true)
    }

    @Test
    @available(*, deprecated)
    func jsonResponseSerializerFailsWhenDataIsNilWithNonEmptyResponseStatusCode() {
        // Given
        let serializer = JSONResponseSerializer()
        let response = HTTPURLResponse(statusCode: 200)

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: response, fileURL: nil, error: nil) }

        // Then
        #expect(result.isFailure)
        #expect(result.success == nil)
        #expect(result.failure != nil)
        #expect(result.failure?.asAFError?.isInputFileNil == true)
    }

    @Test
    @available(*, deprecated)
    func jsonResponseSerializerSucceedsWhenDataIsNilWithEmptyResponseStatusCode() {
        // Given
        let serializer = JSONResponseSerializer()
        let response = HTTPURLResponse(statusCode: 205)

        // When
        let result = Result { try serializer.serializeDownload(request: nil, response: response, fileURL: jsonEmptyDataFileURL, error: nil) }

        // Then
        #expect(result.isSuccess)
        #expect(result.success != nil)
        #expect(result.failure == nil)

        #expect(result.success as? NSNull == NSNull())
    }
}

final class CustomResponseSerializerTests: BaseTestCase {
    @MainActor
    func testThatCustomResponseSerializersCanBeWrittenWithoutCompilerIssues() {
        // Given
        let session = stored(Session())
        final class UselessResponseSerializer: ResponseSerializer {
            func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: (any Error)?) throws -> Data? {
                data
            }
        }
        let serializer = UselessResponseSerializer()
        let expectation = expectation(description: "request should finish")
        var data: Data?

        // When
        session.request(.default).response(responseSerializer: serializer) { response in
            data = response.data
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(data)
    }
}

@Suite
struct DataPreprocessorSerializationTests {
    struct DropFirst: DataPreprocessor {
        func preprocess(_ data: Data) throws -> Data {
            data.dropFirst()
        }
    }

    struct Throwing: DataPreprocessor {
        struct Error: Swift.Error {}

        func preprocess(_ data: Data) throws -> Data {
            throw Error()
        }
    }

    @Test
    func dataResponseSerializerProperlyCallsSuccessfulDataPreprocessor() {
        // Given
        let preprocessor = DropFirst()
        let serializer = DataResponseSerializer(dataPreprocessor: preprocessor)
        let data = Data("abcd".utf8)

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: data, error: nil) }

        // Then
        #expect(result.isSuccess)
        #expect(result.success == Data("bcd".utf8))
        #expect(result.failure == nil)
    }

    @Test
    func dataResponseSerializerProperlyReceivesErrorFromFailingDataPreprocessor() {
        // Given
        let preprocessor = Throwing()
        let serializer = DataResponseSerializer(dataPreprocessor: preprocessor)
        let data = Data("abcd".utf8)

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: data, error: nil) }

        // Then
        #expect(result.isFailure)
        #expect(result.success == nil)
        #expect(result.failure != nil)
    }

    @Test
    func stringResponseSerializerProperlyCallsSuccessfulDataPreprocessor() {
        // Given
        let preprocessor = DropFirst()
        let serializer = StringResponseSerializer(dataPreprocessor: preprocessor)
        let data = Data("abcd".utf8)

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: data, error: nil) }

        // Then
        #expect(result.isSuccess)
        #expect(result.success == "bcd")
        #expect(result.failure == nil)
    }

    @Test
    func stringResponseSerializerProperlyReceivesErrorFromFailingDataPreprocessor() {
        // Given
        let preprocessor = Throwing()
        let serializer = StringResponseSerializer(dataPreprocessor: preprocessor)
        let data = Data("abcd".utf8)

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: data, error: nil) }

        // Then
        #expect(result.isFailure)
        #expect(result.success == nil)
        #expect(result.failure != nil)
    }

    @Test
    @available(*, deprecated)
    func jsonResponseSerializerProperlyCallsSuccessfulDataPreprocessor() {
        // Given
        let preprocessor = DropFirst()
        let serializer = JSONResponseSerializer(dataPreprocessor: preprocessor)
        let data = Data("1\"abcd\"".utf8)

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: data, error: nil) }

        // Then
        #expect(result.isSuccess)
        #expect(result.success as? String == "abcd")
        #expect(result.failure == nil)
    }

    @Test
    @available(*, deprecated)
    func jsonResponseSerializerProperlyReceivesErrorFromFailingDataPreprocessor() {
        // Given
        let preprocessor = Throwing()
        let serializer = JSONResponseSerializer(dataPreprocessor: preprocessor)
        let data = Data("1\"abcd\"".utf8)

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: data, error: nil) }

        // Then
        #expect(result.isFailure)
        #expect(result.success == nil)
        #expect(result.failure != nil)
    }

    @Test
    func decodableResponseSerializerProperlyCallsSuccessfulDataPreprocessor() {
        // Given
        let preprocessor = DropFirst()
        let serializer = DecodableResponseSerializer<DecodableResponseSerializerTests.DecodableValue>(dataPreprocessor: preprocessor)
        let data = Data("1{\"string\":\"string\"}".utf8)

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: data, error: nil) }

        // Then
        #expect(result.isSuccess)
        #expect(result.success?.string == "string")
        #expect(result.failure == nil)
    }

    @Test
    func decodableResponseSerializerProperlyReceivesErrorFromFailingDataPreprocessor() {
        // Given
        let preprocessor = Throwing()
        let serializer = DecodableResponseSerializer<DecodableResponseSerializerTests.DecodableValue>(dataPreprocessor: preprocessor)
        let data = Data("1{\"string\":\"string\"}".utf8)

        // When
        let result = Result { try serializer.serialize(request: nil, response: nil, data: data, error: nil) }

        // Then
        #expect(result.isFailure)
        #expect(result.success == nil)
        #expect(result.failure != nil)
    }
}

@Suite
struct DataPreprocessorTests {
    @Test
    func passthroughPreprocessorPassesDataThrough() {
        // Given
        let preprocessor = PassthroughPreprocessor()
        let data = Data("data".utf8)

        // When
        let result = Result { try preprocessor.preprocess(data) }

        // Then
        #expect(data == result.success, "Preprocessed data should equal original data.")
    }

    @Test
    func googleXSSIPreprocessorProperlyPreprocessesData() {
        // Given
        let preprocessor = GoogleXSSIPreprocessor()
        let data = Data(")]}',\nabcd".utf8)

        // When
        let result = Result { try preprocessor.preprocess(data) }

        // Then
        #expect(result.success.map { String(decoding: $0, as: UTF8.self) } == "abcd")
    }

    @Test
    func googleXSSIPreprocessorDoesNotChangeDataIfPrefixDoesNotMatch() {
        // Given
        let preprocessor = GoogleXSSIPreprocessor()
        let data = Data("abcd".utf8)

        // When
        let result = Result { try preprocessor.preprocess(data) }

        // Then
        #expect(result.success.map { String(decoding: $0, as: UTF8.self) } == "abcd")
    }
}

@Suite
struct StaticDataPreprocessorTests {
    func consumeDataPreprocessor(_ dataPreprocessor: any DataPreprocessor) {
        _ = dataPreprocessor
    }

    @Test
    func passthroughCanBeCreatedStaticallyFromProtocol() {
        // Given, When, Then
        consumeDataPreprocessor(.passthrough)
    }

    @Test
    func googleXSSICanBeCreatedStaticallyFromProtocol() {
        // Given, When, Then
        consumeDataPreprocessor(.googleXSSI)
    }
}

extension HTTPURLResponse {
    convenience init(statusCode: Int, headers: HTTPHeaders? = nil) {
        let url = Endpoint().url
        #if os(watchOS) || os(Linux) || os(Windows) || os(Android) || os(FreeBSD)
        let httpVersion = "HTTP/1.1"
        #else
        let httpVersion = String(kCFHTTPVersion1_1)
        #endif
        self.init(url: url, statusCode: statusCode, httpVersion: httpVersion, headerFields: headers?.dictionary)!
    }
}
