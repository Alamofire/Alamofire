// RequestTests.swift
//
// Copyright (c) 2014–2015 Alamofire (http://alamofire.org)
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

class AlamofireManagerTestCase: XCTestCase {
    func testSetStartRequestsImmediatelyToFalseAndResumeRequest() {
        let manager = Alamofire.Manager()
        manager.startRequestsImmediately = false

        let URL = NSURL(string: "http://httpbin.org/get")!
        let URLRequest = NSURLRequest(URL: URL)

        let expectation = expectationWithDescription("\(URL)")

        manager.request(URLRequest)
            .response { (_,_,_,_) in expectation.fulfill() }
            .resume()

        waitForExpectationsWithTimeout(10) { (error) in
            XCTAssertNil(error, "\(error)")
        }
    }

    func testReleasingManagerWithPendingRequestDeinitializesSuccessfully() {
        var manager: Manager? = Alamofire.Manager()
        manager!.startRequestsImmediately = false

        let URL = NSURL(string: "http://httpbin.org/get")!
        let URLRequest = NSURLRequest(URL: URL)

        let request = manager!.request(URLRequest)

        manager = nil

        XCTAssert(request.task.state == .Suspended)
        XCTAssertNil(manager)
    }
}
