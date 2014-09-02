// ParameterEncodingTests.swift
//
// Copyright (c) 2014 Alamofire (http://alamofire.org)
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

import Foundation
import Alamofire
import XCTest

class AlamofireURLParameterEncodingTestCase: XCTestCase {
    let encoding: ParameterEncoding = .URL
    var request: NSURLRequest!

    override func setUp()  {
        super.setUp()

        let URL = NSURL(string: "http://example.com/")
        self.request = NSURLRequest(URL: URL)
    }

    // MARK: -

    func testURLParameterEncodeNilParameters() {
        let (request, error) = self.encoding.encode(self.request, parameters: nil)

        XCTAssertNil(request.URL.query?, "query should be nil")
    }

    func testURLParameterEncodeOneStringKeyStringValueParameter() {
        let parameters = ["foo": "bar"]
        let (request, error) = self.encoding.encode(self.request, parameters: parameters)

        XCTAssertEqual(request.URL.query!, "foo=bar", "query is incorrect")
    }

    func testURLParameterEncodeOneStringKeyStringValueParameterAppendedToQuery() {
        var mutableRequest = self.request.mutableCopy() as NSMutableURLRequest
        let URLComponents = NSURLComponents(URL: mutableRequest.URL!, resolvingAgainstBaseURL: false)
        URLComponents.query = "baz=qux"
        mutableRequest.URL = URLComponents.URL

        let parameters = ["foo": "bar"]
        let (request, error) = self.encoding.encode(mutableRequest, parameters: parameters)

        XCTAssertEqual(request.URL.query!, "baz=qux&foo=bar", "query is incorrect")
    }

    func testURLParameterEncodeTwoStringKeyStringValueParameters() {
        let parameters = ["foo": "bar", "baz": "qux"]
        let (request, error) = self.encoding.encode(self.request, parameters: parameters)

        XCTAssertEqual(request.URL.query!, "baz=qux&foo=bar", "query is incorrect")
    }

    func testURLParameterEncodeStringKeyIntegerValueParameter() {
        let parameters = ["foo": 1]
        let (request, error) = self.encoding.encode(self.request, parameters: parameters)

        XCTAssertEqual(request.URL.query!, "foo=1", "query is incorrect")
    }

    func testURLParameterEncodeStringKeyDoubleValueParameter() {
        let parameters = ["foo": 1.1]
        let (request, error) = self.encoding.encode(self.request, parameters: parameters)

        XCTAssertEqual(request.URL.query!, "foo=1.1", "query is incorrect")
    }

    func testURLParameterEncodeStringKeyBoolValueParameter() {
        let parameters = ["foo": true]
        let (request, error) = self.encoding.encode(self.request, parameters: parameters)

        XCTAssertEqual(request.URL.query!, "foo=1", "query is incorrect")
    }

    func testURLParameterEncodeStringKeyArrayValueParameter() {
        let parameters = ["foo": ["a", 1, true]]
        let (request, error) = self.encoding.encode(self.request, parameters: parameters)

        XCTAssertEqual(request.URL.query!, "foo%5B%5D=a&foo%5B%5D=1&foo%5B%5D=1", "query is incorrect")
    }

    func testURLParameterEncodeStringKeyDictionaryValueParameter() {
        let parameters = ["foo": ["bar": 1]]
        let (request, error) = self.encoding.encode(self.request, parameters: parameters)

        XCTAssertEqual(request.URL.query!, "foo%5Bbar%5D=1", "query is incorrect")
    }

    func testURLParameterEncodeStringKeyNestedDictionaryValueParameter() {
        let parameters = ["foo": ["bar": ["baz": 1]]]
        let (request, error) = self.encoding.encode(self.request, parameters: parameters)

        XCTAssertEqual(request.URL.query!, "foo%5Bbar%5D%5Bbaz%5D=1", "query is incorrect")
    }

    func testURLParameterEncodeStringKeyNestedDictionaryArrayValueParameter() {
        let parameters = ["foo": ["bar": ["baz": ["a", 1, true]]]]
        let (request, error) = self.encoding.encode(self.request, parameters: parameters)

        XCTAssertEqual(request.URL.query!, "foo%5Bbar%5D%5Bbaz%5D%5B%5D=a&foo%5Bbar%5D%5Bbaz%5D%5B%5D=1&foo%5Bbar%5D%5Bbaz%5D%5B%5D=1", "query is incorrect")
    }

    func testURLParameterEncodeStringKeyPercentEncodedStringValueParameter() {
        let parameters = ["percent": "%25"]
        let (request, error) = self.encoding.encode(self.request, parameters: parameters)

        XCTAssertEqual(request.URL.query!, "percent=%2525", "query is incorrect")
    }

    func testURLParameterEncodeStringKeyNonLatinStringValueParameter() {
        let parameters = [
            "french": "français",
            "japanese": "日本語",
            "arabic": "العربية",
            "emoji": "😃"
        ]
        let (request, error) = self.encoding.encode(self.request, parameters: parameters)

        XCTAssertEqual(request.URL.query!, "arabic=%D8%A7%D9%84%D8%B9%D8%B1%D8%A8%D9%8A%D8%A9&emoji=%F0%9F%98%83&french=fran%C3%A7ais&japanese=%E6%97%A5%E6%9C%AC%E8%AA%9E", "query is incorrect")
    }

    func testURLParameterEncodeGETParametersInURL() {
        var mutableRequest = self.request.mutableCopy() as NSMutableURLRequest
        mutableRequest.HTTPMethod = Method.GET.toRaw()

        let parameters = ["foo": 1, "bar": 2]
        let (request, error) = self.encoding.encode(mutableRequest, parameters: parameters)

        XCTAssertEqual(request.URL.query!, "bar=2&foo=1", "query is incorrect")
        XCTAssertNil(request.valueForHTTPHeaderField("Content-Type"), "Content-Type should be nil")
        XCTAssertNil(request.HTTPBody, "HTTPBody should be nil")
    }

    func testURLParameterEncodePOSTParametersInHTTPBody() {
        var mutableRequest = self.request.mutableCopy() as NSMutableURLRequest
        mutableRequest.HTTPMethod = Method.POST.toRaw()

        let parameters = ["foo": 1, "bar": 2]
        let (request, error) = self.encoding.encode(mutableRequest, parameters: parameters)

        XCTAssertEqual(NSString(data: request.HTTPBody!, encoding: NSUTF8StringEncoding), "bar=2&foo=1", "HTTPBody is incorrect")
        XCTAssertEqual(request.valueForHTTPHeaderField("Content-Type")!, "application/x-www-form-urlencoded", "Content-Type should be application/x-www-form-urlencoded")
        XCTAssertNotNil(request.HTTPBody, "HTTPBody should not be nil")
    }
}

class AlamofireJSONParameterEncodingTestCase: XCTestCase {
    let encoding: ParameterEncoding = .JSON
    var request: NSURLRequest!

    override func setUp()  {
        super.setUp()

        let URL = NSURL(string: "http://example.com/")
        self.request = NSURLRequest(URL: URL)
    }

    // MARK: -

    func testJSONParameterEncodeNilParameters() {
        let (request, error) = self.encoding.encode(self.request, parameters: nil)

        XCTAssertNil(error, "error should be nil")
        XCTAssertNil(request.URL.query?, "query should be nil")
        XCTAssertNil(request.valueForHTTPHeaderField("Content-Type"), "Content-Type should be nil")
        XCTAssertNil(request.HTTPBody, "HTTPBody should be nil")
    }

    func testJSONParameterEncodeComplexParameters() {
        let parameters = [
            "foo": "bar",
            "baz": ["a", 1, true],
            "qux": ["a": 1,
                    "b": [2, 2],
                    "c": [3, 3, 3]
                   ]
        ]

        let (request, error) = self.encoding.encode(self.request, parameters: parameters)

        XCTAssertNil(error, "error should be nil")
        XCTAssertNil(request.URL.query?, "query should be nil")
        XCTAssertNotNil(request.valueForHTTPHeaderField("Content-Type"), "Content-Type should not be nil")
        XCTAssert(request.valueForHTTPHeaderField("Content-Type")!.hasPrefix("application/json"), "Content-Type should be application/json")
        XCTAssertNotNil(request.HTTPBody, "HTTPBody should not be nil")

        let JSON = NSJSONSerialization.JSONObjectWithData(request.HTTPBody!, options: .AllowFragments, error: nil) as NSObject!
        XCTAssertNotNil(JSON, "HTTPBody JSON is invalid")
        XCTAssertEqual(JSON as NSObject, parameters as NSObject, "HTTPBody JSON does not equal parameters")
    }
}

class AlamofirePropertyListParameterEncodingTestCase: XCTestCase {
    let encoding: ParameterEncoding = .PropertyList(.XMLFormat_v1_0, 0)
    var request: NSURLRequest!

    override func setUp()  {
        super.setUp()

        let URL = NSURL(string: "http://example.com/")
        self.request = NSURLRequest(URL: URL)
    }

    // MARK: -

    func testPropertyListParameterEncodeNilParameters() {
        let (request, error) = self.encoding.encode(self.request, parameters: nil)

        XCTAssertNil(error, "error should be nil")
        XCTAssertNil(request.URL.query?, "query should be nil")
        XCTAssertNil(request.valueForHTTPHeaderField("Content-Type"), "Content-Type should be nil")
        XCTAssertNil(request.HTTPBody, "HTTPBody should be nil")
    }

    func testPropertyListParameterEncodeComplexParameters() {
        let parameters = [
            "foo": "bar",
            "baz": ["a", 1, true],
            "qux": ["a": 1,
                "b": [2, 2],
                "c": [3, 3, 3]
            ]
        ]

        let (request, error) = self.encoding.encode(self.request, parameters: parameters)

        XCTAssertNil(error, "error should be nil")
        XCTAssertNil(request.URL.query?, "query should be nil")
        XCTAssertNotNil(request.valueForHTTPHeaderField("Content-Type"), "Content-Type should not be nil")
        XCTAssert(request.valueForHTTPHeaderField("Content-Type")!.hasPrefix("application/x-plist"), "Content-Type should be application/x-plist")
        XCTAssertNotNil(request.HTTPBody, "HTTPBody should not be nil")

        let plist = NSPropertyListSerialization.propertyListWithData(request.HTTPBody!, options: 0, format: nil, error: nil) as NSObject
        XCTAssertNotNil(plist, "HTTPBody JSON is invalid")
        XCTAssertEqual(plist as NSObject, parameters as NSObject, "HTTPBody plist does not equal parameters")
    }

    func testPropertyListParameterEncodeDateAndDataParameters() {
        let date: NSDate = NSDate()
        let data: NSData = "data".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!

        let parameters = [
            "date": date,
            "data": data
        ]

        let (request, error) = self.encoding.encode(self.request, parameters: parameters)

        XCTAssertNil(error, "error should be nil")
        XCTAssertNil(request.URL.query?, "query should be nil")
        XCTAssertNotNil(request.valueForHTTPHeaderField("Content-Type"), "Content-Type should not be nil")
        XCTAssert(request.valueForHTTPHeaderField("Content-Type")!.hasPrefix("application/x-plist"), "Content-Type should be application/x-plist")
        XCTAssertNotNil(request.HTTPBody, "HTTPBody should not be nil")

        let plist = NSPropertyListSerialization.propertyListWithData(request.HTTPBody!, options: 0, format: nil, error: nil) as NSObject!
        XCTAssertNotNil(plist, "HTTPBody JSON is invalid")
        XCTAssert(plist.valueForKey("date") is NSDate, "date is not NSDate")
        XCTAssert(plist.valueForKey("data") is NSData, "data is not NSData")
    }
}
