// ManagerTests.swift
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

        let URL = NSURL(string: "https://httpbin.org/get")!
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

        waitForExpectationsWithTimeout(defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(response, "response should not be nil")
        XCTAssertTrue(response?.statusCode == 200, "response status code should be 200")
    }

    func testReleasingManagerWithPendingRequestDeinitializesSuccessfully() {
        // Given
        var manager: Manager? = Alamofire.Manager()
        manager?.startRequestsImmediately = false

        let URL = NSURL(string: "https://httpbin.org/get")!
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

        let URL = NSURL(string: "https://httpbin.org/get")!
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

// MARK: -

class ManagerConfigurationHeadersTestCase: BaseTestCase {
    enum ConfigurationType {
        case Default, Ephemeral, Background
    }

    func testThatDefaultConfigurationHeadersAreSentWithRequest() {
        // Given, When, Then
        executeAuthorizationHeaderTestForConfigurationType(.Default)
    }

    func testThatEphemeralConfigurationHeadersAreSentWithRequest() {
        // Given, When, Then
        executeAuthorizationHeaderTestForConfigurationType(.Ephemeral)
    }

    func testThatBackgroundConfigurationHeadersAreSentWithRequest() {
        // Given, When, Then
        executeAuthorizationHeaderTestForConfigurationType(.Background)
    }

    private func executeAuthorizationHeaderTestForConfigurationType(type: ConfigurationType) {
        // Given
        let manager: Manager = {
            let configuration: NSURLSessionConfiguration = {
                let configuration: NSURLSessionConfiguration

                switch type {
                case .Default:
                    configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
                case .Ephemeral:
                    configuration = NSURLSessionConfiguration.ephemeralSessionConfiguration()
                case .Background:
                    let identifier = "com.alamofire.test.manager-configuration-tests"

                    #if os(iOS) || os(watchOS)
                        configuration = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier(identifier)
                    #else
                        if #available(OSX 10.10, *) {
                            configuration = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier(identifier)
                        } else {
                            configuration = NSURLSessionConfiguration.backgroundSessionConfiguration(identifier)
                        }
                    #endif
                }

                var headers = Alamofire.Manager.defaultHTTPHeaders
                headers["Authorization"] = "Bearer 123456"
                configuration.HTTPAdditionalHeaders = headers

                return configuration
            }()

            return Manager(configuration: configuration)
        }()

        let expectation = expectationWithDescription("request should complete successfully")

        var request: NSURLRequest?
        var response: NSHTTPURLResponse?
        var result: Result<AnyObject>?

        // When
        manager.request(.GET, "https://httpbin.org/headers")
            .responseJSON { responseRequest, responseResponse, responseResult in
                request = responseRequest
                response = responseResponse
                result = responseResult

                expectation.fulfill()
            }

        waitForExpectationsWithTimeout(defaultTimeout, handler: nil)

        // Then
        XCTAssertNotNil(request, "request should not be nil")
        XCTAssertNotNil(response, "response should not be nil")

        if let result = result {
            XCTAssertTrue(result.isSuccess, "result should be a success")

            if let
                headers = result.value?["headers" as NSString] as? [String: String],
                authorization = headers["Authorization"]
            {
                XCTAssertEqual(authorization, "Bearer 123456", "authorization header value does not match")
            } else {
                XCTFail("failed to extract authorization header value")
            }
        } else {
            XCTFail("result should not be nil")
        }
    }
}
