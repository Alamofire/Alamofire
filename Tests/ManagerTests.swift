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

@testable import Alamofire
import Foundation
import XCTest

class ManagerTestCase: BaseTestCase {

    // MARK: Initialization Tests

    func testInitializerWithDefaultArguments() {
        // Given, When
        let manager = Manager()

        // Then
        XCTAssertNotNil(manager.session.delegate, "session delegate should not be nil")
        XCTAssertTrue(manager.delegate === manager.session.delegate, "manager delegate should equal session delegate")
        XCTAssertNil(manager.session.serverTrustPolicyManager, "session server trust policy manager should be nil")
    }

    func testInitializerWithSpecifiedArguments() {
        // Given
        let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
        let delegate = Manager.SessionDelegate()
        let serverTrustPolicyManager = ServerTrustPolicyManager(policies: [:])

        // When
        let manager = Manager(
            configuration: configuration,
            delegate: delegate,
            serverTrustPolicyManager: serverTrustPolicyManager
        )

        // Then
        XCTAssertNotNil(manager.session.delegate, "session delegate should not be nil")
        XCTAssertTrue(manager.delegate === manager.session.delegate, "manager delegate should equal session delegate")
        XCTAssertNotNil(manager.session.serverTrustPolicyManager, "session server trust policy manager should not be nil")
    }

    func testThatFailableInitializerSucceedsWithDefaultArguments() {
        // Given
        let delegate = Manager.SessionDelegate()
        let session: NSURLSession = {
            let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
            return NSURLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        }()

        // When
        let manager = Manager(session: session, delegate: delegate)

        // Then
        if let manager = manager {
            XCTAssertTrue(manager.delegate === manager.session.delegate, "manager delegate should equal session delegate")
            XCTAssertNil(manager.session.serverTrustPolicyManager, "session server trust policy manager should be nil")
        } else {
            XCTFail("manager should not be nil")
        }
    }

    func testThatFailableInitializerSucceedsWithSpecifiedArguments() {
        // Given
        let delegate = Manager.SessionDelegate()
        let session: NSURLSession = {
            let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
            return NSURLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        }()

        let serverTrustPolicyManager = ServerTrustPolicyManager(policies: [:])

        // When
        let manager = Manager(session: session, delegate: delegate, serverTrustPolicyManager: serverTrustPolicyManager)

        // Then
        if let manager = manager {
            XCTAssertTrue(manager.delegate === manager.session.delegate, "manager delegate should equal session delegate")
            XCTAssertNotNil(manager.session.serverTrustPolicyManager, "session server trust policy manager should not be nil")
        } else {
            XCTFail("manager should not be nil")
        }
    }

    func testThatFailableInitializerFailsWithWhenDelegateDoesNotEqualSessionDelegate() {
        // Given
        let delegate = Manager.SessionDelegate()
        let session: NSURLSession = {
            let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
            return NSURLSession(configuration: configuration, delegate: Manager.SessionDelegate(), delegateQueue: nil)
        }()

        // When
        let manager = Manager(session: session, delegate: delegate)

        // Then
        XCTAssertNil(manager, "manager should be nil")
    }

    func testThatFailableInitializerFailsWhenSessionDelegateIsNil() {
        // Given
        let delegate = Manager.SessionDelegate()
        let session: NSURLSession = {
            let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
            return NSURLSession(configuration: configuration, delegate: nil, delegateQueue: nil)
        }()

        // When
        let manager = Manager(session: session, delegate: delegate)

        // Then
        XCTAssertNil(manager, "manager should be nil")
    }

    // MARK: Start Requests Immediately Tests

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

    // MARK: Deinitialization Tests

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
                    configuration = NSURLSessionConfiguration.backgroundSessionConfigurationForAllPlatformsWithIdentifier(identifier)
                }

                var headers = Alamofire.Manager.defaultHTTPHeaders
                headers["Authorization"] = "Bearer 123456"
                configuration.HTTPAdditionalHeaders = headers

                return configuration
            }()

            return Manager(configuration: configuration)
        }()

        let expectation = expectationWithDescription("request should complete successfully")

        var response: Response<AnyObject, NSError>?

        // When
        manager.request(.GET, "https://httpbin.org/headers")
            .responseJSON { closureResponse in
                response = closureResponse
                expectation.fulfill()
            }

        waitForExpectationsWithTimeout(defaultTimeout, handler: nil)

        // Then
        if let response = response {
            XCTAssertNotNil(response.request, "request should not be nil")
            XCTAssertNotNil(response.response, "response should not be nil")
            XCTAssertNotNil(response.data, "data should not be nil")
            XCTAssertTrue(response.result.isSuccess, "result should be a success")

            if let
                headers = response.result.value?["headers" as NSString] as? [String: String],
                authorization = headers["Authorization"]
            {
                XCTAssertEqual(authorization, "Bearer 123456", "authorization header value does not match")
            } else {
                XCTFail("failed to extract authorization header value")
            }
        } else {
            XCTFail("response should not be nil")
        }
    }
}
