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
    var URLRequest: NSURLRequest!

    override func setUp()  {
        super.setUp()

        let URL = NSURL(string: "http://example.com/")!
        self.URLRequest = NSURLRequest(URL: URL)
    }

    // MARK: -

    func testURLParameterEncodeNilParameters() {
        let (URLRequest, error) = self.encoding.encode(self.URLRequest, parameters: nil)

        XCTAssertNil(URLRequest.URL.query?, "query should be nil")
    }

    func testURLParameterEncodeOneStringKeyStringValueParameter() {
        let parameters = ["foo": "bar"]
        let (URLRequest, error) = self.encoding.encode(self.URLRequest, parameters: parameters)

        XCTAssertEqual(URLRequest.URL.query!, "foo=bar", "query is incorrect")
    }

    func testURLParameterEncodeOneStringKeyStringValueParameterAppendedToQuery() {
        var mutableURLRequest = self.URLRequest.mutableCopy() as NSMutableURLRequest
        let URLComponents = NSURLComponents(URL: mutableURLRequest.URL!, resolvingAgainstBaseURL: false)!
        URLComponents.query = "baz=qux"
        mutableURLRequest.URL = URLComponents.URL

        let parameters = ["foo": "bar"]
        let (URLRequest, error) = self.encoding.encode(mutableURLRequest, parameters: parameters)

        XCTAssertEqual(URLRequest.URL.query!, "baz=qux&foo=bar", "query is incorrect")
    }

    func testURLParameterEncodeTwoStringKeyStringValueParameters() {
        let parameters = ["foo": "bar", "baz": "qux"]
        let (URLRequest, error) = self.encoding.encode(self.URLRequest, parameters: parameters)

        XCTAssertEqual(URLRequest.URL.query!, "baz=qux&foo=bar", "query is incorrect")
    }

    func testURLParameterEncodeStringKeyIntegerValueParameter() {
        let parameters = ["foo": 1]
        let (URLRequest, error) = self.encoding.encode(self.URLRequest, parameters: parameters)

        XCTAssertEqual(URLRequest.URL.query!, "foo=1", "query is incorrect")
    }

    func testURLParameterEncodeStringKeyDoubleValueParameter() {
        let parameters = ["foo": 1.1]
        let (URLRequest, error) = self.encoding.encode(self.URLRequest, parameters: parameters)

        XCTAssertEqual(URLRequest.URL.query!, "foo=1.1", "query is incorrect")
    }

    func testURLParameterEncodeStringKeyBoolValueParameter() {
        let parameters = ["foo": true]
        let (URLRequest, error) = self.encoding.encode(self.URLRequest, parameters: parameters)

        XCTAssertEqual(URLRequest.URL.query!, "foo=1", "query is incorrect")
    }

    func testURLParameterEncodeStringKeyArrayValueParameter() {
        let parameters = ["foo": ["a", 1, true]]
        let (URLRequest, error) = self.encoding.encode(self.URLRequest, parameters: parameters)

        XCTAssertEqual(URLRequest.URL.query!, "foo%5B%5D=a&foo%5B%5D=1&foo%5B%5D=1", "query is incorrect")
    }

    func testURLParameterEncodeStringKeyDictionaryValueParameter() {
        let parameters = ["foo": ["bar": 1]]
        let (URLRequest, error) = self.encoding.encode(self.URLRequest, parameters: parameters)

        XCTAssertEqual(URLRequest.URL.query!, "foo%5Bbar%5D=1", "query is incorrect")
    }

    func testURLParameterEncodeStringKeyNestedDictionaryValueParameter() {
        let parameters = ["foo": ["bar": ["baz": 1]]]
        let (URLRequest, error) = self.encoding.encode(self.URLRequest, parameters: parameters)

        XCTAssertEqual(URLRequest.URL.query!, "foo%5Bbar%5D%5Bbaz%5D=1", "query is incorrect")
    }

    func testURLParameterEncodeStringKeyNestedDictionaryArrayValueParameter() {
        let parameters = ["foo": ["bar": ["baz": ["a", 1, true]]]]
        let (URLRequest, error) = self.encoding.encode(self.URLRequest, parameters: parameters)

        XCTAssertEqual(URLRequest.URL.query!, "foo%5Bbar%5D%5Bbaz%5D%5B%5D=a&foo%5Bbar%5D%5Bbaz%5D%5B%5D=1&foo%5Bbar%5D%5Bbaz%5D%5B%5D=1", "query is incorrect")
    }

    func testURLParameterEncodeStringWithAmpersandKeyStringWithAmpersandValueParameter() {
        let parameters = ["foo&bar": "baz&qux", "foobar": "bazqux"]
        let (URLRequest, error) = self.encoding.encode(self.URLRequest, parameters: parameters)

        XCTAssertEqual(URLRequest.URL.query!, "foo%26bar=baz%26qux&foobar=bazqux", "query is incorrect")
    }

    func testURLParameterEncodeStringWithQuestionMarkKeyStringWithQuestionMarkValueParameter() {
        let parameters = ["?foo?": "?bar?"]
        let (URLRequest, error) = self.encoding.encode(self.URLRequest, parameters: parameters)

        XCTAssertEqual(URLRequest.URL.query!, "%3Ffoo%3F=%3Fbar%3F", "query is incorrect")
    }

    func testURLParameterEncodeStringWithSpaceKeyStringWithSpaceValueParameter() {
        let parameters = [" foo ": " bar "]
        let (URLRequest, error) = self.encoding.encode(self.URLRequest, parameters: parameters)

        XCTAssertEqual(URLRequest.URL.query!, "%20foo%20=%20bar%20", "query is incorrect")
    }

    func testURLParameterEncodeStringWithPlusKeyStringWithPlusValueParameter() {
        let parameters = ["+foo+": "+bar+"]
        let (URLRequest, error) = self.encoding.encode(self.URLRequest, parameters: parameters)
        
        XCTAssertEqual(URLRequest.URL.query!, "%2Bfoo%2B=%2Bbar%2B", "query is incorrect")
    }

    func testURLParameterEncodeStringKeyAllowedCharactersStringValueParameter() {
        let parameters = ["allowed": " =\"#%/<>?@\\^`{}[]|&"]
        let (URLRequest, error) = self.encoding.encode(self.URLRequest, parameters: parameters)

        XCTAssertEqual(URLRequest.URL.query!, "allowed=%20%3D%22%23%25%2F%3C%3E%3F%40%5C%5E%60%7B%7D%5B%5D%7C%26", "query is incorrect")
    }

    func testURLParameterEncodeStringKeyPercentEncodedStringValueParameter() {
        let parameters = ["percent": "%25"]
        let (URLRequest, error) = self.encoding.encode(self.URLRequest, parameters: parameters)

        XCTAssertEqual(URLRequest.URL.query!, "percent=%2525", "query is incorrect")
    }

    func testURLParameterEncodeStringKeyNonLatinStringValueParameter() {
        let parameters = [
            "french": "français",
            "japanese": "日本語",
            "arabic": "العربية",
            "emoji": "😃"
        ]
        let (URLRequest, error) = self.encoding.encode(self.URLRequest, parameters: parameters)

        XCTAssertEqual(URLRequest.URL.query!, "arabic=%D8%A7%D9%84%D8%B9%D8%B1%D8%A8%D9%8A%D8%A9&emoji=%F0%9F%98%83&french=fran%C3%A7ais&japanese=%E6%97%A5%E6%9C%AC%E8%AA%9E", "query is incorrect")
    }
    
    func testURLParameterEncodeStringForRequestWithPrecomposedQuery() {
        
        let URL = NSURL(string: "http://example.com/movies?hd=[1]")!
        
        let parameters = ["page": "0"]
        let (URLRequest, error) = self.encoding.encode(NSURLRequest(URL: URL), parameters: parameters)
        
        XCTAssertEqual(URLRequest.URL.query!, "hd=%5B1%5D&page=0", "query is incorrect")
    }

    func testURLParameterEncodeStringWithPlusKeyStringWithPlusValueParameterForRequestWithPrecomposedQuery() {
        
        let URL = NSURL(string: "http://example.com/movie?hd=[1]")!
        
        let parameters = ["+foo+": "+bar+"]
        let (URLRequest, error) = self.encoding.encode(NSURLRequest(URL: URL), parameters: parameters)
        
        XCTAssertEqual(URLRequest.URL.query!, "hd=%5B1%5D&%2Bfoo%2B=%2Bbar%2B", "query is incorrect")
    }
    
    func testURLParameterEncodeGETParametersInURL() {
        var mutableURLRequest = self.URLRequest.mutableCopy() as NSMutableURLRequest
        mutableURLRequest.HTTPMethod = Method.GET.rawValue

        let parameters = ["foo": 1, "bar": 2]
        let (URLRequest, error) = self.encoding.encode(mutableURLRequest, parameters: parameters)

        XCTAssertEqual(URLRequest.URL.query!, "bar=2&foo=1", "query is incorrect")
        XCTAssertNil(URLRequest.valueForHTTPHeaderField("Content-Type"), "Content-Type should be nil")
        XCTAssertNil(URLRequest.HTTPBody, "HTTPBody should be nil")
    }

    func testURLParameterEncodePOSTParametersInHTTPBody() {
        var mutableURLRequest = self.URLRequest.mutableCopy() as NSMutableURLRequest
        mutableURLRequest.HTTPMethod = Method.POST.rawValue

        let parameters = ["foo": 1, "bar": 2]
        let (URLRequest, error) = self.encoding.encode(mutableURLRequest, parameters: parameters)

        XCTAssertEqual(NSString(data: URLRequest.HTTPBody!, encoding: NSUTF8StringEncoding)!, "bar=2&foo=1", "HTTPBody is incorrect")
        XCTAssertEqual(URLRequest.valueForHTTPHeaderField("Content-Type")!, "application/x-www-form-urlencoded", "Content-Type should be application/x-www-form-urlencoded")
        XCTAssertNotNil(URLRequest.HTTPBody, "HTTPBody should not be nil")
    }
}

class AlamofireJSONParameterEncodingTestCase: XCTestCase {
    let encoding: ParameterEncoding = .JSON
    var URLRequest: NSURLRequest!

    override func setUp()  {
        super.setUp()

        let URL = NSURL(string: "http://example.com/")!
        self.URLRequest = NSURLRequest(URL: URL)
    }

    // MARK: -

    func testJSONParameterEncodeNilParameters() {
        let (URLRequest, error) = self.encoding.encode(self.URLRequest, parameters: nil)

        XCTAssertNil(error, "error should be nil")
        XCTAssertNil(URLRequest.URL.query?, "query should be nil")
        XCTAssertNil(URLRequest.valueForHTTPHeaderField("Content-Type"), "Content-Type should be nil")
        XCTAssertNil(URLRequest.HTTPBody, "HTTPBody should be nil")
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

        let (URLRequest, error) = self.encoding.encode(self.URLRequest, parameters: parameters)

        XCTAssertNil(error, "error should be nil")
        XCTAssertNil(URLRequest.URL.query?, "query should be nil")
        XCTAssertNotNil(URLRequest.valueForHTTPHeaderField("Content-Type"), "Content-Type should not be nil")
        XCTAssert(URLRequest.valueForHTTPHeaderField("Content-Type")!.hasPrefix("application/json"), "Content-Type should be application/json")
        XCTAssertNotNil(URLRequest.HTTPBody, "HTTPBody should not be nil")

        let JSON = NSJSONSerialization.JSONObjectWithData(URLRequest.HTTPBody!, options: .AllowFragments, error: nil) as NSObject!
        XCTAssertNotNil(JSON, "HTTPBody JSON is invalid")
        XCTAssertEqual(JSON as NSObject, parameters as NSObject, "HTTPBody JSON does not equal parameters")
    }
}

class AlamofirePropertyListParameterEncodingTestCase: XCTestCase {
    let encoding: ParameterEncoding = .PropertyList(.XMLFormat_v1_0, 0)
    var URLRequest: NSURLRequest!

    override func setUp()  {
        super.setUp()

        let URL = NSURL(string: "http://example.com/")!
        self.URLRequest = NSURLRequest(URL: URL)
    }

    // MARK: -

    func testPropertyListParameterEncodeNilParameters() {
        let (URLRequest, error) = self.encoding.encode(self.URLRequest, parameters: nil)

        XCTAssertNil(error, "error should be nil")
        XCTAssertNil(URLRequest.URL.query?, "query should be nil")
        XCTAssertNil(URLRequest.valueForHTTPHeaderField("Content-Type"), "Content-Type should be nil")
        XCTAssertNil(URLRequest.HTTPBody, "HTTPBody should be nil")
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

        let (URLRequest, error) = self.encoding.encode(self.URLRequest, parameters: parameters)

        XCTAssertNil(error, "error should be nil")
        XCTAssertNil(URLRequest.URL.query?, "query should be nil")
        XCTAssertNotNil(URLRequest.valueForHTTPHeaderField("Content-Type"), "Content-Type should not be nil")
        XCTAssert(URLRequest.valueForHTTPHeaderField("Content-Type")!.hasPrefix("application/x-plist"), "Content-Type should be application/x-plist")
        XCTAssertNotNil(URLRequest.HTTPBody, "HTTPBody should not be nil")

        let plist = NSPropertyListSerialization.propertyListWithData(URLRequest.HTTPBody!, options: 0, format: nil, error: nil) as NSObject
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

        let (URLRequest, error) = self.encoding.encode(self.URLRequest, parameters: parameters)

        XCTAssertNil(error, "error should be nil")
        XCTAssertNil(URLRequest.URL.query?, "query should be nil")
        XCTAssertNotNil(URLRequest.valueForHTTPHeaderField("Content-Type"), "Content-Type should not be nil")
        XCTAssert(URLRequest.valueForHTTPHeaderField("Content-Type")!.hasPrefix("application/x-plist"), "Content-Type should be application/x-plist")
        XCTAssertNotNil(URLRequest.HTTPBody, "HTTPBody should not be nil")

        let plist = NSPropertyListSerialization.propertyListWithData(URLRequest.HTTPBody!, options: 0, format: nil, error: nil) as NSObject!
        XCTAssertNotNil(plist, "HTTPBody JSON is invalid")
        XCTAssert(plist.valueForKey("date") is NSDate, "date is not NSDate")
        XCTAssert(plist.valueForKey("data") is NSData, "data is not NSData")
    }
}

class AlamofireCustomParameterEncodingTestCase: XCTestCase {
    func testCustomParameterEncode() {
        let encodingClosure: (URLRequestConvertible, [String: AnyObject]?) -> (NSURLRequest, NSError?) = { (URLRequest, parameters) in
            let mutableURLRequest = URLRequest.URLRequest.mutableCopy() as NSMutableURLRequest
            mutableURLRequest.setValue("Xcode", forHTTPHeaderField: "User-Agent")
            return (mutableURLRequest, nil)
        }

        let encoding: ParameterEncoding = .Custom(encodingClosure)

        let URL = NSURL(string: "http://example.com")!
        let URLRequest = NSURLRequest(URL: URL)
        let parameters: [String: AnyObject] = [:]

        XCTAssertEqual(encoding.encode(URLRequest, parameters: parameters).0, encodingClosure(URLRequest, parameters).0, "URLRequest should be equal")
    }
}
