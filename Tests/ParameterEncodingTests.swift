//
//  ParameterEncodingTests.swift
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

class ParameterEncodingTestCase: BaseTestCase {
    let urlRequest = URLRequest(url: URL(string: "https://example.com/")!)
}

// MARK: -

class URLParameterEncodingTestCase: ParameterEncodingTestCase {

    // MARK: Properties

    let encoding = URLEncoding.default

    // MARK: Tests - Parameter Types

    func testURLParameterEncodeNilParameters() {
        do {
            // Given, When
            let urlRequest = try encoding.encode(self.urlRequest, with: nil)

            // Then
            XCTAssertNil(urlRequest.url?.query)
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testURLParameterEncodeEmptyDictionaryParameter() {
        do {
            // Given
            let parameters: [String: Any] = [:]

            // When
            let urlRequest = try encoding.encode(self.urlRequest, with: parameters)

            // Then
            XCTAssertNil(urlRequest.url?.query)
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testURLParameterEncodeOneStringKeyStringValueParameter() {
        do {
            // Given
            let parameters = ["foo": "bar"]

            // When
            let urlRequest = try encoding.encode(self.urlRequest, with: parameters)

            // Then
            XCTAssertEqual(urlRequest.url?.query, "foo=bar")
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testURLParameterEncodeOneStringKeyStringValueParameterAppendedToQuery() {
        do {
            // Given
            var mutableURLRequest = self.urlRequest
            var urlComponents = URLComponents(url: mutableURLRequest.url!, resolvingAgainstBaseURL: false)!
            urlComponents.query = "baz=qux"
            mutableURLRequest.url = urlComponents.url

            let parameters = ["foo": "bar"]

            // When
            let urlRequest = try encoding.encode(mutableURLRequest, with: parameters)

            // Then
            XCTAssertEqual(urlRequest.url?.query, "baz=qux&foo=bar")
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testURLParameterEncodeTwoStringKeyStringValueParameters() {
        do {
            // Given
            let parameters = ["foo": "bar", "baz": "qux"]

            // When
            let urlRequest = try encoding.encode(self.urlRequest, with: parameters)

            // Then
            XCTAssertEqual(urlRequest.url?.query, "baz=qux&foo=bar")
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testURLParameterEncodeStringKeyNSNumberIntegerValueParameter() {
        do {
            // Given
            let parameters = ["foo": NSNumber(value: 25)]

            // When
            let urlRequest = try encoding.encode(self.urlRequest, with: parameters)

            // Then
            XCTAssertEqual(urlRequest.url?.query, "foo=25")
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testURLParameterEncodeStringKeyNSNumberBoolValueParameter() {
        do {
            // Given
            let parameters = ["foo": NSNumber(value: false)]

            // When
            let urlRequest = try encoding.encode(self.urlRequest, with: parameters)

            // Then
            XCTAssertEqual(urlRequest.url?.query, "foo=0")
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testURLParameterEncodeStringKeyIntegerValueParameter() {
        do {
            // Given
            let parameters = ["foo": 1]

            // When
            let urlRequest = try encoding.encode(self.urlRequest, with: parameters)

            // Then
            XCTAssertEqual(urlRequest.url?.query, "foo=1")
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testURLParameterEncodeStringKeyDoubleValueParameter() {
        do {
            // Given
            let parameters = ["foo": 1.1]

            // When
            let urlRequest = try encoding.encode(self.urlRequest, with: parameters)

            // Then
            XCTAssertEqual(urlRequest.url?.query, "foo=1.1")
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testURLParameterEncodeStringKeyBoolValueParameter() {
        do {
            // Given
            let parameters = ["foo": true]

            // When
            let urlRequest = try encoding.encode(self.urlRequest, with: parameters)

            // Then
            XCTAssertEqual(urlRequest.url?.query, "foo=1")
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testURLParameterEncodeStringKeyArrayValueParameter() {
        do {
            // Given
            let parameters = ["foo": ["a", 1, true]]

            // When
            let urlRequest = try encoding.encode(self.urlRequest, with: parameters)

            // Then
            XCTAssertEqual(urlRequest.url?.query, "foo%5B%5D=a&foo%5B%5D=1&foo%5B%5D=1")
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testURLParameterEncodeStringKeyDictionaryValueParameter() {
        do {
            // Given
            let parameters = ["foo": ["bar": 1]]

            // When
            let urlRequest = try encoding.encode(self.urlRequest, with: parameters)

            // Then
            XCTAssertEqual(urlRequest.url?.query, "foo%5Bbar%5D=1")
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testURLParameterEncodeStringKeyNestedDictionaryValueParameter() {
        do {
            // Given
            let parameters = ["foo": ["bar": ["baz": 1]]]

            // When
            let urlRequest = try encoding.encode(self.urlRequest, with: parameters)

            // Then
            XCTAssertEqual(urlRequest.url?.query, "foo%5Bbar%5D%5Bbaz%5D=1")
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testURLParameterEncodeStringKeyNestedDictionaryArrayValueParameter() {
        do {
            // Given
            let parameters = ["foo": ["bar": ["baz": ["a", 1, true]]]]

            // When
            let urlRequest = try encoding.encode(self.urlRequest, with: parameters)

            // Then
            let expectedQuery = "foo%5Bbar%5D%5Bbaz%5D%5B%5D=a&foo%5Bbar%5D%5Bbaz%5D%5B%5D=1&foo%5Bbar%5D%5Bbaz%5D%5B%5D=1"
            XCTAssertEqual(urlRequest.url?.query, expectedQuery)
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    // MARK: Tests - All Reserved / Unreserved / Illegal Characters According to RFC 3986

    func testThatReservedCharactersArePercentEscapedMinusQuestionMarkAndForwardSlash() {
        do {
            // Given
            let generalDelimiters = ":#[]@"
            let subDelimiters = "!$&'()*+,;="
            let parameters = ["reserved": "\(generalDelimiters)\(subDelimiters)"]

            // When
            let urlRequest = try encoding.encode(self.urlRequest, with: parameters)

            // Then
            let expectedQuery = "reserved=%3A%23%5B%5D%40%21%24%26%27%28%29%2A%2B%2C%3B%3D"
            XCTAssertEqual(urlRequest.url?.query, expectedQuery)
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testThatReservedCharactersQuestionMarkAndForwardSlashAreNotPercentEscaped() {
        do {
            // Given
            let parameters = ["reserved": "?/"]

            // When
            let urlRequest = try encoding.encode(self.urlRequest, with: parameters)

            // Then
            XCTAssertEqual(urlRequest.url?.query, "reserved=?/")
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testThatUnreservedNumericCharactersAreNotPercentEscaped() {
        do {
            // Given
            let parameters = ["numbers": "0123456789"]

            // When
            let urlRequest = try encoding.encode(self.urlRequest, with: parameters)

            // Then
            XCTAssertEqual(urlRequest.url?.query, "numbers=0123456789")
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testThatUnreservedLowercaseCharactersAreNotPercentEscaped() {
        do {
            // Given
            let parameters = ["lowercase": "abcdefghijklmnopqrstuvwxyz"]

            // When
            let urlRequest = try encoding.encode(self.urlRequest, with: parameters)

            // Then
            XCTAssertEqual(urlRequest.url?.query, "lowercase=abcdefghijklmnopqrstuvwxyz")
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testThatUnreservedUppercaseCharactersAreNotPercentEscaped() {
        do {
            // Given
            let parameters = ["uppercase": "ABCDEFGHIJKLMNOPQRSTUVWXYZ"]

            // When
            let urlRequest = try encoding.encode(self.urlRequest, with: parameters)

            // Then
            XCTAssertEqual(urlRequest.url?.query, "uppercase=ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testThatIllegalASCIICharactersArePercentEscaped() {
        do {
            // Given
            let parameters = ["illegal": " \"#%<>[]\\^`{}|"]

            // When
            let urlRequest = try encoding.encode(self.urlRequest, with: parameters)

            // Then
            let expectedQuery = "illegal=%20%22%23%25%3C%3E%5B%5D%5C%5E%60%7B%7D%7C"
            XCTAssertEqual(urlRequest.url?.query, expectedQuery)
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    // MARK: Tests - Special Character Queries

    func testURLParameterEncodeStringWithAmpersandKeyStringWithAmpersandValueParameter() {
        do {
            // Given
            let parameters = ["foo&bar": "baz&qux", "foobar": "bazqux"]

            // When
            let urlRequest = try encoding.encode(self.urlRequest, with: parameters)

            // Then
            XCTAssertEqual(urlRequest.url?.query, "foo%26bar=baz%26qux&foobar=bazqux")
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testURLParameterEncodeStringWithQuestionMarkKeyStringWithQuestionMarkValueParameter() {
        do {
            // Given
            let parameters = ["?foo?": "?bar?"]

            // When
            let urlRequest = try encoding.encode(self.urlRequest, with: parameters)

            // Then
            XCTAssertEqual(urlRequest.url?.query, "?foo?=?bar?")
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testURLParameterEncodeStringWithSlashKeyStringWithQuestionMarkValueParameter() {
        do {
            // Given
            let parameters = ["foo": "/bar/baz/qux"]

            // When
            let urlRequest = try encoding.encode(self.urlRequest, with: parameters)

            // Then
            XCTAssertEqual(urlRequest.url?.query, "foo=/bar/baz/qux")
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testURLParameterEncodeStringWithSpaceKeyStringWithSpaceValueParameter() {
        do {
            // Given
            let parameters = [" foo ": " bar "]

            // When
            let urlRequest = try encoding.encode(self.urlRequest, with: parameters)

            // Then
            XCTAssertEqual(urlRequest.url?.query, "%20foo%20=%20bar%20")
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testURLParameterEncodeStringWithPlusKeyStringWithPlusValueParameter() {
        do {
            // Given
            let parameters = ["+foo+": "+bar+"]

            // When
            let urlRequest = try encoding.encode(self.urlRequest, with: parameters)

            // Then
            XCTAssertEqual(urlRequest.url?.query, "%2Bfoo%2B=%2Bbar%2B")
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testURLParameterEncodeStringKeyPercentEncodedStringValueParameter() {
        do {
            // Given
            let parameters = ["percent": "%25"]

            // When
            let urlRequest = try encoding.encode(self.urlRequest, with: parameters)

            // Then
            XCTAssertEqual(urlRequest.url?.query, "percent=%2525")
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testURLParameterEncodeStringKeyNonLatinStringValueParameter() {
        do {
            // Given
            let parameters = [
                "french": "français",
                "japanese": "日本語",
                "arabic": "العربية",
                "emoji": "😃"
            ]

            // When
            let urlRequest = try encoding.encode(self.urlRequest, with: parameters)

            // Then
            let expectedParameterValues = [
                "arabic=%D8%A7%D9%84%D8%B9%D8%B1%D8%A8%D9%8A%D8%A9",
                "emoji=%F0%9F%98%83",
                "french=fran%C3%A7ais",
                "japanese=%E6%97%A5%E6%9C%AC%E8%AA%9E"
            ]

            let expectedQuery = expectedParameterValues.joined(separator: "&")
            XCTAssertEqual(urlRequest.url?.query, expectedQuery)
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testURLParameterEncodeStringForRequestWithPrecomposedQuery() {
        do {
            // Given
            let url = URL(string: "https://example.com/movies?hd=[1]")!
            let parameters = ["page": "0"]

            // When
            let urlRequest = try encoding.encode(URLRequest(url: url), with: parameters)

            // Then
            XCTAssertEqual(urlRequest.url?.query, "hd=%5B1%5D&page=0")
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testURLParameterEncodeStringWithPlusKeyStringWithPlusValueParameterForRequestWithPrecomposedQuery() {
        do {
            // Given
            let url = URL(string: "https://example.com/movie?hd=[1]")!
            let parameters = ["+foo+": "+bar+"]

            // When
            let urlRequest = try encoding.encode(URLRequest(url: url), with: parameters)

            // Then
            XCTAssertEqual(urlRequest.url?.query, "hd=%5B1%5D&%2Bfoo%2B=%2Bbar%2B")
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testURLParameterEncodeStringWithThousandsOfChineseCharacters() {
        do {
            // Given
            let repeatedCount = 2_000
            let url = URL(string: "https://example.com/movies")!
            let parameters = ["chinese": String(count: repeatedCount, repeatedString: "一二三四五六七八九十")]

            // When
            let urlRequest = try encoding.encode(URLRequest(url: url), with: parameters)

            // Then
            var expected = "chinese="

            for _ in 0..<repeatedCount {
                expected += "%E4%B8%80%E4%BA%8C%E4%B8%89%E5%9B%9B%E4%BA%94%E5%85%AD%E4%B8%83%E5%85%AB%E4%B9%9D%E5%8D%81"
            }

            XCTAssertEqual(urlRequest.url?.query, expected)
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    // MARK: Tests - Varying HTTP Methods

    func testThatURLParameterEncodingEncodesGETParametersInURL() {
        do {
            // Given
            var mutableURLRequest = self.urlRequest
            mutableURLRequest.httpMethod = HTTPMethod.get.rawValue
            let parameters = ["foo": 1, "bar": 2]

            // When
            let urlRequest = try encoding.encode(mutableURLRequest, with: parameters)

            // Then
            XCTAssertEqual(urlRequest.url?.query, "bar=2&foo=1")
            XCTAssertNil(urlRequest.value(forHTTPHeaderField: "Content-Type"), "Content-Type should be nil")
            XCTAssertNil(urlRequest.httpBody, "HTTPBody should be nil")
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testThatURLParameterEncodingEncodesPOSTParametersInHTTPBody() {
        do {
            // Given
            var mutableURLRequest = self.urlRequest
            mutableURLRequest.httpMethod = HTTPMethod.post.rawValue
            let parameters = ["foo": 1, "bar": 2]

            // When
            let urlRequest = try encoding.encode(mutableURLRequest, with: parameters)

            // Then
            XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded; charset=utf-8")
            XCTAssertNotNil(urlRequest.httpBody, "HTTPBody should not be nil")

            if let httpBody = urlRequest.httpBody, let decodedHTTPBody = String(data: httpBody, encoding: .utf8) {
                XCTAssertEqual(decodedHTTPBody, "bar=2&foo=1")
            } else {
                XCTFail("decoded http body should not be nil")
            }
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testThatURLEncodedInURLParameterEncodingEncodesPOSTParametersInURL() {
        do {
            // Given
            var mutableURLRequest = self.urlRequest
            mutableURLRequest.httpMethod = HTTPMethod.post.rawValue
            let parameters = ["foo": 1, "bar": 2]

            // When
            let urlRequest = try URLEncoding.queryString.encode(mutableURLRequest, with: parameters)

            // Then
            XCTAssertEqual(urlRequest.url?.query, "bar=2&foo=1")
            XCTAssertNil(urlRequest.value(forHTTPHeaderField: "Content-Type"))
            XCTAssertNil(urlRequest.httpBody, "HTTPBody should be nil")
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }
}

// MARK: -

class JSONParameterEncodingTestCase: ParameterEncodingTestCase {
    // MARK: Properties

    let encoding = JSONEncoding.default

    // MARK: Tests

    func testJSONParameterEncodeNilParameters() {
        do {
            // Given, When
            let URLRequest = try encoding.encode(self.urlRequest, with: nil)

            // Then
            XCTAssertNil(URLRequest.url?.query, "query should be nil")
            XCTAssertNil(URLRequest.value(forHTTPHeaderField: "Content-Type"))
            XCTAssertNil(URLRequest.httpBody, "HTTPBody should be nil")
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testJSONParameterEncodeComplexParameters() {
        do {
            // Given
            let parameters: [String: Any] = [
                "foo": "bar",
                "baz": ["a", 1, true],
                "qux": [
                    "a": 1,
                    "b": [2, 2],
                    "c": [3, 3, 3]
                ]
            ]

            // When
            let URLRequest = try encoding.encode(self.urlRequest, with: parameters)

            // Then
            XCTAssertNil(URLRequest.url?.query)
            XCTAssertNotNil(URLRequest.value(forHTTPHeaderField: "Content-Type"))
            XCTAssertEqual(URLRequest.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertNotNil(URLRequest.httpBody)

            if let httpBody = URLRequest.httpBody {
                do {
                    let json = try JSONSerialization.jsonObject(with: httpBody, options: .allowFragments)

                    if let json = json as? NSObject {
                        XCTAssertEqual(json, parameters as NSObject)
                    } else {
                        XCTFail("json should be an NSObject")
                    }
                } catch {
                    XCTFail("json should not be nil")
                }
            }
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testJSONParameterEncodeArray() {
        do {
            // Given
            let array: [String] = ["foo", "bar", "baz"]

            // When
            let URLRequest = try encoding.encode(self.urlRequest, withJSONObject: array)

            // Then
            XCTAssertNil(URLRequest.url?.query)
            XCTAssertNotNil(URLRequest.value(forHTTPHeaderField: "Content-Type"))
            XCTAssertEqual(URLRequest.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertNotNil(URLRequest.httpBody)

            if let httpBody = URLRequest.httpBody {
                do {
                    let json = try JSONSerialization.jsonObject(with: httpBody, options: .allowFragments)

                    if let json = json as? NSObject {
                        XCTAssertEqual(json, array as NSObject)
                    } else {
                        XCTFail("json should be an NSObject")
                    }
                } catch {
                    XCTFail("json should not be nil")
                }
            }
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testJSONParameterEncodeParametersRetainsCustomContentType() {
        do {
            // Given
            var mutableURLRequest = URLRequest(url: URL(string: "https://example.com/")!)
            mutableURLRequest.setValue("application/custom-json-type+json", forHTTPHeaderField: "Content-Type")

            let parameters = ["foo": "bar"]

            // When
            let urlRequest = try encoding.encode(mutableURLRequest, with: parameters)

            // Then
            XCTAssertNil(urlRequest.url?.query)
            XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Content-Type"), "application/custom-json-type+json")
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }
}

// MARK: -

class PropertyListParameterEncodingTestCase: ParameterEncodingTestCase {

    // MARK: Properties

    let encoding = PropertyListEncoding.default

    // MARK: Tests

    func testPropertyListParameterEncodeNilParameters() {
        do {
            // Given, When
            let urlRequest = try encoding.encode(self.urlRequest, with: nil)

            // Then
            XCTAssertNil(urlRequest.url?.query)
            XCTAssertNil(urlRequest.value(forHTTPHeaderField: "Content-Type"))
            XCTAssertNil(urlRequest.httpBody)
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testPropertyListParameterEncodeComplexParameters() {
        do {
            // Given
            let parameters: [String: Any] = [
                "foo": "bar",
                "baz": ["a", 1, true],
                "qux": [
                    "a": 1,
                    "b": [2, 2],
                    "c": [3, 3, 3]
                ]
            ]

            // When
            let urlRequest = try encoding.encode(self.urlRequest, with: parameters)

            // Then
            XCTAssertNil(urlRequest.url?.query)
            XCTAssertNotNil(urlRequest.value(forHTTPHeaderField: "Content-Type"))
            XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Content-Type"), "application/x-plist")
            XCTAssertNotNil(urlRequest.httpBody)

            if let httpBody = urlRequest.httpBody {
                do {
                    let plist = try PropertyListSerialization.propertyList(from: httpBody, options: [], format: nil)

                    if let plist = plist as? NSObject {
                        XCTAssertEqual(plist, parameters as NSObject)
                    } else {
                        XCTFail("plist should be an NSObject")
                    }
                } catch {
                    XCTFail("plist should not be nil")
                }
            }
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testPropertyListParameterEncodeDateAndDataParameters() {
        do {
            // Given
            let date: Date = Date()
            let data: Data = "data".data(using: .utf8, allowLossyConversion: false)!

            let parameters: [String: Any] = [
                "date": date,
                "data": data
            ]

            // When
            let urlRequest = try encoding.encode(self.urlRequest, with: parameters)

            // Then
            XCTAssertNil(urlRequest.url?.query)
            XCTAssertNotNil(urlRequest.value(forHTTPHeaderField: "Content-Type"))
            XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Content-Type"), "application/x-plist")
            XCTAssertNotNil(urlRequest.httpBody)

            if let httpBody = urlRequest.httpBody {
                do {
                    let plist = try PropertyListSerialization.propertyList(from: httpBody, options: [], format: nil) as AnyObject

                    XCTAssertTrue(plist.value(forKey: "date") is Date)
                    XCTAssertTrue(plist.value(forKey: "data") is Data)
                } catch {
                    XCTFail("plist should not be nil")
                }
            } else {
                XCTFail("HTTPBody should not be nil")
            }
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testPropertyListParameterEncodeParametersRetainsCustomContentType() {
        do {
            // Given
            var mutableURLRequest = URLRequest(url: URL(string: "https://example.com/")!)
            mutableURLRequest.setValue("application/custom-plist-type+plist", forHTTPHeaderField: "Content-Type")

            let parameters = ["foo": "bar"]

            // When
            let urlRequest = try encoding.encode(mutableURLRequest, with: parameters)

            // Then
            XCTAssertNil(urlRequest.url?.query)
            XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Content-Type"), "application/custom-plist-type+plist")
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }
}
