//
//  SessionDelegateTests.swift
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

@testable import Alamofire
import Foundation
import XCTest

class SessionDelegateTestCase: BaseTestCase {
    var manager: Session!

    // MARK: - Setup and Teardown

    override func setUp() {
        super.setUp()
        manager = Session(configuration: .ephemeral)
    }

    // MARK: - Tests - Redirects

    func testThatRequestWillPerformHTTPRedirectionByDefault() {
        // Given
        let redirectURLString = "https://www.apple.com/"
        let urlString = "https://httpbin.org/redirect-to?url=\(redirectURLString)"

        let expectation = self.expectation(description: "Request should redirect to \(redirectURLString)")

        var response: DataResponse<Data?>?

        // When
        manager.request(urlString)
            .response { resp in
                response = resp
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertNil(response?.error)

        XCTAssertEqual(response?.response?.url?.absoluteString, redirectURLString)
        XCTAssertEqual(response?.response?.statusCode, 200)
    }

    func testThatRequestWillPerformRedirectionMultipleTimesByDefault() {
        // Given
        let redirectURLString = "https://httpbin.org/get"
        let urlString = "https://httpbin.org/redirect/5"

        let expectation = self.expectation(description: "Request should redirect to \(redirectURLString)")

        var response: DataResponse<Data?>?

        // When
        manager.request(urlString)
            .response { resp in
                response = resp
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertNil(response?.error)

        XCTAssertEqual(response?.response?.url?.absoluteString, redirectURLString)
        XCTAssertEqual(response?.response?.statusCode, 200)
    }

    func testThatAppropriateNotificationsAreCalledWithRequestForDataRequest() {
        // Given
        var request: Request?
        _ = expectation(forNotification: Request.didResume, object: nil, handler: nil)
        _ = expectation(forNotification: Request.didComplete, object: nil) { (notification) in
            request = notification.request
            return (request != nil)
        }

        // When
        manager.request("https://httpbin.org/get").response { _ in }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(request?.response?.statusCode, 200)
    }

    func testThatDidCompleteNotificationIsCalledWithRequestForDownloadRequests() {
        // Given
        var request: Request?
        _ = expectation(forNotification: Request.didResume, object: nil, handler: nil)
        _ = expectation(forNotification: Request.didComplete, object: nil) { (notification) in
            request = notification.request
            return (request != nil)
        }

        // When
        manager.download("https://httpbin.org/get").response { _ in }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertEqual(request?.response?.statusCode, 200)
    }
}
