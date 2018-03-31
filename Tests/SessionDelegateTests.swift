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
    var manager: SessionManager!

    // MARK: - Setup and Teardown

    override func setUp() {
        super.setUp()
        manager = SessionManager(configuration: .ephemeral)
    }

    // MARK: - Tests - Session Invalidation

    func testThatSessionDidBecomeInvalidWithErrorClosureIsCalledWhenSet() {
        // Given
        let expectation = self.expectation(description: "Override closure should be called")

        var overrideClosureCalled = false
        var invalidationError: Error?

        manager.delegate.sessionDidBecomeInvalidWithError = { _, error in
            overrideClosureCalled = true
            invalidationError = error

            expectation.fulfill()
        }

        // When
        manager.session.invalidateAndCancel()
        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertTrue(overrideClosureCalled)
        XCTAssertNil(invalidationError)
    }

    // MARK: - Tests - Session Challenges

    func testThatSessionDidReceiveChallengeClosureIsCalledWhenSet() {
        if #available(iOS 9.0, *) {
            // Given
            let expectation = self.expectation(description: "Override closure should be called")

            var overrideClosureCalled = false
            var response: HTTPURLResponse?

            manager.delegate.sessionDidReceiveChallenge = { session, challenge in
                overrideClosureCalled = true
                return (.performDefaultHandling, nil)
            }

            // When
            manager.request("https://httpbin.org/get").responseJSON { closureResponse in
                response = closureResponse.response
                expectation.fulfill()
            }

            waitForExpectations(timeout: timeout, handler: nil)

            // Then
            XCTAssertTrue(overrideClosureCalled)
            XCTAssertEqual(response?.statusCode, 200)
        } else {
            // This test MUST be disabled on iOS 8.x because `respondsToSelector` is not being called for the
            // `URLSession:didReceiveChallenge:completionHandler:` selector when more than one test here is run
            // at a time. Whether we flush the URL session of wipe all the shared credentials, the behavior is
            // still the same. Until we find a better solution, we'll need to disable this test on iOS 8.x.
        }
    }

    func testThatSessionDidReceiveChallengeWithCompletionClosureIsCalledWhenSet() {
        if #available(iOS 9.0, *) {
            // Given
            let expectation = self.expectation(description: "Override closure should be called")

            var overrideClosureCalled = false
            var response: HTTPURLResponse?

            manager.delegate.sessionDidReceiveChallengeWithCompletion = { session, challenge, completion in
                overrideClosureCalled = true
                completion(.performDefaultHandling, nil)
            }

            // When
            manager.request("https://httpbin.org/get").responseJSON { closureResponse in
                response = closureResponse.response
                expectation.fulfill()
            }

            waitForExpectations(timeout: timeout, handler: nil)

            // Then
            XCTAssertTrue(overrideClosureCalled)
            XCTAssertEqual(response?.statusCode, 200)
        } else {
            // This test MUST be disabled on iOS 8.x because `respondsToSelector` is not being called for the
            // `URLSession:didReceiveChallenge:completionHandler:` selector when more than one test here is run
            // at a time. Whether we flush the URL session of wipe all the shared credentials, the behavior is
            // still the same. Until we find a better solution, we'll need to disable this test on iOS 8.x.
        }
    }

    // MARK: - Tests - Redirects

    func testThatRequestWillPerformHTTPRedirectionByDefault() {
        // Given
        let redirectURLString = "https://www.apple.com/"
        let urlString = "https://httpbin.org/redirect-to?url=\(redirectURLString)"

        let expectation = self.expectation(description: "Request should redirect to \(redirectURLString)")

        var response: DefaultDataResponse?

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

        var response: DefaultDataResponse?

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

    func testThatTaskOverrideClosureCanPerformHTTPRedirection() {
        // Given
        let redirectURLString = "https://www.apple.com/"
        let urlString = "https://httpbin.org/redirect-to?url=\(redirectURLString)"

        let expectation = self.expectation(description: "Request should redirect to \(redirectURLString)")
        let callbackExpectation = self.expectation(description: "Redirect callback should be made")
        let delegate: SessionDelegate = manager.delegate

        delegate.taskWillPerformHTTPRedirection = { _, _, _, request in
            callbackExpectation.fulfill()
            return request
        }

        var response: DefaultDataResponse?

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

    func testThatTaskOverrideClosureWithCompletionCanPerformHTTPRedirection() {
        // Given
        let redirectURLString = "https://www.apple.com/"
        let urlString = "https://httpbin.org/redirect-to?url=\(redirectURLString)"

        let expectation = self.expectation(description: "Request should redirect to \(redirectURLString)")
        let callbackExpectation = self.expectation(description: "Redirect callback should be made")
        let delegate: SessionDelegate = manager.delegate

        delegate.taskWillPerformHTTPRedirectionWithCompletion = { _, _, _, request, completion in
            completion(request)
            callbackExpectation.fulfill()
        }

        var response: DefaultDataResponse?

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

    func testThatTaskOverrideClosureCanCancelHTTPRedirection() {
        // Given
        let redirectURLString = "https://www.apple.com"
        let urlString = "https://httpbin.org/redirect-to?url=\(redirectURLString)"

        let expectation = self.expectation(description: "Request should not redirect to \(redirectURLString)")
        let callbackExpectation = self.expectation(description: "Redirect callback should be made")
        let delegate: SessionDelegate = manager.delegate

        delegate.taskWillPerformHTTPRedirectionWithCompletion = { _, _, _, _, completion in
            callbackExpectation.fulfill()
            completion(nil)
        }

        var response: DefaultDataResponse?

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

        XCTAssertEqual(response?.response?.url?.absoluteString, urlString)
        XCTAssertEqual(response?.response?.statusCode, 302)
    }

    func testThatTaskOverrideClosureWithCompletionCanCancelHTTPRedirection() {
        // Given
        let redirectURLString = "https://www.apple.com"
        let urlString = "https://httpbin.org/redirect-to?url=\(redirectURLString)"

        let expectation = self.expectation(description: "Request should not redirect to \(redirectURLString)")
        let callbackExpectation = self.expectation(description: "Redirect callback should be made")
        let delegate: SessionDelegate = manager.delegate

        delegate.taskWillPerformHTTPRedirection = { _, _, _, _ in
            callbackExpectation.fulfill()
            return nil
        }

        var response: DefaultDataResponse?

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

        XCTAssertEqual(response?.response?.url?.absoluteString, urlString)
        XCTAssertEqual(response?.response?.statusCode, 302)
    }

    func testThatTaskOverrideClosureIsCalledMultipleTimesForMultipleHTTPRedirects() {
        // Given
        let redirectCount = 5
        let redirectURLString = "https://httpbin.org/get"
        let urlString = "https://httpbin.org/redirect/\(redirectCount)"

        let expectation = self.expectation(description: "Request should redirect to \(redirectURLString)")
        let delegate: SessionDelegate = manager.delegate
        var redirectExpectations = [XCTestExpectation]()
        for index in 0..<redirectCount {
            redirectExpectations.insert(self.expectation(description: "Redirect #\(index) callback was received"), at: 0)
        }

        delegate.taskWillPerformHTTPRedirection = { _, _, _, request in
            if let redirectExpectation = redirectExpectations.popLast() {
                redirectExpectation.fulfill()
            } else {
                XCTFail("Too many redirect callbacks were received")
            }

            return request
        }

        var response: DefaultDataResponse?

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

    func testThatTaskOverrideClosureWithCompletionIsCalledMultipleTimesForMultipleHTTPRedirects() {
        // Given
        let redirectCount = 5
        let redirectURLString = "https://httpbin.org/get"
        let urlString = "https://httpbin.org/redirect/\(redirectCount)"

        let expectation = self.expectation(description: "Request should redirect to \(redirectURLString)")
        let delegate: SessionDelegate = manager.delegate

        var redirectExpectations = [XCTestExpectation]()

        for index in 0..<redirectCount {
            redirectExpectations.insert(self.expectation(description: "Redirect #\(index) callback was received"), at: 0)
        }

        delegate.taskWillPerformHTTPRedirectionWithCompletion = { _, _, _, request, completion in
            if let redirectExpectation = redirectExpectations.popLast() {
                redirectExpectation.fulfill()
            } else {
                XCTFail("Too many redirect callbacks were received")
            }

            completion(request)
        }

        var response: DefaultDataResponse?

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

    func testThatRedirectedRequestContainsAllHeadersFromOriginalRequest() {
        // Given
        let redirectURLString = "https://httpbin.org/get"
        let urlString = "https://httpbin.org/redirect-to?url=\(redirectURLString)"
        let headers = [
            "Authorization": "1234",
            "Custom-Header": "foobar",
        ]

        // NOTE: It appears that most headers are maintained during a redirect with the exception of the `Authorization`
        // header. It appears that Apple's strips the `Authorization` header from the redirected URL request. If you
        // need to maintain the `Authorization` header, you need to manually append it to the redirected request.

        manager.delegate.taskWillPerformHTTPRedirection = { session, task, response, request in
            var redirectedRequest = request

            if
                let originalRequest = task.originalRequest,
                let headers = originalRequest.allHTTPHeaderFields,
                let authorizationHeaderValue = headers["Authorization"]
            {
                var mutableRequest = request
                mutableRequest.setValue(authorizationHeaderValue, forHTTPHeaderField: "Authorization")
                redirectedRequest = mutableRequest
            }

            return redirectedRequest
        }

        let expectation = self.expectation(description: "Request should redirect to \(redirectURLString)")

        var response: DataResponse<Any>?

        // When
        manager.request(urlString, headers: headers)
            .responseJSON { closureResponse in
                response = closureResponse
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertNotNil(response?.data)
        XCTAssertEqual(response?.result.isSuccess, true)

        if let json = response?.result.value as? [String: Any], let headers = json["headers"] as? [String: String] {
            XCTAssertEqual(headers["Authorization"], "1234")
            XCTAssertEqual(headers["Custom-Header"], "foobar")
        }
    }

    // MARK: - Tests - Data Task Responses

    func testThatDataTaskDidReceiveResponseClosureIsCalledWhenSet() {
        // Given
        let expectation = self.expectation(description: "Override closure should be called")

        var overrideClosureCalled = false
        var response: HTTPURLResponse?

        manager.delegate.dataTaskDidReceiveResponse = { session, task, response in
            overrideClosureCalled = true
            return .allow
        }

        // When
        manager.request("https://httpbin.org/get").responseJSON { closureResponse in
            response = closureResponse.response
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertTrue(overrideClosureCalled)
        XCTAssertEqual(response?.statusCode, 200)
    }

    func testThatDataTaskDidReceiveResponseWithCompletionClosureIsCalledWhenSet() {
        // Given
        let expectation = self.expectation(description: "Override closure should be called")

        var overrideClosureCalled = false
        var response: HTTPURLResponse?

        manager.delegate.dataTaskDidReceiveResponseWithCompletion = { session, task, response, completion in
            overrideClosureCalled = true
            completion(.allow)
        }

        // When
        manager.request("https://httpbin.org/get").responseJSON { closureResponse in
            response = closureResponse.response
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertTrue(overrideClosureCalled)
        XCTAssertEqual(response?.statusCode, 200)
    }

    func testThatDidCompleteNotificationIsCalledWithResponseDataForDataTasks() {
        // Given
        var notificationCalledWithResponseData = false
        var response: HTTPURLResponse?
        #if swift(>=4.1)
        let notification = Notification.Name.Task.DidComplete
        #else
        let notification = Notification.Name.Task.DidComplete.rawValue
        #endif
        let expectation = self.expectation(forNotification: notification, object: nil) { notif -> Bool in

            // check that we are handling notif for a dataTask
            guard let task = notif.userInfo?[Notification.Key.Task] as? URLSessionDataTask else {
                return false
            }

            response = task.response as? HTTPURLResponse

            // check that responseData are set in userInfo-dict and it's not empty
            if let responseData = notif.userInfo?[Notification.Key.ResponseData] as? Data {
                notificationCalledWithResponseData = responseData.count > 0
            }

            return notificationCalledWithResponseData
        }

        // When
        manager.request("https://httpbin.org/get").responseJSON { resp in }

        wait(for: [expectation], timeout: timeout)

        // Then
        XCTAssertTrue(notificationCalledWithResponseData)
        XCTAssertEqual(response?.statusCode, 200)
    }

    func testThatDidCompleteNotificationIsntCalledForDownloadTasks() {
        // Given
        var notificationCalledWithNilResponseData = false
        var response: HTTPURLResponse?
        #if swift(>=4.1)
        let notification = Notification.Name.Task.DidComplete
        #else
        let notification = Notification.Name.Task.DidComplete.rawValue
        #endif
        let expectation = self.expectation(forNotification: notification, object: nil) { notif -> Bool in

            // check that we are handling notif for a downloadTask
            guard let task = notif.userInfo?[Notification.Key.Task] as? URLSessionDownloadTask else {
                return false
            }

            response = task.response as? HTTPURLResponse

            // check that responseData are NOT set in userInfo-dict
            notificationCalledWithNilResponseData = notif.userInfo?[Notification.Key.ResponseData] == nil
            return notificationCalledWithNilResponseData
        }

        // When
        manager.download("https://httpbin.org/get").response { resp in }

        wait(for: [expectation], timeout: timeout)

        // Then
        XCTAssertTrue(notificationCalledWithNilResponseData)
        XCTAssertEqual(response?.statusCode, 200)
    }
}
