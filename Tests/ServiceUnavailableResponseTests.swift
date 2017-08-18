//
//  ServiceUnavailableResponseTests.swift
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

import XCTest
@testable import Alamofire

class ServiceUnavailableResponseTests: XCTestCase {
    fileprivate let dummyUrl:URL = URL(string: "http://dummy")!
    
    func test_getRetryAfter_withRetryAfterHeaderSeconds_returnsFalse() {
        let expectedSeconds = 21
        let secondsHeader = ["Retry-After" : "\(expectedSeconds)"]
        
        let retryAfter = ServiceUnavailableResponse.getRetryAfter(allHeaderFields: secondsHeader)
        XCTAssertNotNil(retryAfter)
        XCTAssertNotNil(retryAfter?.seconds)
        XCTAssertEqual(retryAfter?.seconds!, expectedSeconds)
    }
    
    func test_getRetryAfter_withRetryAfterHeader24HourHTTPFormattedDate_returnsFalse() {
        let dateString = "Fri, 31 Dec 2017 23:59:59 GMT"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, dd LLL yyyy HH:mm:ss zzz"
        let expectedDate = dateFormatter.date(from: dateString)
        let httpFormattedDateHeader = ["Retry-After" : dateString]
        
        let retryAfter = ServiceUnavailableResponse.getRetryAfter(allHeaderFields: httpFormattedDateHeader)
        XCTAssertNotNil(retryAfter)
        XCTAssertNotNil(retryAfter?.date)
        XCTAssertEqual(retryAfter?.date, expectedDate)
    }
    
    func test_getRetryAfter_withInvalidHeaderValue_returnsFalse() {
        let invalidValue = "i'm invalid"
        let invalidValueHeader = ["Retry-After" : "\(invalidValue)"]
        
        let retryAfter = ServiceUnavailableResponse.getRetryAfter(allHeaderFields: invalidValueHeader)
        XCTAssertNil(retryAfter)
    }
    
    func test_isServiceUnavailableResponse_with503AndRetryAfterHeaderSeconds_returnsFalse() {
        let response503 = HTTPURLResponse(
            url: dummyUrl,
            statusCode: 503,
            httpVersion: "HTTP/1.1",
            headerFields: ["Retry-After" : "20"]
            )!
        let isServiceUnavailableResponse = ServiceUnavailableResponse.isServiceUnavailableResponse(response: response503)
        XCTAssertTrue(isServiceUnavailableResponse)
    }
    
    func test_isServiceUnavailableResponse_with503AndRetryAfterHeader24HourHTTPFormattedDate_returnsFalse() {
        let response503 = HTTPURLResponse(
            url: dummyUrl,
            statusCode: 503,
            httpVersion: "HTTP/1.1",
            headerFields: ["Retry-After" : "Fri, 31 Dec 2017 23:59:59 GMT"]
            )!
        let isServiceUnavailableResponse = ServiceUnavailableResponse.isServiceUnavailableResponse(response: response503)
        XCTAssertTrue(isServiceUnavailableResponse)
    }
    
    func test_isServiceUnavailableResponse_with503AndNoRetryAfterHeader_returnsFalse() {
        let response503 = HTTPURLResponse(
            url: dummyUrl,
            statusCode: 503,
            httpVersion: "HTTP/1.1",
            headerFields: nil
            )!
        let isServiceUnavailableResponse = ServiceUnavailableResponse.isServiceUnavailableResponse(response: response503)
        XCTAssertFalse(isServiceUnavailableResponse)
    }
    
    func test_isServiceUnavailableResponse_with200OK_returnsFalse() {
        let response200Ok = HTTPURLResponse(
            url: dummyUrl,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
        let isServiceUnavailableResponse = ServiceUnavailableResponse.isServiceUnavailableResponse(response: response200Ok)
        XCTAssertFalse(isServiceUnavailableResponse)
    }
    
    func test_isServiceUnavailableResponse_with200OKEmptyHeaders_returnsFalse() {
        let response200Ok = HTTPURLResponse(
            url: dummyUrl,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [:]
            )!
        let isServiceUnavailableResponse = ServiceUnavailableResponse.isServiceUnavailableResponse(response: response200Ok)
        XCTAssertFalse(isServiceUnavailableResponse)
    }
    
    func test_isServiceUnavailableResponse_with200OKAndRetryAfterHeader_returnsFalse() {
        let response200Ok = HTTPURLResponse(
            url: dummyUrl,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Retry-After" : "20"]
            )!
        let isServiceUnavailableResponse = ServiceUnavailableResponse.isServiceUnavailableResponse(response: response200Ok)
        XCTAssertFalse(isServiceUnavailableResponse)
    }
    
}
