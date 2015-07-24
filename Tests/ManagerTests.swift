// RequestTests.swift
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

class ManagerTestCase: BaseTestCase {
    func testSetStartRequestsImmediatelyToFalseAndResumeRequest() {
        // Given
        let manager = Alamofire.Manager()
        manager.startRequestsImmediately = false

        let URL = NSURL(string: "http://httpbin.org/get")!
        let URLRequest = NSURLRequest(URL: URL)

        let expectation = expectationWithDescription("\(URL)")

        var response: NSHTTPURLResponse?

        // When
        manager.request(URLRequest)
            .response { _, responseResponse, _, _ in
                response = responseResponse
                expectation.fulfill()
            }
            .resume()

        waitForExpectationsWithTimeout(self.defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertTrue(response?.statusCode == 200, "response status code should be 200")
    }

    func testReleasingManagerWithPendingRequestDeinitializesSuccessfully() {
        // Given
        var manager: Manager? = Alamofire.Manager()
        manager?.startRequestsImmediately = false

        let URL = NSURL(string: "http://httpbin.org/get")!
        let URLRequest = NSURLRequest(URL: URL)

        // When
        let request = manager?.request(URLRequest)
        manager = nil

        // Then
        XCTAssertTrue(request?.task.state == .Suspended, "request task state should be '.Suspended'")
        XCTAssertNil(manager, "manager should be nil")
    }

    func testReleasingManagerWithPendingCanceledRequestDeinitializesSuccessfully() {
        // Given
        var manager: Manager? = Alamofire.Manager()
        manager!.startRequestsImmediately = false

        let URL = NSURL(string: "http://httpbin.org/get")!
        let URLRequest = NSURLRequest(URL: URL)

        // When
        let request = manager!.request(URLRequest)
        request.cancel()
        manager = nil

        // Then
        let state = request.task.state
        XCTAssertTrue(state == .Canceling || state == .Completed, "state should be .Canceling or .Completed")
        XCTAssertNil(manager, "manager should be nil")
    }
}
