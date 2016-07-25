//
//  SessionDelegateTests.swift
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

@testable import Alamofire
import Foundation
import XCTest

class SessionDelegateTestCase: BaseTestCase {
    var manager: Alamofire.Manager!

    // MARK: - Setup and Teardown

    override func setUp() {
        super.setUp()
        manager = Alamofire.Manager(configuration: .ephemeral)
    }

    // MARK: - Tests - Session Invalidation

    func testThatSessionDidBecomeInvalidWithErrorClosureIsCalledWhenSet() {
        // Given
        let expectation = self.expectation(description: "Override closure should be called")

        var overrideClosureCalled = false
        var invalidationError: NSError?

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
        // Given
        let expectation = self.expectation(description: "Override closure should be called")

        var overrideClosureCalled = false
        var response: HTTPURLResponse?

        manager.delegate.sessionDidReceiveChallenge = { session, challenge in
            overrideClosureCalled = true
            return (.performDefaultHandling, nil)
        }

        // When
        manager.request(.GET, "https://httpbin.org/get").responseJSON { closureResponse in
            response = closureResponse.response
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertTrue(overrideClosureCalled)
        XCTAssertEqual(response?.statusCode, 200)
    }

    func testThatSessionDidReceiveChallengeWithCompletionClosureIsCalledWhenSet() {
        // Given
        let expectation = self.expectation(description: "Override closure should be called")

        var overrideClosureCalled = false
        var response: HTTPURLResponse?

        manager.delegate.sessionDidReceiveChallengeWithCompletion = { session, challenge, completion in
            overrideClosureCalled = true
            completion(.performDefaultHandling, nil)
        }

        // When
        manager.request(.GET, "https://httpbin.org/get").responseJSON { closureResponse in
            response = closureResponse.response
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertTrue(overrideClosureCalled)
        XCTAssertEqual(response?.statusCode, 200)
    }

    // MARK: - Tests - Redirects

    func testThatRequestWillPerformHTTPRedirectionByDefault() {
        // Given
        let redirectURLString = "https://www.apple.com/"
        let URLString = "https://httpbin.org/redirect-to?url=\(redirectURLString)"

        let expectation = self.expectation(description: "Request should redirect to \(redirectURLString)")

        var request: Foundation.URLRequest?
        var response: HTTPURLResponse?
        var data: Data?
        var error: NSError?

        // When
        manager.request(.GET, URLString)
            .response { responseRequest, responseResponse, responseData, responseError in
                request = responseRequest
                response = responseResponse
                data = responseData
                error = responseError

                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertNotNil(data, "data should not be nil")
        XCTAssertNil(error, "error should be nil")
        XCTAssertEqual(response?.url?.urlString ?? "", redirectURLString, "response URL should match the redirect URL")
        XCTAssertEqual(response?.statusCode ?? -1, 200, "response should have a 200 status code")
    }

    func testThatRequestWillPerformRedirectionMultipleTimesByDefault() {
        // Given
        let redirectURLString = "https://httpbin.org/get"
        let URLString = "https://httpbin.org/redirect/5"

        let expectation = self.expectation(description: "Request should redirect to \(redirectURLString)")

        var request: Foundation.URLRequest?
        var response: HTTPURLResponse?
        var data: Data?
        var error: NSError?

        // When
        manager.request(.GET, URLString)
            .response { responseRequest, responseResponse, responseData, responseError in
                request = responseRequest
                response = responseResponse
                data = responseData
                error = responseError

                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertNotNil(data, "data should not be nil")
        XCTAssertNil(error, "error should be nil")

        XCTAssertEqual(response?.url?.urlString ?? "", redirectURLString, "response URL should match the redirect URL")
        XCTAssertEqual(response?.statusCode ?? -1, 200, "response should have a 200 status code")
    }

    func testThatTaskOverrideClosureCanPerformHTTPRedirection() {
        // Given
        let redirectURLString = "https://www.apple.com/"
        let URLString = "https://httpbin.org/redirect-to?url=\(redirectURLString)"

        let expectation = self.expectation(description: "Request should redirect to \(redirectURLString)")
        let callbackExpectation = self.expectation(description: "Redirect callback should be made")
        let delegate: Alamofire.Manager.SessionDelegate = manager.delegate

        delegate.taskWillPerformHTTPRedirection = { _, _, _, request in
            callbackExpectation.fulfill()
            return request
        }

        var request: Foundation.URLRequest?
        var response: HTTPURLResponse?
        var data: Data?
        var error: NSError?

        // When
        manager.request(.GET, URLString)
            .response { responseRequest, responseResponse, responseData, responseError in
                request = responseRequest
                response = responseResponse
                data = responseData
                error = responseError

                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertNotNil(data, "data should not be nil")
        XCTAssertNil(error, "error should be nil")
        XCTAssertEqual(response?.url?.urlString ?? "", redirectURLString, "response URL should match the redirect URL")
        XCTAssertEqual(response?.statusCode ?? -1, 200, "response should have a 200 status code")
    }

    func testThatTaskOverrideClosureWithCompletionCanPerformHTTPRedirection() {
        // Given
        let redirectURLString = "https://www.apple.com/"
        let URLString = "https://httpbin.org/redirect-to?url=\(redirectURLString)"

        let expectation = self.expectation(description: "Request should redirect to \(redirectURLString)")
        let callbackExpectation = self.expectation(description: "Redirect callback should be made")
        let delegate: Alamofire.Manager.SessionDelegate = manager.delegate

        delegate.taskWillPerformHTTPRedirectionWithCompletion = { _, _, _, request, completion in
            completion(request)
            callbackExpectation.fulfill()
        }

        var request: Foundation.URLRequest?
        var response: HTTPURLResponse?
        var data: Data?
        var error: NSError?

        // When
        manager.request(.GET, URLString)
            .response { responseRequest, responseResponse, responseData, responseError in
                request = responseRequest
                response = responseResponse
                data = responseData
                error = responseError

                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertNotNil(data, "data should not be nil")
        XCTAssertNil(error, "error should be nil")

        XCTAssertEqual(response?.url?.urlString ?? "", redirectURLString, "response URL should match the redirect URL")
        XCTAssertEqual(response?.statusCode ?? -1, 200, "response should have a 200 status code")
    }

    func testThatTaskOverrideClosureCanCancelHTTPRedirection() {
        // Given
        let redirectURLString = "https://www.apple.com"
        let URLString = "https://httpbin.org/redirect-to?url=\(redirectURLString)"

        let expectation = self.expectation(description: "Request should not redirect to \(redirectURLString)")
        let callbackExpectation = self.expectation(description: "Redirect callback should be made")
        let delegate: Alamofire.Manager.SessionDelegate = manager.delegate

        delegate.taskWillPerformHTTPRedirectionWithCompletion = { _, _, _, _, completion in
            callbackExpectation.fulfill()
            completion(nil)
        }

        var request: Foundation.URLRequest?
        var response: HTTPURLResponse?
        var data: Data?
        var error: NSError?

        // When
        manager.request(.GET, URLString)
            .response { responseRequest, responseResponse, responseData, responseError in
                request = responseRequest
                response = responseResponse
                data = responseData
                error = responseError

                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertNotNil(data, "data should not be nil")
        XCTAssertNil(error, "error should be nil")

        XCTAssertEqual(response?.url?.urlString ?? "", URLString, "response URL should match the origin URL")
        XCTAssertEqual(response?.statusCode ?? -1, 302, "response should have a 302 status code")
    }

    func testThatTaskOverrideClosureWithCompletionCanCancelHTTPRedirection() {
        // Given
        let redirectURLString = "https://www.apple.com"
        let URLString = "https://httpbin.org/redirect-to?url=\(redirectURLString)"

        let expectation = self.expectation(description: "Request should not redirect to \(redirectURLString)")
        let callbackExpectation = self.expectation(description: "Redirect callback should be made")
        let delegate: Alamofire.Manager.SessionDelegate = manager.delegate

        delegate.taskWillPerformHTTPRedirection = { _, _, _, _ in
            callbackExpectation.fulfill()
            return nil
        }

        var request: Foundation.URLRequest?
        var response: HTTPURLResponse?
        var data: Data?
        var error: NSError?

        // When
        manager.request(.GET, URLString)
            .response { responseRequest, responseResponse, responseData, responseError in
                request = responseRequest
                response = responseResponse
                data = responseData
                error = responseError

                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertNotNil(data, "data should not be nil")
        XCTAssertNil(error, "error should be nil")

        XCTAssertEqual(response?.url?.urlString ?? "", URLString, "response URL should match the origin URL")
        XCTAssertEqual(response?.statusCode ?? -1, 302, "response should have a 302 status code")
    }

    func testThatTaskOverrideClosureIsCalledMultipleTimesForMultipleHTTPRedirects() {
        // Given
        let redirectCount = 5
        let redirectURLString = "https://httpbin.org/get"
        let URLString = "https://httpbin.org/redirect/\(redirectCount)"

        let expectation = self.expectation(description: "Request should redirect to \(redirectURLString)")
        let delegate: Alamofire.Manager.SessionDelegate = manager.delegate
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

        var request: Foundation.URLRequest?
        var response: HTTPURLResponse?
        var data: Data?
        var error: NSError?

        // When
        manager.request(.GET, URLString)
            .response { responseRequest, responseResponse, responseData, responseError in
                request = responseRequest
                response = responseResponse
                data = responseData
                error = responseError

                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertNotNil(data, "data should not be nil")
        XCTAssertNil(error, "error should be nil")

        XCTAssertEqual(response?.url?.urlString ?? "", redirectURLString, "response URL should match the redirect URL")
        XCTAssertEqual(response?.statusCode ?? -1, 200, "response should have a 200 status code")
    }

    func testThatTaskOverrideClosureWithCompletionIsCalledMultipleTimesForMultipleHTTPRedirects() {
        // Given
        let redirectCount = 5
        let redirectURLString = "https://httpbin.org/get"
        let URLString = "https://httpbin.org/redirect/\(redirectCount)"

        let expectation = self.expectation(description: "Request should redirect to \(redirectURLString)")
        let delegate: Alamofire.Manager.SessionDelegate = manager.delegate

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

        var request: Foundation.URLRequest?
        var response: HTTPURLResponse?
        var data: Data?
        var error: NSError?

        // When
        manager.request(.GET, URLString)
            .response { responseRequest, responseResponse, responseData, responseError in
                request = responseRequest
                response = responseResponse
                data = responseData
                error = responseError

                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertNotNil(data, "data should not be nil")
        XCTAssertNil(error, "error should be nil")

        XCTAssertEqual(response?.url?.urlString ?? "", redirectURLString, "response URL should match the redirect URL")
        XCTAssertEqual(response?.statusCode ?? -1, 200, "response should have a 200 status code")
    }

    func testThatRedirectedRequestContainsAllHeadersFromOriginalRequest() {
        // Given
        let redirectURLString = "https://httpbin.org/get"
        let URLString = "https://httpbin.org/redirect-to?url=\(redirectURLString)"
        let headers = [
            "Authorization": "1234",
            "Custom-Header": "foobar",
            ]

        // NOTE: It appears that most headers are maintained during a redirect with the exception of the `Authorization`
        // header. It appears that Apple's strips the `Authorization` header from the redirected URL request. If you
        // need to maintain the `Authorization` header, you need to manually append it to the redirected request.

        manager.delegate.taskWillPerformHTTPRedirection = { session, task, response, request in
            var redirectedRequest = request

            if let originalRequest = task.originalRequest,
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

        var response: Response<AnyObject, NSError>?

        // When
        manager.request(.GET, URLString, headers: headers)
            .responseJSON { closureResponse in
                response = closureResponse
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertNotNil(response?.request, "request should not be nil")
        XCTAssertNotNil(response?.response, "response should not be nil")
        XCTAssertNotNil(response?.data, "data should not be nil")
        XCTAssertTrue(response?.result.isSuccess ?? false, "response result should be a success")

        if let json = response?.result.value as? [String: AnyObject], let headers = json["headers"] as? [String: String] {
            XCTAssertEqual(headers["Custom-Header"], "foobar", "Custom-Header should be equal to foobar")
            XCTAssertEqual(headers["Authorization"], "1234", "Authorization header should be equal to 1234")
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
        manager.request(.GET, "https://httpbin.org/get").responseJSON { closureResponse in
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
        manager.request(.GET, "https://httpbin.org/get").responseJSON { closureResponse in
            response = closureResponse.response
            expectation.fulfill()
        }

        waitForExpectations(timeout: timeout, handler: nil)

        // Then
        XCTAssertTrue(overrideClosureCalled)
        XCTAssertEqual(response?.statusCode, 200)
    }
}
