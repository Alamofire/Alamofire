//
//  ParameterEncodingTests.swift
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
import XCTest

class ParameterEncodingTestCase: BaseTestCase {
    let urlRequest = Endpoint().urlRequest
}

// MARK: -

final class URLParameterEncodingTestCase: ParameterEncodingTestCase {
    // MARK: Properties

    let encoding = URLEncoding.default

    // MARK: Tests - Parameter Types

    func testURLParameterEncodeNilParameters() throws {
        // Given, When
        let urlRequest = try encoding.encode(urlRequest, with: nil)

        // Then
        XCTAssertNil(urlRequest.url?.query)
    }

    func testURLParameterEncodeEmptyDictionaryParameter() throws {
        // Given
        let parameters: [String: Any] = [:]

        // When
        let urlRequest = try encoding.encode(urlRequest, with: parameters)

        // Then
        XCTAssertNil(urlRequest.url?.query)
    }

    func testURLParameterEncodeOneStringKeyStringValueParameter() throws {
        // Given
        let parameters = ["foo": "bar"]

        // When
        let urlRequest = try encoding.encode(urlRequest, with: parameters)

        // Then
        XCTAssertEqual(urlRequest.url?.query, "foo=bar")
    }

    func testURLParameterEncodeOneStringKeyStringValueParameterAppendedToQuery() throws {
        // Given
        var mutableURLRequest = urlRequest
        var urlComponents = URLComponents(url: mutableURLRequest.url!, resolvingAgainstBaseURL: false)!
        urlComponents.query = "baz=qux"
        mutableURLRequest.url = urlComponents.url

        let parameters = ["foo": "bar"]

        // When
        let urlRequest = try encoding.encode(mutableURLRequest, with: parameters)

        // Then
        XCTAssertEqual(urlRequest.url?.query, "baz=qux&foo=bar")
    }

    func testURLParameterEncodeTwoStringKeyStringValueParameters() throws {
        // Given
        let parameters = ["foo": "bar", "baz": "qux"]

        // When
        let urlRequest = try encoding.encode(urlRequest, with: parameters)

        // Then
        XCTAssertEqual(urlRequest.url?.query, "baz=qux&foo=bar")
    }

    func testURLParameterEncodeStringKeyNSNumberIntegerValueParameter() throws {
        // Given
        let parameters = ["foo": NSNumber(value: 25)]

        // When
        let urlRequest = try encoding.encode(urlRequest, with: parameters)

        // Then
        XCTAssertEqual(urlRequest.url?.query, "foo=25")
    }

    func testURLParameterEncodeStringKeyNSNumberBoolValueParameter() throws {
        // Given
        let parameters = ["foo": NSNumber(value: false)]

        // When
        let urlRequest = try encoding.encode(urlRequest, with: parameters)

        // Then
        XCTAssertEqual(urlRequest.url?.query, "foo=0")
    }

    func testURLParameterEncodeStringKeyIntegerValueParameter() throws {
        // Given
        let parameters = ["foo": 1]

        // When
        let urlRequest = try encoding.encode(urlRequest, with: parameters)

        // Then
        XCTAssertEqual(urlRequest.url?.query, "foo=1")
    }

    func testURLParameterEncodeStringKeyDoubleValueParameter() throws {
        // Given
        let parameters = ["foo": 1.1]

        // When
        let urlRequest = try encoding.encode(urlRequest, with: parameters)

        // Then
        XCTAssertEqual(urlRequest.url?.query, "foo=1.1")
    }

    func testURLParameterEncodeStringKeyBoolValueParameter() throws {
        // Given
        let parameters = ["foo": true]

        // When
        let urlRequest = try encoding.encode(urlRequest, with: parameters)

        // Then
        XCTAssertEqual(urlRequest.url?.query, "foo=1")
    }

    func testURLParameterEncodeStringKeyArrayValueParameter() throws {
        // Given
        let parameters = ["foo": ["a", 1, true]]

        // When
        let urlRequest = try encoding.encode(urlRequest, with: parameters)

        // Then
        XCTAssertEqual(urlRequest.url?.query, "foo%5B%5D=a&foo%5B%5D=1&foo%5B%5D=1")
    }

    func testURLParameterEncodeArrayNestedDictionaryValueParameterWithIndex() throws {
        // Given
        let encoding = URLEncoding(arrayEncoding: .indexInBrackets)
        let parameters = ["foo": ["a", 1, true, ["bar": 2], ["qux": 3], ["quy": ["quz": 3]]]]

        // When
        let urlRequest = try encoding.encode(urlRequest, with: parameters)

        // Then
        XCTAssertEqual(urlRequest.url?.query, "foo%5B0%5D=a&foo%5B1%5D=1&foo%5B2%5D=1&foo%5B3%5D%5Bbar%5D=2&foo%5B4%5D%5Bqux%5D=3&foo%5B5%5D%5Bquy%5D%5Bquz%5D=3")
    }

    func testURLParameterEncodeStringKeyArrayValueParameterWithoutBrackets() throws {
        // Given
        let encoding = URLEncoding(arrayEncoding: .noBrackets)
        let parameters = ["foo": ["a", 1, true]]

        // When
        let urlRequest = try encoding.encode(urlRequest, with: parameters)

        // Then
        XCTAssertEqual(urlRequest.url?.query, "foo=a&foo=1&foo=1")
    }

    func testURLParameterEncodeStringKeyArrayValueParameterWithCustomClosure() throws {
        // Given
        let encoding = URLEncoding(arrayEncoding: .custom { key, index in
            "\(key).\(index + 1)"
        })
        let parameters = ["foo": ["a", 1, true]]

        // When
        let urlRequest = try encoding.encode(urlRequest, with: parameters)

        // Then
        XCTAssertEqual(urlRequest.url?.query, "foo.1=a&foo.2=1&foo.3=1")
    }

    func testURLParameterEncodeStringKeyDictionaryValueParameter() throws {
        // Given
        let parameters = ["foo": ["bar": 1]]

        // When
        let urlRequest = try encoding.encode(urlRequest, with: parameters)

        // Then
        XCTAssertEqual(urlRequest.url?.query, "foo%5Bbar%5D=1")
    }

    func testURLParameterEncodeStringKeyNestedDictionaryValueParameter() throws {
        // Given
        let parameters = ["foo": ["bar": ["baz": 1]]]

        // When
        let urlRequest = try encoding.encode(urlRequest, with: parameters)

        // Then
        XCTAssertEqual(urlRequest.url?.query, "foo%5Bbar%5D%5Bbaz%5D=1")
    }

    func testURLParameterEncodeStringKeyNestedDictionaryArrayValueParameter() throws {
        // Given
        let parameters = ["foo": ["bar": ["baz": ["a", 1, true]]]]

        // When
        let urlRequest = try encoding.encode(urlRequest, with: parameters)

        // Then
        let expectedQuery = "foo%5Bbar%5D%5Bbaz%5D%5B%5D=a&foo%5Bbar%5D%5Bbaz%5D%5B%5D=1&foo%5Bbar%5D%5Bbaz%5D%5B%5D=1"
        XCTAssertEqual(urlRequest.url?.query, expectedQuery)
    }

    func testURLParameterEncodeStringKeyNestedDictionaryArrayValueParameterWithoutBrackets() throws {
        // Given
        let encoding = URLEncoding(arrayEncoding: .noBrackets)
        let parameters = ["foo": ["bar": ["baz": ["a", 1, true]]]]

        // When
        let urlRequest = try encoding.encode(urlRequest, with: parameters)

        // Then
        let expectedQuery = "foo%5Bbar%5D%5Bbaz%5D=a&foo%5Bbar%5D%5Bbaz%5D=1&foo%5Bbar%5D%5Bbaz%5D=1"
        XCTAssertEqual(urlRequest.url?.query, expectedQuery)
    }

    func testURLParameterLiteralBoolEncodingWorksAndDoesNotAffectNumbers() throws {
        // Given
        let encoding = URLEncoding(boolEncoding: .literal)
        let parameters: [String: Any] = [ // Must still encode to numbers
            "a": 1,
            "b": 0,
            "c": 1.0,
            "d": 0.0,
            "e": NSNumber(value: 1),
            "f": NSNumber(value: 0),
            "g": NSNumber(value: 1.0),
            "h": NSNumber(value: 0.0),

            // Must encode to literals
            "i": true,
            "j": false,
            "k": NSNumber(value: true),
            "l": NSNumber(value: false)
        ]

        // When
        let urlRequest = try encoding.encode(urlRequest, with: parameters)

        // Then
        XCTAssertEqual(urlRequest.url?.query, "a=1&b=0&c=1&d=0&e=1&f=0&g=1&h=0&i=true&j=false&k=true&l=false")
    }

    // MARK: Tests - All Reserved / Unreserved / Illegal Characters According to RFC 3986

    func testThatReservedCharactersArePercentEscapedMinusQuestionMarkAndForwardSlash() throws {
        // Given
        let generalDelimiters = ":#[]@"
        let subDelimiters = "!$&'()*+,;="
        let parameters = ["reserved": "\(generalDelimiters)\(subDelimiters)"]

        // When
        let urlRequest = try encoding.encode(urlRequest, with: parameters)

        // Then
        let expectedQuery = "reserved=%3A%23%5B%5D%40%21%24%26%27%28%29%2A%2B%2C%3B%3D"
        XCTAssertEqual(urlRequest.url?.query, expectedQuery)
    }

    func testThatReservedCharactersQuestionMarkAndForwardSlashAreNotPercentEscaped() throws {
        // Given
        let parameters = ["reserved": "?/"]

        // When
        let urlRequest = try encoding.encode(urlRequest, with: parameters)

        // Then
        XCTAssertEqual(urlRequest.url?.query, "reserved=?/")
    }

    func testThatUnreservedNumericCharactersAreNotPercentEscaped() throws {
        // Given
        let parameters = ["numbers": "0123456789"]

        // When
        let urlRequest = try encoding.encode(urlRequest, with: parameters)

        // Then
        XCTAssertEqual(urlRequest.url?.query, "numbers=0123456789")
    }

    func testThatUnreservedLowercaseCharactersAreNotPercentEscaped() throws {
        // Given
        let parameters = ["lowercase": "abcdefghijklmnopqrstuvwxyz"]

        // When
        let urlRequest = try encoding.encode(urlRequest, with: parameters)

        // Then
        XCTAssertEqual(urlRequest.url?.query, "lowercase=abcdefghijklmnopqrstuvwxyz")
    }

    func testThatUnreservedUppercaseCharactersAreNotPercentEscaped() throws {
        // Given
        let parameters = ["uppercase": "ABCDEFGHIJKLMNOPQRSTUVWXYZ"]

        // When
        let urlRequest = try encoding.encode(urlRequest, with: parameters)

        // Then
        XCTAssertEqual(urlRequest.url?.query, "uppercase=ABCDEFGHIJKLMNOPQRSTUVWXYZ")
    }

    func testThatIllegalASCIICharactersArePercentEscaped() throws {
        // Given
        let parameters = ["illegal": " \"#%<>[]\\^`{}|"]

        // When
        let urlRequest = try encoding.encode(urlRequest, with: parameters)

        // Then
        let expectedQuery = "illegal=%20%22%23%25%3C%3E%5B%5D%5C%5E%60%7B%7D%7C"
        XCTAssertEqual(urlRequest.url?.query, expectedQuery)
    }

    // MARK: Tests - Special Character Queries

    func testURLParameterEncodeStringWithAmpersandKeyStringWithAmpersandValueParameter() throws {
        // Given
        let parameters = ["foo&bar": "baz&qux", "foobar": "bazqux"]

        // When
        let urlRequest = try encoding.encode(urlRequest, with: parameters)

        // Then
        XCTAssertEqual(urlRequest.url?.query, "foo%26bar=baz%26qux&foobar=bazqux")
    }

    func testURLParameterEncodeStringWithQuestionMarkKeyStringWithQuestionMarkValueParameter() throws {
        // Given
        let parameters = ["?foo?": "?bar?"]

        // When
        let urlRequest = try encoding.encode(urlRequest, with: parameters)

        // Then
        XCTAssertEqual(urlRequest.url?.query, "?foo?=?bar?")
    }

    func testURLParameterEncodeStringWithSlashKeyStringWithQuestionMarkValueParameter() throws {
        // Given
        let parameters = ["foo": "/bar/baz/qux"]

        // When
        let urlRequest = try encoding.encode(urlRequest, with: parameters)

        // Then
        XCTAssertEqual(urlRequest.url?.query, "foo=/bar/baz/qux")
    }

    func testURLParameterEncodeStringWithSpaceKeyStringWithSpaceValueParameter() throws {
        // Given
        let parameters = [" foo ": " bar "]

        // When
        let urlRequest = try encoding.encode(urlRequest, with: parameters)

        // Then
        XCTAssertEqual(urlRequest.url?.query, "%20foo%20=%20bar%20")
    }

    func testURLParameterEncodeStringWithPlusKeyStringWithPlusValueParameter() throws {
        // Given
        let parameters = ["+foo+": "+bar+"]

        // When
        let urlRequest = try encoding.encode(urlRequest, with: parameters)

        // Then
        XCTAssertEqual(urlRequest.url?.query, "%2Bfoo%2B=%2Bbar%2B")
    }

    func testURLParameterEncodeStringKeyPercentEncodedStringValueParameter() throws {
        // Given
        let parameters = ["percent": "%25"]

        // When
        let urlRequest = try encoding.encode(urlRequest, with: parameters)

        // Then
        XCTAssertEqual(urlRequest.url?.query, "percent=%2525")
    }

    func testURLParameterEncodeStringKeyNonLatinStringValueParameter() throws {
        // Given
        let parameters = ["french": "français",
                          "japanese": "日本語",
                          "arabic": "العربية",
                          "emoji": "😃"]

        // When
        let urlRequest = try encoding.encode(urlRequest, with: parameters)

        // Then
        let expectedParameterValues = ["arabic=%D8%A7%D9%84%D8%B9%D8%B1%D8%A8%D9%8A%D8%A9",
                                       "emoji=%F0%9F%98%83",
                                       "french=fran%C3%A7ais",
                                       "japanese=%E6%97%A5%E6%9C%AC%E8%AA%9E"]

        let expectedQuery = expectedParameterValues.joined(separator: "&")
        XCTAssertEqual(urlRequest.url?.query, expectedQuery)
    }

    func testURLParameterEncodeStringForRequestWithPrecomposedQuery() throws {
        // Given
        let url = URL(string: "https://example.com/movies?hd=[1]")!
        let parameters = ["page": "0"]

        // When
        let urlRequest = try encoding.encode(URLRequest(url: url), with: parameters)

        // Then
        XCTAssertEqual(urlRequest.url?.query, "hd=%5B1%5D&page=0")
    }

    func testURLParameterEncodeStringWithPlusKeyStringWithPlusValueParameterForRequestWithPrecomposedQuery() throws {
        // Given
        let url = URL(string: "https://example.com/movie?hd=[1]")!
        let parameters = ["+foo+": "+bar+"]

        // When
        let urlRequest = try encoding.encode(URLRequest(url: url), with: parameters)

        // Then
        XCTAssertEqual(urlRequest.url?.query, "hd=%5B1%5D&%2Bfoo%2B=%2Bbar%2B")
    }

    func testURLParameterEncodeStringWithThousandsOfChineseCharacters() throws {
        // Given
        let repeatedCount = 2000
        let url = URL(string: "https://example.com/movies")!
        let parameters = ["chinese": String(repeating: "一二三四五六七八九十", count: repeatedCount)]

        // When
        let urlRequest = try encoding.encode(URLRequest(url: url), with: parameters)

        // Then
        var expected = "chinese="

        for _ in 0..<repeatedCount {
            expected += "%E4%B8%80%E4%BA%8C%E4%B8%89%E5%9B%9B%E4%BA%94%E5%85%AD%E4%B8%83%E5%85%AB%E4%B9%9D%E5%8D%81"
        }

        XCTAssertEqual(urlRequest.url?.query, expected)
    }

    // MARK: Tests - Varying HTTP Methods

    func testThatURLParameterEncodingEncodesGETParametersInURL() throws {
        // Given
        var mutableURLRequest = urlRequest
        mutableURLRequest.httpMethod = HTTPMethod.get.rawValue
        let parameters = ["foo": 1, "bar": 2]

        // When
        let urlRequest = try encoding.encode(mutableURLRequest, with: parameters)

        // Then
        XCTAssertEqual(urlRequest.url?.query, "bar=2&foo=1")
        XCTAssertNil(urlRequest.value(forHTTPHeaderField: "Content-Type"), "Content-Type should be nil")
        XCTAssertNil(urlRequest.httpBody, "HTTPBody should be nil")
    }

    func testThatURLParameterEncodingEncodesPOSTParametersInHTTPBody() throws {
        // Given
        var mutableURLRequest = urlRequest
        mutableURLRequest.httpMethod = HTTPMethod.post.rawValue
        let parameters = ["foo": 1, "bar": 2]

        // When
        let urlRequest = try encoding.encode(mutableURLRequest, with: parameters)

        // Then
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded; charset=utf-8")
        XCTAssertNotNil(urlRequest.httpBody, "HTTPBody should not be nil")

        XCTAssertEqual(urlRequest.httpBody?.asString, "bar=2&foo=1")
    }

    func testThatURLEncodedInURLParameterEncodingEncodesPOSTParametersInURL() throws {
        // Given
        var mutableURLRequest = urlRequest
        mutableURLRequest.httpMethod = HTTPMethod.post.rawValue
        let parameters = ["foo": 1, "bar": 2]

        // When
        let urlRequest = try URLEncoding.queryString.encode(mutableURLRequest, with: parameters)

        // Then
        XCTAssertEqual(urlRequest.url?.query, "bar=2&foo=1")
        XCTAssertNil(urlRequest.value(forHTTPHeaderField: "Content-Type"))
        XCTAssertNil(urlRequest.httpBody, "HTTPBody should be nil")
    }
}

// MARK: -

final class JSONParameterEncodingTestCase: ParameterEncodingTestCase {
    // MARK: Properties

    let encoding = JSONEncoding.default

    // MARK: Tests

    func testJSONParameterEncodeNilParameters() throws {
        // Given, When
        let request = try encoding.encode(urlRequest, with: nil)

        // Then
        XCTAssertNil(request.url?.query, "query should be nil")
        XCTAssertNil(request.value(forHTTPHeaderField: "Content-Type"))
        XCTAssertNil(request.httpBody, "HTTPBody should be nil")
    }

    func testJSONParameterEncodeComplexParameters() throws {
        // Given
        let parameters: [String: Any] = ["foo": "bar",
                                         "baz": ["a", 1, true],
                                         "qux": ["a": 1,
                                                 "b": [2, 2],
                                                 "c": [3, 3, 3]]]

        // When
        let request = try encoding.encode(urlRequest, with: parameters)

        // Then
        XCTAssertNil(request.url?.query)
        XCTAssertNotNil(request.value(forHTTPHeaderField: "Content-Type"))
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertNotNil(request.httpBody)

        XCTAssertEqual(try request.httpBody?.asJSONObject() as? NSObject,
                       parameters as NSObject,
                       "Decoded request body and parameters should be equal.")
    }

    func testJSONParameterEncodeArray() throws {
        // Given
        let array = ["foo", "bar", "baz"]

        // When
        let request = try encoding.encode(urlRequest, withJSONObject: array)

        // Then
        XCTAssertNil(request.url?.query)
        XCTAssertNotNil(request.value(forHTTPHeaderField: "Content-Type"))
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertNotNil(request.httpBody)

        XCTAssertEqual(try request.httpBody?.asJSONObject() as? NSObject,
                       array as NSObject,
                       "Decoded request body and parameters should be equal.")
    }

    func testJSONParameterEncodeParametersRetainsCustomContentType() throws {
        // Given
        let request = Endpoint(headers: [.contentType("application/custom-json-type+json")]).urlRequest

        let parameters = ["foo": "bar"]

        // When
        let urlRequest = try encoding.encode(request, with: parameters)

        // Then
        XCTAssertNil(urlRequest.url?.query)
        XCTAssertEqual(urlRequest.headers["Content-Type"], "application/custom-json-type+json")
    }

    func testJSONParameterEncodeParametersThrowsErrorWithInvalidValue() {
        // Given
        struct Value {}
        let value = Value()

        // When
        let result = Result { try encoding.encode(urlRequest, with: ["key": value]) }

        // Then
        XCTAssertTrue(result.failure?.asAFError?.isJSONEncodingFailed == true)
    }

    func testJSONParameterEncodeObjectThrowsErrorWithInvalidValue() {
        // Given
        struct Value {}
        let value = Value()

        // When
        let result = Result { try encoding.encode(urlRequest, withJSONObject: value) }

        // Then
        XCTAssertTrue(result.failure?.asAFError?.isJSONEncodingFailed == true)
    }
}
