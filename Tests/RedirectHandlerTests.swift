//
//  RedirectHandlerTests.swift
//
//  Copyright (c) 2019 Alamofire Software Foundation (http://alamofire.org/)
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

final class RedirectHandlerTestCase: BaseTestCase {
    // MARK: - Properties

    private var redirectURLString: String { "https://www.apple.com/" }
    private var urlString: String { "https://httpbin.org/redirect-to?url=\(redirectURLString)" }

    // MARK: - Tests - Per Request

    func testThatRequestRedirectHandlerCanFollowRedirects() {
        // Given
        let session = Session()

        var response: DataResponse<Data?, AFError>?
        let expectation = self.expectation(description: "Request should redirect to \(redirectURLString)")

        // When
        session.request(urlString).redirect(using: Redirector.follow).response { resp in
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

    func testThatRequestRedirectHandlerCanNotFollowRedirects() {
        // Given
        let session = Session()

        var response: DataResponse<Data?, AFError>?
        let expectation = self.expectation(description: "Request should NOT redirect to \(redirectURLString)")

        // When
        session.request(urlString).redirect(using: Redirector.doNotFollow).response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNil(response?.data)
        XCTAssertNil(response?.error)

        XCTAssertEqual(response?.response?.url?.absoluteString, urlString)
        XCTAssertEqual(response?.response?.statusCode, 302)
    }

    func testThatRequestRedirectHandlerCanModifyRedirects() {
        // Given
        let session = Session()
        let redirectURLString = "https://www.nike.com"
        let redirectURLRequest = URLRequest(url: URL(string: redirectURLString)!)

        var response: DataResponse<Data?, AFError>?
        let expectation = self.expectation(description: "Request should redirect to \(redirectURLString)")

        // When
        let redirector = Redirector(behavior: .modify { _, _, _ in redirectURLRequest })

        session.request(urlString).redirect(using: redirector).response { resp in
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

    // MARK: - Tests - Per Session

    func testThatSessionRedirectHandlerCanFollowRedirects() {
        // Given
        let session = Session(redirectHandler: Redirector.follow)

        var response: DataResponse<Data?, AFError>?
        let expectation = self.expectation(description: "Request should redirect to \(redirectURLString)")

        // When
        session.request(urlString).response { resp in
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

    func testThatSessionRedirectHandlerCanNotFollowRedirects() {
        // Given
        let session = Session(redirectHandler: Redirector.doNotFollow)

        var response: DataResponse<Data?, AFError>?
        let expectation = self.expectation(description: "Request should NOT redirect to \(redirectURLString)")

        // When
        session.request(urlString).response { resp in
            response = resp
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNil(response?.data)
        XCTAssertNil(response?.error)

        XCTAssertEqual(response?.response?.url?.absoluteString, urlString)
        XCTAssertEqual(response?.response?.statusCode, 302)
    }

    func testThatSessionRedirectHandlerCanModifyRedirects() {
        // Given
        let redirectURLString = "https://www.nike.com"
        let redirectURLRequest = URLRequest(url: URL(string: redirectURLString)!)

        let redirector = Redirector(behavior: .modify { _, _, _ in redirectURLRequest })
        let session = Session(redirectHandler: redirector)

        var response: DataResponse<Data?, AFError>?
        let expectation = self.expectation(description: "Request should redirect to \(redirectURLString)")

        // When
        session.request(urlString).response { resp in
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

    // MARK: - Tests - Per Request Prioritization

    func testThatRequestRedirectHandlerIsPrioritizedOverSessionRedirectHandler() {
        // Given
        let session = Session(redirectHandler: Redirector.doNotFollow)

        var response: DataResponse<Data?, AFError>?
        let expectation = self.expectation(description: "Request should redirect to \(redirectURLString)")

        // When
        session.request(urlString).redirect(using: Redirector.follow).response { resp in
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
}
