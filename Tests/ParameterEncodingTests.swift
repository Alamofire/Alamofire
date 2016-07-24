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
    let urlRequest = Foundation.URLRequest(url: URL(string: "https://example.com/")!)
}

// MARK: -

class URLParameterEncodingTestCase: ParameterEncodingTestCase {
    let encoding: ParameterEncoding = .url

    // MARK: Tests - Parameter Types

    func testURLParameterEncodeNilParameters() {
        // Given
        // When
        let (URLRequest, _) = encoding.encode(self.urlRequest, parameters: nil)

        // Then
        XCTAssertNil(URLRequest.url?.query, "query should be nil")
    }

    func testURLParameterEncodeEmptyDictionaryParameter() {
        // Given
        let parameters: [String: AnyObject] = [:]

        // When
        let (URLRequest, _) = encoding.encode(self.urlRequest, parameters: parameters)

        // Then
        XCTAssertNil(URLRequest.url?.query, "query should be nil")
    }

    func testURLParameterEncodeOneStringKeyStringValueParameter() {
        // Given
        let parameters = ["foo": "bar"]

        // When
        let (URLRequest, _) = encoding.encode(self.urlRequest, parameters: parameters)

        // Then
        XCTAssertEqual(URLRequest.url?.query ?? "", "foo=bar", "query is incorrect")
    }

    func testURLParameterEncodeOneStringKeyStringValueParameterAppendedToQuery() {
        // Given
        var mutableURLRequest = self.urlRequest.urlRequest
        var urlComponents = Foundation.URLComponents(url: mutableURLRequest.url!, resolvingAgainstBaseURL: false)!
        urlComponents.query = "baz=qux"
        mutableURLRequest.url = urlComponents.url

        let parameters = ["foo": "bar"]

        // When
        let (URLRequest, _) = encoding.encode(mutableURLRequest, parameters: parameters)

        // Then
        XCTAssertEqual(URLRequest.url?.query ?? "", "baz=qux&foo=bar", "query is incorrect")
    }

    func testURLParameterEncodeTwoStringKeyStringValueParameters() {
        // Given
        let parameters = ["foo": "bar", "baz": "qux"]

        // When
        let (URLRequest, _) = encoding.encode(self.urlRequest, parameters: parameters)

        // Then
        XCTAssertEqual(URLRequest.url?.query ?? "", "baz=qux&foo=bar", "query is incorrect")
    }

    func testURLParameterEncodeStringKeyIntegerValueParameter() {
        // Given
        let parameters = ["foo": 1]

        // When
        let (URLRequest, _) = encoding.encode(self.urlRequest, parameters: parameters)

        // Then
        XCTAssertEqual(URLRequest.url?.query ?? "", "foo=1", "query is incorrect")
    }

    func testURLParameterEncodeStringKeyDoubleValueParameter() {
        // Given
        let parameters = ["foo": 1.1]

        // When
        let (URLRequest, _) = encoding.encode(self.urlRequest, parameters: parameters)

        // Then
        XCTAssertEqual(URLRequest.url?.query ?? "", "foo=1.1", "query is incorrect")
    }

    func testURLParameterEncodeStringKeyBoolValueParameter() {
        // Given
        let parameters = ["foo": true]

        // When
        let (URLRequest, _) = encoding.encode(self.urlRequest, parameters: parameters)

        // Then
        XCTAssertEqual(URLRequest.url?.query ?? "", "foo=1", "query is incorrect")
    }

    func testURLParameterEncodeStringKeyArrayValueParameter() {
        // Given
        let parameters = ["foo": ["a", 1, true]]

        // When
        let (URLRequest, _) = encoding.encode(self.urlRequest, parameters: parameters)

        // Then
        XCTAssertEqual(URLRequest.url?.query ?? "", "foo%5B%5D=a&foo%5B%5D=1&foo%5B%5D=1", "query is incorrect")
    }

    func testURLParameterEncodeStringKeyDictionaryValueParameter() {
        // Given
        let parameters = ["foo": ["bar": 1]]

        // When
        let (URLRequest, _) = encoding.encode(self.urlRequest, parameters: parameters)

        // Then
        XCTAssertEqual(URLRequest.url?.query ?? "", "foo%5Bbar%5D=1", "query is incorrect")
    }

    func testURLParameterEncodeStringKeyNestedDictionaryValueParameter() {
        // Given
        let parameters = ["foo": ["bar": ["baz": 1]]]

        // When
        let (URLRequest, _) = encoding.encode(self.urlRequest, parameters: parameters)

        // Then
        XCTAssertEqual(URLRequest.url?.query ?? "", "foo%5Bbar%5D%5Bbaz%5D=1", "query is incorrect")
    }

    func testURLParameterEncodeStringKeyNestedDictionaryArrayValueParameter() {
        // Given
        let parameters = ["foo": ["bar": ["baz": ["a", 1, true]]]]

        // When
        let (URLRequest, _) = encoding.encode(self.urlRequest, parameters: parameters)

        // Then
        let expectedQuery = "foo%5Bbar%5D%5Bbaz%5D%5B%5D=a&foo%5Bbar%5D%5Bbaz%5D%5B%5D=1&foo%5Bbar%5D%5Bbaz%5D%5B%5D=1"
        XCTAssertEqual(URLRequest.url?.query ?? "", expectedQuery, "query is incorrect")
    }

    // MARK: Tests - All Reserved / Unreserved / Illegal Characters According to RFC 3986

    func testThatReservedCharactersArePercentEscapedMinusQuestionMarkAndForwardSlash() {
        // Given
        let generalDelimiters = ":#[]@"
        let subDelimiters = "!$&'()*+,;="
        let parameters = ["reserved": "\(generalDelimiters)\(subDelimiters)"]

        // When
        let (URLRequest, _) = encoding.encode(self.urlRequest, parameters: parameters)

        // Then
        let expectedQuery = "reserved=%3A%23%5B%5D%40%21%24%26%27%28%29%2A%2B%2C%3B%3D"
        XCTAssertEqual(URLRequest.url?.query ?? "", expectedQuery, "query is incorrect")
    }

    func testThatReservedCharactersQuestionMarkAndForwardSlashAreNotPercentEscaped() {
        // Given
        let parameters = ["reserved": "?/"]

        // When
        let (URLRequest, _) = encoding.encode(self.urlRequest, parameters: parameters)

        // Then
        XCTAssertEqual(URLRequest.url?.query ?? "", "reserved=?/", "query is incorrect")
    }

    func testThatUnreservedNumericCharactersAreNotPercentEscaped() {
        // Given
        let parameters = ["numbers": "0123456789"]

        // When
        let (URLRequest, _) = encoding.encode(self.urlRequest, parameters: parameters)

        // Then
        XCTAssertEqual(URLRequest.url?.query ?? "", "numbers=0123456789", "query is incorrect")
    }

    func testThatUnreservedLowercaseCharactersAreNotPercentEscaped() {
        // Given
        let parameters = ["lowercase": "abcdefghijklmnopqrstuvwxyz"]

        // When
        let (URLRequest, _) = encoding.encode(self.urlRequest, parameters: parameters)

        // Then
        XCTAssertEqual(URLRequest.url?.query ?? "", "lowercase=abcdefghijklmnopqrstuvwxyz", "query is incorrect")
    }

    func testThatUnreservedUppercaseCharactersAreNotPercentEscaped() {
        // Given
        let parameters = ["uppercase": "ABCDEFGHIJKLMNOPQRSTUVWXYZ"]

        // When
        let (URLRequest, _) = encoding.encode(self.urlRequest, parameters: parameters)

        // Then
        XCTAssertEqual(URLRequest.url?.query ?? "", "uppercase=ABCDEFGHIJKLMNOPQRSTUVWXYZ", "query is incorrect")
    }

    func testThatIllegalASCIICharactersArePercentEscaped() {
        // Given
        let parameters = ["illegal": " \"#%<>[]\\^`{}|"]

        // When
        let (URLRequest, _) = encoding.encode(self.urlRequest, parameters: parameters)

        // Then
        let expectedQuery = "illegal=%20%22%23%25%3C%3E%5B%5D%5C%5E%60%7B%7D%7C"
        XCTAssertEqual(URLRequest.url?.query ?? "", expectedQuery, "query is incorrect")
    }

    // MARK: Tests - Special Character Queries

    func testURLParameterEncodeStringWithAmpersandKeyStringWithAmpersandValueParameter() {
        // Given
        let parameters = ["foo&bar": "baz&qux", "foobar": "bazqux"]

        // When
        let (URLRequest, _) = encoding.encode(self.urlRequest, parameters: parameters)

        // Then
        XCTAssertEqual(URLRequest.url?.query ?? "", "foo%26bar=baz%26qux&foobar=bazqux", "query is incorrect")
    }

    func testURLParameterEncodeStringWithQuestionMarkKeyStringWithQuestionMarkValueParameter() {
        // Given
        let parameters = ["?foo?": "?bar?"]

        // When
        let (URLRequest, _) = encoding.encode(self.urlRequest, parameters: parameters)

        // Then
        XCTAssertEqual(URLRequest.url?.query ?? "", "?foo?=?bar?", "query is incorrect")
    }

    func testURLParameterEncodeStringWithSlashKeyStringWithQuestionMarkValueParameter() {
        // Given
        let parameters = ["foo": "/bar/baz/qux"]

        // When
        let (URLRequest, _) = encoding.encode(self.urlRequest, parameters: parameters)

        // Then
        XCTAssertEqual(URLRequest.url?.query ?? "", "foo=/bar/baz/qux", "query is incorrect")
    }

    func testURLParameterEncodeStringWithSpaceKeyStringWithSpaceValueParameter() {
        // Given
        let parameters = [" foo ": " bar "]

        // When
        let (URLRequest, _) = encoding.encode(self.urlRequest, parameters: parameters)

        // Then
        XCTAssertEqual(URLRequest.url?.query ?? "", "%20foo%20=%20bar%20", "query is incorrect")
    }

    func testURLParameterEncodeStringWithPlusKeyStringWithPlusValueParameter() {
        // Given
        let parameters = ["+foo+": "+bar+"]

        // When
        let (URLRequest, _) = encoding.encode(self.urlRequest, parameters: parameters)

        // Then
        XCTAssertEqual(URLRequest.url?.query ?? "", "%2Bfoo%2B=%2Bbar%2B", "query is incorrect")
    }

    func testURLParameterEncodeStringKeyPercentEncodedStringValueParameter() {
        // Given
        let parameters = ["percent": "%25"]

        // When
        let (URLRequest, _) = encoding.encode(self.urlRequest, parameters: parameters)

        // Then
        XCTAssertEqual(URLRequest.url?.query ?? "", "percent=%2525", "query is incorrect")
    }

    func testURLParameterEncodeStringKeyNonLatinStringValueParameter() {
        // Given
        let parameters = [
            "french": "français",
            "japanese": "日本語",
            "arabic": "العربية",
            "emoji": "😃"
        ]

        // When
        let (URLRequest, _) = encoding.encode(self.urlRequest, parameters: parameters)

        // Then
        let expectedParameterValues = [
            "arabic=%D8%A7%D9%84%D8%B9%D8%B1%D8%A8%D9%8A%D8%A9",
            "emoji=%F0%9F%98%83",
            "french=fran%C3%A7ais",
            "japanese=%E6%97%A5%E6%9C%AC%E8%AA%9E"
        ]

        let expectedQuery = expectedParameterValues.joined(separator: "&")
        XCTAssertEqual(URLRequest.url?.query ?? "", expectedQuery, "query is incorrect")
    }

    func testURLParameterEncodeStringForRequestWithPrecomposedQuery() {
        // Given
        let URL = Foundation.URL(string: "https://example.com/movies?hd=[1]")!
        let parameters = ["page": "0"]

        // When
        let (URLRequest, _) = encoding.encode(Foundation.URLRequest(url: URL), parameters: parameters)

        // Then
        XCTAssertEqual(URLRequest.url?.query ?? "", "hd=%5B1%5D&page=0", "query is incorrect")
    }

    func testURLParameterEncodeStringWithPlusKeyStringWithPlusValueParameterForRequestWithPrecomposedQuery() {
        // Given
        let URL = Foundation.URL(string: "https://example.com/movie?hd=[1]")!
        let parameters = ["+foo+": "+bar+"]

        // When
        let (URLRequest, _) = encoding.encode(Foundation.URLRequest(url: URL), parameters: parameters)

        // Then
        XCTAssertEqual(URLRequest.url?.query ?? "", "hd=%5B1%5D&%2Bfoo%2B=%2Bbar%2B", "query is incorrect")
    }

    func testURLParameterEncodeStringWithThousandsOfChineseCharacters() {
        // Given
        let repeatedCount = 2_000
        let URL = Foundation.URL(string: "https://example.com/movies")!
        let parameters = ["chinese": String(count: repeatedCount, repeatedString: "一二三四五六七八九十")]

        // When
        let (URLRequest, _) = encoding.encode(Foundation.URLRequest(url: URL), parameters: parameters)

        // Then
        var expected = "chinese="
        for _ in 0..<repeatedCount {
            expected += "%E4%B8%80%E4%BA%8C%E4%B8%89%E5%9B%9B%E4%BA%94%E5%85%AD%E4%B8%83%E5%85%AB%E4%B9%9D%E5%8D%81"
        }
        XCTAssertEqual(URLRequest.url?.query ?? "", expected, "query is incorrect")
    }

    // MARK: Tests - Varying HTTP Methods

    func testThatURLParameterEncodingEncodesGETParametersInURL() {
        // Given
        var mutableURLRequest = self.urlRequest.urlRequest
        mutableURLRequest.httpMethod = Method.GET.rawValue
        let parameters = ["foo": 1, "bar": 2]

        // When
        let (urlRequest, _) = encoding.encode(mutableURLRequest, parameters: parameters)

        // Then
        XCTAssertEqual(urlRequest.url?.query ?? "", "bar=2&foo=1", "query is incorrect")
        XCTAssertNil(urlRequest.value(forHTTPHeaderField: "Content-Type"), "Content-Type should be nil")
        XCTAssertNil(urlRequest.httpBody, "HTTPBody should be nil")
    }

    func testThatURLParameterEncodingEncodesPOSTParametersInHTTPBody() {
        // Given
        var mutableURLRequest = self.urlRequest.urlRequest
        mutableURLRequest.httpMethod = Method.POST.rawValue
        let parameters = ["foo": 1, "bar": 2]

        // When
        let (URLRequest, _) = encoding.encode(mutableURLRequest, parameters: parameters)

        // Then
        XCTAssertEqual(
            URLRequest.value(forHTTPHeaderField: "Content-Type") ?? "",
            "application/x-www-form-urlencoded; charset=utf-8",
            "Content-Type should be application/x-www-form-urlencoded"
        )
        XCTAssertNotNil(URLRequest.httpBody, "HTTPBody should not be nil")

        if let httpBody = URLRequest.httpBody,
           let decodedHTTPBody = String(data: httpBody, encoding: String.Encoding.utf8)
        {
            XCTAssertEqual(decodedHTTPBody, "bar=2&foo=1", "HTTPBody is incorrect")
        } else {
            XCTFail("decoded http body should not be nil")
        }
    }

    func testThatURLEncodedInURLParameterEncodingEncodesPOSTParametersInURL() {
        // Given
        var mutableURLRequest = self.urlRequest.urlRequest
        mutableURLRequest.httpMethod = Method.POST.rawValue
        let parameters = ["foo": 1, "bar": 2]

        // When
        let (URLRequest, _) = ParameterEncoding.urlEncodedInURL.encode(mutableURLRequest, parameters: parameters)

        // Then
        XCTAssertEqual(URLRequest.url?.query ?? "", "bar=2&foo=1", "query is incorrect")
        XCTAssertNil(URLRequest.value(forHTTPHeaderField: "Content-Type"), "Content-Type should be nil")
        XCTAssertNil(URLRequest.httpBody, "HTTPBody should be nil")
    }
}

// MARK: -

class JSONParameterEncodingTestCase: ParameterEncodingTestCase {
    // MARK: Properties

    let encoding: ParameterEncoding = .json

    // MARK: Tests

    func testJSONParameterEncodeNilParameters() {
        // Given
        // When
        let (URLRequest, error) = encoding.encode(self.urlRequest, parameters: nil)

        // Then
        XCTAssertNil(error, "error should be nil")
        XCTAssertNil(URLRequest.url?.query, "query should be nil")
        XCTAssertNil(URLRequest.value(forHTTPHeaderField: "Content-Type"), "Content-Type should be nil")
        XCTAssertNil(URLRequest.httpBody, "HTTPBody should be nil")
    }

    func testJSONParameterEncodeComplexParameters() {
        // Given
        let parameters = [
            "foo": "bar",
            "baz": ["a", 1, true],
            "qux": [
                "a": 1,
                "b": [2, 2],
                "c": [3, 3, 3]
            ]
        ]

        // When
        let (URLRequest, error) = encoding.encode(self.urlRequest, parameters: parameters)

        // Then
        XCTAssertNil(error, "error should be nil")
        XCTAssertNil(URLRequest.url?.query, "query should be nil")
        XCTAssertNotNil(URLRequest.value(forHTTPHeaderField: "Content-Type"), "Content-Type should not be nil")
        XCTAssertEqual(
            URLRequest.value(forHTTPHeaderField: "Content-Type") ?? "",
            "application/json",
            "Content-Type should be application/json"
        )
        XCTAssertNotNil(URLRequest.httpBody, "HTTPBody should not be nil")

        if let HTTPBody = URLRequest.httpBody {
            do {
                let JSON = try JSONSerialization.jsonObject(with: HTTPBody, options: .allowFragments)

                if let JSON = JSON as? NSObject {
                    XCTAssertEqual(JSON, parameters as NSObject, "HTTPBody JSON does not equal parameters")
                } else {
                    XCTFail("JSON should be an NSObject")
                }
            } catch {
                XCTFail("JSON should not be nil")
            }
        } else {
            XCTFail("JSON should not be nil")
        }
    }

    func testJSONParameterEncodeParametersRetainsCustomContentType() {
        // Given
        var mutableURLRequest = Foundation.URLRequest(url: URL(string: "https://example.com/")!)
        mutableURLRequest.setValue("application/custom-json-type+json", forHTTPHeaderField: "Content-Type")

        let parameters = ["foo": "bar"]

        // When
        let (URLRequest, error) = encoding.encode(mutableURLRequest, parameters: parameters)

        // Then
        XCTAssertNil(error)
        XCTAssertNil(URLRequest.url?.query)
        XCTAssertEqual(URLRequest.value(forHTTPHeaderField: "Content-Type"), "application/custom-json-type+json")
    }
}

// MARK: -

class PropertyListParameterEncodingTestCase: ParameterEncodingTestCase {
    // MARK: Properties

    let encoding: ParameterEncoding = .propertyList(.xml, 0)

    // MARK: Tests

    func testPropertyListParameterEncodeNilParameters() {
        // Given
        // When
        let (URLRequest, error) = encoding.encode(self.urlRequest, parameters: nil)

        // Then
        XCTAssertNil(error, "error should be nil")
        XCTAssertNil(URLRequest.url?.query, "query should be nil")
        XCTAssertNil(URLRequest.value(forHTTPHeaderField: "Content-Type"), "Content-Type should be nil")
        XCTAssertNil(URLRequest.httpBody, "HTTPBody should be nil")
    }

    func testPropertyListParameterEncodeComplexParameters() {
        // Given
        let parameters = [
            "foo": "bar",
            "baz": ["a", 1, true],
            "qux": [
                "a": 1,
                "b": [2, 2],
                "c": [3, 3, 3]
            ]
        ]

        // When
        let (URLRequest, error) = encoding.encode(self.urlRequest, parameters: parameters)

        // Then
        XCTAssertNil(error, "error should be nil")
        XCTAssertNil(URLRequest.url?.query, "query should be nil")
        XCTAssertNotNil(URLRequest.value(forHTTPHeaderField: "Content-Type"), "Content-Type should not be nil")
        XCTAssertEqual(
            URLRequest.value(forHTTPHeaderField: "Content-Type") ?? "",
            "application/x-plist",
            "Content-Type should be application/x-plist"
        )
        XCTAssertNotNil(URLRequest.httpBody, "HTTPBody should not be nil")

        if let HTTPBody = URLRequest.httpBody {
            do {
                let plist = try PropertyListSerialization.propertyList(
                    from: HTTPBody,
                    options: PropertyListSerialization.MutabilityOptions(),
                    format: nil
                )
                if let plist = plist as? NSObject {
                    XCTAssertEqual(plist, parameters as NSObject, "HTTPBody plist does not equal parameters")
                } else {
                    XCTFail("plist should be an NSObject")
                }
            } catch {
                XCTFail("plist should not be nil")
            }
        }
    }

    func testPropertyListParameterEncodeDateAndDataParameters() {
        // Given
        let date: Date = Date()
        let data: Data = "data".data(using: String.Encoding.utf8, allowLossyConversion: false)!

        let parameters = [
            "date": date,
            "data": data
        ]

        // When
        let (urlRequest, error) = encoding.encode(self.urlRequest, parameters: parameters as? [String : AnyObject])

        // Then
        XCTAssertNil(error, "error should be nil")
        XCTAssertNil(urlRequest.url?.query, "query should be nil")
        XCTAssertNotNil(urlRequest.value(forHTTPHeaderField: "Content-Type"), "Content-Type should not be nil")
        XCTAssertEqual(
            urlRequest.value(forHTTPHeaderField: "Content-Type") ?? "",
            "application/x-plist",
            "Content-Type should be application/x-plist"
        )
        XCTAssertNotNil(urlRequest.httpBody, "HTTPBody should not be nil")

        if let HTTPBody = urlRequest.httpBody {
            do {
                let plist = try PropertyListSerialization.propertyList(
                    from: HTTPBody,
                    options: PropertyListSerialization.MutabilityOptions(),
                    format: nil
                )
                XCTAssertTrue(plist.value(forKey: "date") is NSDate, "date is not NSDate")
                XCTAssertTrue(plist.value(forKey: "data") is NSData, "data is not NSData")
            } catch {
                XCTFail("plist should not be nil")
            }
        } else {
            XCTFail("HTTPBody should not be nil")
        }
    }

    func testPropertyListParameterEncodeParametersRetainsCustomContentType() {
        // Given
        var mutableURLRequest = Foundation.URLRequest(url: URL(string: "https://example.com/")!)
        mutableURLRequest.setValue("application/custom-plist-type+plist", forHTTPHeaderField: "Content-Type")

        let parameters = ["foo": "bar"]

        // When
        let (urlRequest, error) = encoding.encode(mutableURLRequest, parameters: parameters)

        // Then
        XCTAssertNil(error)
        XCTAssertNil(urlRequest.url?.query)
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Content-Type"), "application/custom-plist-type+plist")
    }
}

// MARK: -

class CustomParameterEncodingTestCase: ParameterEncodingTestCase {
    // MARK: Tests

    func testCustomParameterEncode() {
        // Given
        let encodingClosure: (URLRequestConvertible, [String: AnyObject]?) -> (Foundation.URLRequest, NSError?) = { urlRequest, parameters in
            guard let parameters = parameters else { return (urlRequest.urlRequest, nil) }

            var urlString = urlRequest.urlRequest.urlString + "?"

            parameters.forEach { urlString += "\($0)=\($1)" }

            var mutableURLRequest = urlRequest.urlRequest
            mutableURLRequest.url = Foundation.URL(string: urlString)!

            return (mutableURLRequest, nil)
        }

        // When
        let encoding: ParameterEncoding = .custom(encodingClosure)

        // Then
        let url = Foundation.URL(string: "https://example.com")!
        let urlRequest = Foundation.URLRequest(url: url)
        let parameters: [String: AnyObject] = ["foo": "bar"]

        let result = encoding.encode(urlRequest, parameters: parameters)
        XCTAssertEqual(result.0.urlString, "https://example.com?foo=bar")
    }
}
