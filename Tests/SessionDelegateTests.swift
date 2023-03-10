//
//  SessionDelegateTests.swift
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

@testable import Alamofire
import Foundation
import XCTest

final class SessionDelegateTestCase: BaseTestCase {
    // MARK: - Tests - Redirects

    func testThatRequestWillPerformHTTPRedirectionByDefault() {
        // Given
        let session = Session(configuration: .ephemeral)
        let redirectURLString = Endpoint().url.absoluteString

        let expectation = expectation(description: "Request should redirect to \(redirectURLString)")

        var response: DataResponse<Data?, AFError>?

        // When
        session.request(.redirectTo(redirectURLString))
            .response { resp in
                response = resp
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

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
        let session = Session(configuration: .ephemeral)

        let expectation = expectation(description: "Request should redirect")

        var response: DataResponse<Data?, AFError>?

        // When
        session.request(.redirect(5))
            .response { resp in
                response = resp
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertNil(response?.error)
        XCTAssertEqual(response?.response?.statusCode, 200)
    }

    func testThatRequestWillPerformRedirectionFor307Response() {
        // Given
        let session = Session(configuration: .ephemeral)
        let redirectURLString = Endpoint().url.absoluteString

        let expectation = expectation(description: "Request should redirect to \(redirectURLString)")

        var response: DataResponse<Data?, AFError>?

        // When
        session.request(.redirectTo(redirectURLString, code: 307))
            .response { resp in
                response = resp
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertNil(response?.error)

        XCTAssertEqual(response?.response?.url?.absoluteString, redirectURLString)
        XCTAssertEqual(response?.response?.statusCode, 200)
    }

    // MARK: - Tests - Notification

    func testThatAppropriateNotificationsAreCalledWithRequestForDataRequest() {
        // Given
        let session = Session(startRequestsImmediately: false)
        var resumedRequest: Request?
        var resumedTaskRequest: Request?
        var completedTaskRequest: Request?
        var completedRequest: Request?
        var requestResponse: DataResponse<Data?, AFError>?
        let expect = expectation(description: "request should complete")

        // When
        let request = session.request(.default).response { response in
            requestResponse = response
            expect.fulfill()
        }
        expectation(forNotification: Request.didResumeNotification, object: nil) { notification in
            guard let receivedRequest = notification.request, receivedRequest == request else { return false }

            resumedRequest = notification.request
            return true
        }
        expectation(forNotification: Request.didResumeTaskNotification, object: nil) { notification in
            guard let receivedRequest = notification.request, receivedRequest == request else { return false }

            resumedTaskRequest = notification.request
            return true
        }
        expectation(forNotification: Request.didCompleteTaskNotification, object: nil) { notification in
            guard let receivedRequest = notification.request, receivedRequest == request else { return false }

            completedTaskRequest = notification.request
            return true
        }
        expectation(forNotification: Request.didFinishNotification, object: nil) { notification in
            guard let receivedRequest = notification.request, receivedRequest == request else { return false }

            completedRequest = notification.request
            return true
        }

        request.resume()

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(resumedRequest)
        XCTAssertNotNil(resumedTaskRequest)
        XCTAssertNotNil(completedTaskRequest)
        XCTAssertNotNil(completedRequest)
        XCTAssertEqual(resumedRequest, completedRequest)
        XCTAssertEqual(resumedTaskRequest, completedTaskRequest)
        XCTAssertEqual(requestResponse?.response?.statusCode, 200)
    }

    func testThatDidCompleteNotificationIsCalledWithRequestForDownloadRequests() {
        // Given
        let session = Session(startRequestsImmediately: false)
        var resumedRequest: Request?
        var resumedTaskRequest: Request?
        var completedTaskRequest: Request?
        var completedRequest: Request?
        var requestResponse: DownloadResponse<URL?, AFError>?
        let expect = expectation(description: "request should complete")

        // When
        let request = session.download(.default).response { response in
            requestResponse = response
            expect.fulfill()
        }
        expectation(forNotification: Request.didResumeNotification, object: nil) { notification in
            guard let receivedRequest = notification.request, receivedRequest == request else { return false }

            resumedRequest = notification.request
            return true
        }
        expectation(forNotification: Request.didResumeTaskNotification, object: nil) { notification in
            guard let receivedRequest = notification.request, receivedRequest == request else { return false }

            resumedTaskRequest = notification.request
            return true
        }
        expectation(forNotification: Request.didCompleteTaskNotification, object: nil) { notification in
            guard let receivedRequest = notification.request, receivedRequest == request else { return false }

            completedTaskRequest = notification.request
            return true
        }
        expectation(forNotification: Request.didFinishNotification, object: nil) { notification in
            guard let receivedRequest = notification.request, receivedRequest == request else { return false }

            completedRequest = notification.request
            return true
        }

        request.resume()

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(resumedRequest)
        XCTAssertNotNil(resumedTaskRequest)
        XCTAssertNotNil(completedTaskRequest)
        XCTAssertNotNil(completedRequest)
        XCTAssertEqual(resumedRequest, completedRequest)
        XCTAssertEqual(resumedTaskRequest, completedTaskRequest)
        XCTAssertEqual(requestResponse?.response?.statusCode, 200)
    }
}
