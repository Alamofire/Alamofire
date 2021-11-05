//
//  ParameterEncoderTests.swift
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
import XCTest

final class JSONParameterEncoderTests: BaseTestCase {
    func testThatDataIsProperlyEncodedAndProperContentTypeIsSet() throws {
        // Given
        let encoder = JSONParameterEncoder()
        let request = Endpoint().urlRequest

        // When
        let newRequest = try encoder.encode(TestParameters.default, into: request)

        // Then
        XCTAssertEqual(newRequest.headers["Content-Type"], "application/json")
        XCTAssertEqual(newRequest.httpBody?.asString, "{\"property\":\"property\"}")
    }

    func testThatDataIsProperlyEncodedButContentTypeIsNotSetIfRequestAlreadyHasAContentType() throws {
        // Given
        let encoder = JSONParameterEncoder()
        var request = Endpoint().urlRequest
        request.headers.update(.contentType("type"))

        // When
        let newRequest = try encoder.encode(TestParameters.default, into: request)

        // Then
        XCTAssertEqual(newRequest.headers["Content-Type"], "type")
        XCTAssertEqual(newRequest.httpBody?.asString, "{\"property\":\"property\"}")
    }

    func testThatJSONEncoderCanBeCustomized() throws {
        // Given
        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = .prettyPrinted
        let encoder = JSONParameterEncoder(encoder: jsonEncoder)
        let request = Endpoint().urlRequest

        // When
        let newRequest = try encoder.encode(TestParameters.default, into: request)

        // Then
        let expected = """
        {
          "property" : "property"
        }
        """
        XCTAssertEqual(newRequest.httpBody?.asString, expected)
    }

    func testThatJSONEncoderDefaultWorks() throws {
        // Given
        let encoder = JSONParameterEncoder.default
        let request = Endpoint().urlRequest

        // When
        let encoded = try encoder.encode(TestParameters.default, into: request)

        // Then
        let expected = """
        {"property":"property"}
        """
        XCTAssertEqual(encoded.httpBody?.asString, expected)
    }

    func testThatJSONEncoderPrettyPrintedPrintsPretty() throws {
        // Given
        let encoder = JSONParameterEncoder.prettyPrinted
        let request = Endpoint().urlRequest

        // When
        let encoded = try encoder.encode(TestParameters.default, into: request)

        // Then
        let expected = """
        {
          "property" : "property"
        }
        """
        XCTAssertEqual(encoded.httpBody?.asString, expected)
    }
}

final class SortedKeysJSONParameterEncoderTests: BaseTestCase {
    func testTestJSONEncoderSortedKeysHasSortedKeys() throws {
        guard #available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *) else { return }
        // Given
        let encoder = JSONParameterEncoder.sortedKeys
        let request = Endpoint().urlRequest

        // When
        let encoded = try encoder.encode(["z": "z", "a": "a", "p": "p"], into: request)

        // Then
        let expected = """
        {"a":"a","p":"p","z":"z"}
        """
        XCTAssertEqual(encoded.httpBody?.asString, expected)
    }
}

final class URLEncodedFormParameterEncoderTests: BaseTestCase {
    func testThatQueryIsBodyEncodedAndProperContentTypeIsSetForPOSTRequest() throws {
        // Given
        let encoder = URLEncodedFormParameterEncoder()
        let request = Endpoint(method: .post).urlRequest

        // When
        let newRequest = try encoder.encode(TestParameters.default, into: request)

        // Then
        XCTAssertEqual(newRequest.headers["Content-Type"], "application/x-www-form-urlencoded; charset=utf-8")
        XCTAssertEqual(newRequest.httpBody?.asString, "property=property")
    }

    func testThatQueryIsBodyEncodedButContentTypeIsNotSetWhenRequestAlreadyHasContentType() throws {
        // Given
        let encoder = URLEncodedFormParameterEncoder()
        var request = Endpoint(method: .post).urlRequest
        request.headers.update(.contentType("type"))

        // When
        let newRequest = try encoder.encode(TestParameters.default, into: request)

        // Then
        XCTAssertEqual(newRequest.headers["Content-Type"], "type")
        XCTAssertEqual(newRequest.httpBody?.asString, "property=property")
    }

    func testThatEncoderCanBeCustomized() throws {
        // Given
        let urlEncoder = URLEncodedFormEncoder(boolEncoding: .literal)
        let encoder = URLEncodedFormParameterEncoder(encoder: urlEncoder)
        let request = Endpoint().urlRequest

        // When
        let newRequest = try encoder.encode(["bool": true], into: request)

        // Then
        let components = URLComponents(url: newRequest.url!, resolvingAgainstBaseURL: false)
        XCTAssertEqual(components?.percentEncodedQuery, "bool=true")
    }

    func testThatQueryIsInURLWhenDestinationIsURLAndMethodIsPOST() throws {
        // Given
        let encoder = URLEncodedFormParameterEncoder(destination: .queryString)
        let request = Endpoint(method: .post).urlRequest

        // When
        let newRequest = try encoder.encode(TestParameters.default, into: request)

        // Then
        let components = URLComponents(url: newRequest.url!, resolvingAgainstBaseURL: false)
        XCTAssertEqual(components?.percentEncodedQuery, "property=property")
    }

    func testThatQueryIsNilWhenEncodableResultsInAnEmptyString() throws {
        // Given
        let encoder = URLEncodedFormParameterEncoder(destination: .queryString)
        let request = Endpoint().urlRequest

        // When
        let newRequest = try encoder.encode([String: String](), into: request)

        // Then
        let components = URLComponents(url: newRequest.url!, resolvingAgainstBaseURL: false)
        XCTAssertNil(components?.percentEncodedQuery)
    }
}

final class URLEncodedFormEncoderTests: BaseTestCase {
    func testEncoderThrowsErrorWhenAttemptingToEncodeNilInKeyedContainer() {
        // Given
        let encoder = URLEncodedFormEncoder()
        let parameters = FailingOptionalStruct(testedContainer: .keyed)

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertTrue(result.isFailure)
    }

    func testEncoderThrowsErrorWhenAttemptingToEncodeNilInUnkeyedContainer() {
        // Given
        let encoder = URLEncodedFormEncoder()
        let parameters = FailingOptionalStruct(testedContainer: .unkeyed)

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertTrue(result.isFailure)
    }

    func testEncoderCanEncodeDictionary() {
        // Given
        let encoder = URLEncodedFormEncoder()
        let parameters = ["a": "a"]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertEqual(result.success, "a=a")
    }

    func testEncoderCanEncodeDecimal() {
        // Given
        let encoder = URLEncodedFormEncoder()
        let decimal: Decimal = 1.0
        let parameters = ["a": decimal]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertEqual(result.success, "a=1")
    }

    func testEncoderCanEncodeDecimalWithHighPrecision() {
        // Given
        let encoder = URLEncodedFormEncoder()
        let decimal: Decimal = 1.123456
        let parameters = ["a": decimal]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertEqual(result.success, "a=1.123456")
    }

    func testEncoderCanEncodeDouble() {
        // Given
        let encoder = URLEncodedFormEncoder()
        let parameters = ["a": 1.0]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertEqual(result.success, "a=1.0")
    }

    func testEncoderCanEncodeFloat() {
        // Given
        let encoder = URLEncodedFormEncoder()
        let parameters: [String: Float] = ["a": 1.0]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertEqual(result.success, "a=1.0")
    }

    func testEncoderCanEncodeInt8() {
        // Given
        let encoder = URLEncodedFormEncoder()
        let parameters: [String: Int8] = ["a": 1]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertEqual(result.success, "a=1")
    }

    func testEncoderCanEncodeInt16() {
        // Given
        let encoder = URLEncodedFormEncoder()
        let parameters: [String: Int16] = ["a": 1]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertEqual(result.success, "a=1")
    }

    func testEncoderCanEncodeInt32() {
        // Given
        let encoder = URLEncodedFormEncoder()
        let parameters: [String: Int32] = ["a": 1]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertEqual(result.success, "a=1")
    }

    func testEncoderCanEncodeInt64() {
        // Given
        let encoder = URLEncodedFormEncoder()
        let parameters: [String: Int64] = ["a": 1]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertEqual(result.success, "a=1")
    }

    func testEncoderCanEncodeUInt() {
        // Given
        let encoder = URLEncodedFormEncoder()
        let parameters: [String: UInt] = ["a": 1]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertEqual(result.success, "a=1")
    }

    func testEncoderCanEncodeUInt8() {
        // Given
        let encoder = URLEncodedFormEncoder()
        let parameters: [String: UInt8] = ["a": 1]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertEqual(result.success, "a=1")
    }

    func testEncoderCanEncodeUInt16() {
        // Given
        let encoder = URLEncodedFormEncoder()
        let parameters: [String: UInt16] = ["a": 1]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertEqual(result.success, "a=1")
    }

    func testEncoderCanEncodeUInt32() {
        // Given
        let encoder = URLEncodedFormEncoder()
        let parameters: [String: UInt32] = ["a": 1]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertEqual(result.success, "a=1")
    }

    func testEncoderCanEncodeUInt64() {
        // Given
        let encoder = URLEncodedFormEncoder()
        let parameters: [String: UInt64] = ["a": 1]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertEqual(result.success, "a=1")
    }

    func testThatNestedDictionariesHaveBracketedKeys() {
        // Given
        let encoder = URLEncodedFormEncoder()
        let parameters = ["a": ["b": "b"]]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertEqual(result.success, "a%5Bb%5D=b")
    }

    func testThatEncodableStructCanBeEncoded() {
        // Given
        let encoder = URLEncodedFormEncoder()
        let parameters = EncodableStruct()

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        let expected = "five%5Ba%5D=a&four%5B%5D=1&four%5B%5D=2&four%5B%5D=3&one=one&seven%5Ba%5D=a&six%5Ba%5D%5Bb%5D=b&three=1&two=2"
        XCTAssertEqual(result.success, expected)
    }

    func testThatManuallyEncodableStructCanBeEncoded() {
        // Given
        let encoder = URLEncodedFormEncoder()
        let parameters = ManuallyEncodableStruct()

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        let expected = "root%5B%5D%5B%5D%5B%5D=1&root%5B%5D%5B%5D%5B%5D=2&root%5B%5D%5B%5D%5B%5D=3&root%5B%5D%5B%5D=1&root%5B%5D%5B%5D=2&root%5B%5D%5B%5D=3&root%5B%5D%5Ba%5D%5Bstring%5D=string"
        XCTAssertEqual(result.success, expected)
    }

    func testThatEncodableClassWithNoInheritanceCanBeEncoded() {
        // Given
        let encoder = URLEncodedFormEncoder()
        let parameters = EncodableSuperclass()

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertEqual(result.success, "one=one&three=1&two=2")
    }

    func testThatEncodableSubclassCanBeEncoded() {
        // Given
        let encoder = URLEncodedFormEncoder()
        let parameters = EncodableSubclass()

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        let expected = "five%5Ba%5D=a&five%5Bb%5D=b&four%5B%5D=1&four%5B%5D=2&four%5B%5D=3&one=one&three=1&two=2"
        XCTAssertEqual(result.success, expected)
    }

    func testThatEncodableSubclassCanBeEncodedInImplementationOrderWhenAlphabetizeKeysIsFalse() {
        // Given
        let encoder = URLEncodedFormEncoder(alphabetizeKeyValuePairs: false)
        let parameters = EncodableStruct()

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        let expected = "one=one&two=2&three=1&four%5B%5D=1&four%5B%5D=2&four%5B%5D=3&five%5Ba%5D=a&six%5Ba%5D%5Bb%5D=b&seven%5Ba%5D=a"
        XCTAssertEqual(result.success, expected)
    }

    func testThatManuallyEncodableSubclassCanBeEncoded() {
        // Given
        let encoder = URLEncodedFormEncoder()
        let parameters = ManuallyEncodableSubclass()

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        let expected = "five%5Ba%5D=a&five%5Bb%5D=b&four%5Bfive%5D=2&four%5Bfour%5D=one"
        XCTAssertEqual(result.success, expected)
    }

    func testThatARootArrayCannotBeEncoded() {
        // Given
        let encoder = URLEncodedFormEncoder()
        let parameters = [1]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertFalse(result.isSuccess)
    }

    func testThatARootValueCannotBeEncoded() {
        // Given
        let encoder = URLEncodedFormEncoder()
        let parameters = "string"

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertFalse(result.isSuccess)
    }

    func testThatOptionalValuesCannotBeEncoded() {
        // Given
        let encoder = URLEncodedFormEncoder()
        let parameters: [String: String?] = ["string": nil]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertFalse(result.isSuccess)
    }

    func testThatEncodableSuperclassCanBeEncodedWithIndexInBrackets() {
        // Given
        let encoder = URLEncodedFormEncoder(arrayEncoding: .indexInBrackets)
        let parameters = ["foo": [EncodableSuperclass()]]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertEqual(result.success, "foo%5B0%5D%5Bone%5D=one&foo%5B0%5D%5Bthree%5D=1&foo%5B0%5D%5Btwo%5D=2")
    }

    func testThatEncodableSubclassCanBeEncodedWithIndexInBrackets() {
        // Given
        let encoder = URLEncodedFormEncoder(arrayEncoding: .indexInBrackets)
        let parameters = EncodableSubclass()

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        let expected = "five%5Ba%5D=a&five%5Bb%5D=b&four%5B0%5D=1&four%5B1%5D=2&four%5B2%5D=3&one=one&three=1&two=2"
        XCTAssertEqual(result.success, expected)
    }

    func testThatManuallyEncodableSubclassCanBeEncodedWithIndexInBrackets() {
        // Given
        let encoder = URLEncodedFormEncoder(arrayEncoding: .indexInBrackets)
        let parameters = ManuallyEncodableSubclass()

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        let expected = "five%5Ba%5D=a&five%5Bb%5D=b&four%5Bfive%5D=2&four%5Bfour%5D=one"
        XCTAssertEqual(result.success, expected)
    }

    func testThatEncodableStructCanBeEncodedWithIndexInBrackets() {
        // Given
        let encoder = URLEncodedFormEncoder(arrayEncoding: .indexInBrackets)
        let parameters = EncodableStruct()

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        let expected = "five%5Ba%5D=a&four%5B0%5D=1&four%5B1%5D=2&four%5B2%5D=3&one=one&seven%5Ba%5D=a&six%5Ba%5D%5Bb%5D=b&three=1&two=2"
        XCTAssertEqual(result.success, expected)
    }

    func testThatManuallyEncodableStructCanBeEncodedWithIndexInBrackets() {
        // Given
        let encoder = URLEncodedFormEncoder(arrayEncoding: .indexInBrackets)
        let parameters = ManuallyEncodableStruct()

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // then
        let expected = "root%5B0%5D%5B0%5D=1&root%5B0%5D%5B1%5D=2&root%5B0%5D%5B2%5D=3&root%5B1%5D%5Ba%5D%5Bstring%5D=string&root%5B2%5D%5B0%5D%5B0%5D=1&root%5B2%5D%5B0%5D%5B1%5D=2&root%5B2%5D%5B0%5D%5B2%5D=3"
        XCTAssertEqual(result.success, expected)
    }

    func testThatArrayNestedDictionaryIntValueCanBeEncodedWithIndexInBrackets() {
        // Given
        let encoder = URLEncodedFormEncoder(arrayEncoding: .indexInBrackets)
        let parameters = ["foo": [["bar": 2], ["qux": 3], ["quy": 4]]]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertEqual(result.success, "foo%5B0%5D%5Bbar%5D=2&foo%5B1%5D%5Bqux%5D=3&foo%5B2%5D%5Bquy%5D=4")
    }

    func testThatArrayNestedDictionaryStringValueCanBeEncodedWithIndexInBrackets() {
        // Given
        let encoder = URLEncodedFormEncoder(arrayEncoding: .indexInBrackets)
        let parameters = ["foo": [["bar": "2"], ["qux": "3"], ["quy": "4"]]]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertEqual(result.success, "foo%5B0%5D%5Bbar%5D=2&foo%5B1%5D%5Bqux%5D=3&foo%5B2%5D%5Bquy%5D=4")
    }

    func testThatArrayNestedDictionaryBoolValueCanBeEncodedWithIndexInBrackets() {
        // Given
        let encoder = URLEncodedFormEncoder(arrayEncoding: .indexInBrackets)
        let parameters = ["foo": [["bar": true], ["qux": false], ["quy": true]]]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertEqual(result.success, "foo%5B0%5D%5Bbar%5D=1&foo%5B1%5D%5Bqux%5D=0&foo%5B2%5D%5Bquy%5D=1")
    }

    func testThatArraysCanBeEncodedWithoutBrackets() {
        // Given
        let encoder = URLEncodedFormEncoder(arrayEncoding: .noBrackets)
        let parameters = ["array": [1, 2]]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertEqual(result.success, "array=1&array=2")
    }

    func testThatBoolsCanBeLiteralEncoded() {
        // Given
        let encoder = URLEncodedFormEncoder(boolEncoding: .literal)
        let parameters = ["bool": true]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertEqual(result.success, "bool=true")
    }

    func testThatDataCanBeEncoded() {
        // Given
        let encoder = URLEncodedFormEncoder()
        let parameters = ["data": Data("data".utf8)]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertEqual(result.success, "data=ZGF0YQ%3D%3D")
    }

    func testThatCustomDataEncodingFailsWhenErrorIsThrown() {
        // Given
        struct DataEncodingError: Error {}

        let encoder = URLEncodedFormEncoder(dataEncoding: .custom { _ in throw DataEncodingError() })
        let parameters = ["data": Data("data".utf8)]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertTrue(result.failure is DataEncodingError)
    }

    func testThatDatesCanBeEncoded() {
        // Given
        let encoder = URLEncodedFormEncoder(dateEncoding: .deferredToDate)
        let parameters = ["date": Date(timeIntervalSinceReferenceDate: 123.456)]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertEqual(result.success, "date=123.456")
    }

    func testThatDatesCanBeEncodedAsSecondsSince1970() {
        // Given
        let encoder = URLEncodedFormEncoder(dateEncoding: .secondsSince1970)
        let parameters = ["date": Date(timeIntervalSinceReferenceDate: 123.456)]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertEqual(result.success, "date=978307323.456")
    }

    func testThatDatesCanBeEncodedAsMillisecondsSince1970() {
        // Given
        let encoder = URLEncodedFormEncoder(dateEncoding: .millisecondsSince1970)
        let parameters = ["date": Date(timeIntervalSinceReferenceDate: 123.456)]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertEqual(result.success, "date=978307323456.0")
    }

    func testThatDatesCanBeEncodedAsISO8601Formatted() {
        // Given
        let encoder = URLEncodedFormEncoder(dateEncoding: .iso8601)
        let parameters = ["date": Date(timeIntervalSinceReferenceDate: 123.456)]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertEqual(result.success, "date=2001-01-01T00%3A02%3A03Z")
    }

    func testThatDatesCanBeEncodedAsFormatted() {
        // Given
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSS"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        let encoder = URLEncodedFormEncoder(dateEncoding: .formatted(dateFormatter))
        let parameters = ["date": Date(timeIntervalSinceReferenceDate: 123.456)]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertEqual(result.success, "date=2001-01-01%2000%3A02%3A03.4560")
    }

    func testThatDatesCanBeEncodedAsCustomFormatted() {
        // Given
        let encoder = URLEncodedFormEncoder(dateEncoding: .custom { "\($0.timeIntervalSinceReferenceDate)" })
        let parameters = ["date": Date(timeIntervalSinceReferenceDate: 123.456)]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertEqual(result.success, "date=123.456")
    }

    func testEncoderThrowsErrorWhenCustomDateEncodingFails() {
        // Given
        struct DateEncodingError: Error {}

        let encoder = URLEncodedFormEncoder(dateEncoding: .custom { _ in throw DateEncodingError() })
        let parameters = ["date": Date(timeIntervalSinceReferenceDate: 123.456)]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertTrue(result.isFailure)
        XCTAssertTrue(result.failure is DateEncodingError)
    }

    func testThatKeysCanBeEncodedIntoSnakeCase() {
        // Given
        let encoder = URLEncodedFormEncoder(keyEncoding: .convertToSnakeCase)
        let parameters = ["oneTwoThree": "oneTwoThree"]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertEqual(result.success, "one_two_three=oneTwoThree")
    }

    func testThatKeysCanBeEncodedIntoKebabCase() {
        // Given
        let encoder = URLEncodedFormEncoder(keyEncoding: .convertToKebabCase)
        let parameters = ["oneTwoThree": "oneTwoThree"]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertEqual(result.success, "one-two-three=oneTwoThree")
    }

    func testThatKeysCanBeEncodedIntoACapitalizedString() {
        // Given
        let encoder = URLEncodedFormEncoder(keyEncoding: .capitalized)
        let parameters = ["oneTwoThree": "oneTwoThree"]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertEqual(result.success, "OneTwoThree=oneTwoThree")
    }

    func testThatKeysCanBeEncodedIntoALowercasedString() {
        // Given
        let encoder = URLEncodedFormEncoder(keyEncoding: .lowercased)
        let parameters = ["oneTwoThree": "oneTwoThree"]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertEqual(result.success, "onetwothree=oneTwoThree")
    }

    func testThatKeysCanBeEncodedIntoAnUppercasedString() {
        // Given
        let encoder = URLEncodedFormEncoder(keyEncoding: .uppercased)
        let parameters = ["oneTwoThree": "oneTwoThree"]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertEqual(result.success, "ONETWOTHREE=oneTwoThree")
    }

    func testThatKeysCanBeCustomEncoded() {
        // Given
        let encoder = URLEncodedFormEncoder(keyEncoding: .custom { _ in "A" })
        let parameters = ["oneTwoThree": "oneTwoThree"]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertEqual(result.success, "A=oneTwoThree")
    }

    func testThatSpacesCanBeEncodedAsPluses() {
        // Given
        let encoder = URLEncodedFormEncoder(spaceEncoding: .plusReplaced)
        let parameters = ["spaces": "replace with spaces"]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertEqual(result.success, "spaces=replace+with+spaces")
    }

    func testThatEscapedCharactersCanBeCustomized() {
        // Given
        var allowed = CharacterSet.afURLQueryAllowed
        allowed.remove(charactersIn: "?/")
        let encoder = URLEncodedFormEncoder(allowedCharacters: allowed)
        let parameters = ["allowed": "?/"]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertEqual(result.success, "allowed=%3F%2F")
    }

    func testThatUnreservedCharactersAreNotPercentEscaped() {
        // Given
        let encoder = URLEncodedFormEncoder()
        let parameters = ["lowercase": "abcdefghijklmnopqrstuvwxyz",
                          "numbers": "0123456789",
                          "uppercase": "ABCDEFGHIJKLMNOPQRSTUVWXYZ"]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        let expected = "lowercase=abcdefghijklmnopqrstuvwxyz&numbers=0123456789&uppercase=ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        XCTAssertEqual(result.success, expected)
    }

    func testThatReservedCharactersArePercentEscaped() {
        // Given
        let encoder = URLEncodedFormEncoder()
        let generalDelimiters = ":#[]@"
        let subDelimiters = "!$&'()*+,;="
        let parameters = ["reserved": "\(generalDelimiters)\(subDelimiters)"]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertEqual(result.success, "reserved=%3A%23%5B%5D%40%21%24%26%27%28%29%2A%2B%2C%3B%3D")
    }

    func testThatIllegalASCIICharactersArePercentEscaped() {
        // Given
        let encoder = URLEncodedFormEncoder()
        let parameters = ["illegal": " \"#%<>[]\\^`{}|"]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertEqual(result.success, "illegal=%20%22%23%25%3C%3E%5B%5D%5C%5E%60%7B%7D%7C")
    }

    func testThatAmpersandsInKeysAndValuesArePercentEscaped() {
        // Given
        let encoder = URLEncodedFormEncoder()
        let parameters = ["foo&bar": "baz&qux", "foobar": "bazqux"]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertEqual(result.success, "foo%26bar=baz%26qux&foobar=bazqux")
    }

    func testThatQuestionMarksInKeysAndValuesAreNotPercentEscaped() {
        // Given
        let encoder = URLEncodedFormEncoder()
        let parameters = ["?foo?": "?bar?"]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertEqual(result.success, "?foo?=?bar?")
    }

    func testThatSlashesInKeysAndValuesAreNotPercentEscaped() {
        // Given
        let encoder = URLEncodedFormEncoder()
        let parameters = ["foo": "/bar/baz/qux"]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertEqual(result.success, "foo=/bar/baz/qux")
    }

    func testThatSpacesInKeysAndValuesArePercentEscaped() {
        // Given
        let encoder = URLEncodedFormEncoder()
        let parameters = [" foo ": " bar "]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertEqual(result.success, "%20foo%20=%20bar%20")
    }

    func testThatPlusesInKeysAndValuesArePercentEscaped() {
        // Given
        let encoder = URLEncodedFormEncoder()
        let parameters = ["+foo+": "+bar+"]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertEqual(result.success, "%2Bfoo%2B=%2Bbar%2B")
    }

    func testThatPercentsInKeysAndValuesArePercentEscaped() {
        // Given
        let encoder = URLEncodedFormEncoder()
        let parameters = ["percent%": "%25"]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        XCTAssertEqual(result.success, "percent%25=%2525")
    }

    func testThatNonLatinCharactersArePercentEscaped() {
        // Given
        let encoder = URLEncodedFormEncoder()
        let parameters = ["french": "français",
                          "japanese": "日本語",
                          "arabic": "العربية",
                          "emoji": "😃"]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        let expectedParameterValues = ["arabic=%D8%A7%D9%84%D8%B9%D8%B1%D8%A8%D9%8A%D8%A9",
                                       "emoji=%F0%9F%98%83",
                                       "french=fran%C3%A7ais",
                                       "japanese=%E6%97%A5%E6%9C%AC%E8%AA%9E"].joined(separator: "&")
        XCTAssertEqual(result.success, expectedParameterValues)
    }

    func testStringWithThousandsOfChineseCharactersIsPercentEscaped() {
        // Given
        let encoder = URLEncodedFormEncoder()
        let repeatedCount = 2000
        let parameters = ["chinese": String(repeating: "一二三四五六七八九十", count: repeatedCount)]

        // When
        let result = Result<String, Error> { try encoder.encode(parameters) }

        // Then
        let escaped = String(repeating: "%E4%B8%80%E4%BA%8C%E4%B8%89%E5%9B%9B%E4%BA%94%E5%85%AD%E4%B8%83%E5%85%AB%E4%B9%9D%E5%8D%81",
                             count: repeatedCount)
        let expected = "chinese=\(escaped)"
        XCTAssertEqual(result.success, expected)
    }
}

#if swift(>=5.5)
final class StaticParameterEncoderInstanceTests: BaseTestCase {
    func takeParameterEncoder(_ parameterEncoder: ParameterEncoder) {
        _ = parameterEncoder
    }

    func testThatJSONParameterEncoderCanBeCreatedStaticallyFromProtocol() {
        // Given, When, Then
        takeParameterEncoder(.json())
    }

    func testThatURLEncodedFormParameterEncoderCanBeCreatedStaticallyFromProtocol() {
        // Given, When, Then
        takeParameterEncoder(.urlEncodedForm())
    }
}
#endif

private struct EncodableStruct: Encodable {
    let one = "one"
    let two = 2
    let three = true
    let four = [1, 2, 3]
    let five = ["a": "a"]
    let six = ["a": ["b": "b"]]
    let seven = NestedEncodableStruct()
}

private struct NestedEncodableStruct: Encodable {
    let a = "a"
}

private class EncodableSuperclass: Encodable {
    let one = "one"
    let two = 2
    let three = true
}

private final class EncodableSubclass: EncodableSuperclass {
    let four = [1, 2, 3]
    let five = ["a": "a", "b": "b"]

    private enum CodingKeys: String, CodingKey {
        case four, five
    }

    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(four, forKey: .four)
        try container.encode(five, forKey: .five)
    }
}

private final class ManuallyEncodableSubclass: EncodableSuperclass {
    let four = [1, 2, 3]
    let five = ["a": "a", "b": "b"]

    private enum CodingKeys: String, CodingKey {
        case four, five
    }

    override func encode(to encoder: Encoder) throws {
        var keyedContainer = encoder.container(keyedBy: CodingKeys.self)

        try keyedContainer.encode(four, forKey: .four)
        try keyedContainer.encode(five, forKey: .five)

        let superEncoder = keyedContainer.superEncoder()
        var superContainer = superEncoder.container(keyedBy: CodingKeys.self)
        try superContainer.encode(one, forKey: .four)

        let keyedSuperEncoder = keyedContainer.superEncoder(forKey: .four)
        var superKeyedContainer = keyedSuperEncoder.container(keyedBy: CodingKeys.self)
        try superKeyedContainer.encode(two, forKey: .five)

        var unkeyedContainer = keyedContainer.nestedUnkeyedContainer(forKey: .four)
        let unkeyedSuperEncoder = unkeyedContainer.superEncoder()
        var keyedUnkeyedSuperContainer = unkeyedSuperEncoder.container(keyedBy: CodingKeys.self)
        try keyedUnkeyedSuperContainer.encode(one, forKey: .four)
    }
}

private struct ManuallyEncodableStruct: Encodable {
    let a = ["string": "string"]
    let b = [1, 2, 3]

    private enum RootKey: String, CodingKey {
        case root
    }

    private enum TypeKeys: String, CodingKey {
        case a, b
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: RootKey.self)

        var nestedKeyedContainer = container.nestedContainer(keyedBy: TypeKeys.self, forKey: .root)
        try nestedKeyedContainer.encode(a, forKey: .a)

        var nestedUnkeyedContainer = container.nestedUnkeyedContainer(forKey: .root)
        try nestedUnkeyedContainer.encode(b)

        var nestedUnkeyedKeyedContainer = nestedUnkeyedContainer.nestedContainer(keyedBy: TypeKeys.self)
        try nestedUnkeyedKeyedContainer.encode(a, forKey: .a)

        var nestedUnkeyedUnkeyedContainer = nestedUnkeyedContainer.nestedUnkeyedContainer()
        try nestedUnkeyedUnkeyedContainer.encode(b)
    }
}

private struct FailingOptionalStruct: Encodable {
    enum TestedContainer {
        case keyed, unkeyed
    }

    enum CodingKeys: String, CodingKey { case a }

    let testedContainer: TestedContainer

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch testedContainer {
        case .keyed:
            var nested = container.nestedContainer(keyedBy: CodingKeys.self, forKey: .a)
            try nested.encodeNil(forKey: .a)
        case .unkeyed:
            var nested = container.nestedUnkeyedContainer(forKey: .a)
            try nested.encodeNil()
        }
    }
}
