//
//  AuthenticationTests.swift
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

import Alamofire
import Foundation
import XCTest

final class BasicAuthenticationTestCase: BaseTestCase {
    func testHTTPBasicAuthenticationFailsWithInvalidCredentials() {
        // Given
        let session = Session()
        let endpoint = Endpoint.basicAuth()
        let expectation = expectation(description: "\(endpoint.url) 401")

        var response: DataResponse<Data?, AFError>?

        // When
        session.request(endpoint)
            .authenticate(username: "invalid", password: "credentials")
            .response { resp in
                response = resp
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertEqual(response?.response?.statusCode, 401)
        XCTAssertNil(response?.data)
        XCTAssertNil(response?.error)
    }

    func testHTTPBasicAuthenticationWithValidCredentials() {
        // Given
        let session = Session()
        let user = "user1", password = "password"
        let endpoint = Endpoint.basicAuth(forUser: user, password: password)
        let expectation = expectation(description: "\(endpoint.url) 200")

        var response: DataResponse<Data?, AFError>?

        // When
        session.request(endpoint)
            .authenticate(username: user, password: password)
            .response { resp in
                response = resp
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertEqual(response?.response?.statusCode, 200)
        XCTAssertNotNil(response?.data)
        XCTAssertNil(response?.error)
    }

    func testHTTPBasicAuthenticationWithStoredCredentials() {
        // Given
        let session = Session()
        let user = "user2", password = "password"
        let endpoint = Endpoint.basicAuth(forUser: user, password: password)
        let expectation = expectation(description: "\(endpoint.url) 200")

        var response: DataResponse<Data?, AFError>?

        // When
        let credential = URLCredential(user: user, password: password, persistence: .forSession)
        URLCredentialStorage.shared.setDefaultCredential(credential,
                                                         for: .init(host: endpoint.host.rawValue,
                                                                    port: endpoint.port,
                                                                    protocol: endpoint.scheme.rawValue,
                                                                    realm: endpoint.host.rawValue,
                                                                    authenticationMethod: NSURLAuthenticationMethodHTTPBasic))
        session.request(endpoint)
            .response { resp in
                response = resp
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertEqual(response?.response?.statusCode, 200)
        XCTAssertNotNil(response?.data)
        XCTAssertNil(response?.error)
    }

    func testHiddenHTTPBasicAuthentication() {
        // Given
        let session = Session()
        let endpoint = Endpoint.hiddenBasicAuth()
        let expectation = expectation(description: "\(endpoint.url) 200")

        var response: DataResponse<Data?, AFError>?

        // When
        session.request(endpoint)
            .response { resp in
                response = resp
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertEqual(response?.response?.statusCode, 200)
        XCTAssertNotNil(response?.data)
        XCTAssertNil(response?.error)
    }
}

// MARK: -

// Disabled due to HTTPBin flakiness.
final class HTTPDigestAuthenticationTestCase: BaseTestCase {
    func _testHTTPDigestAuthenticationWithInvalidCredentials() {
        // Given
        let session = Session()
        let endpoint = Endpoint.digestAuth()
        let expectation = expectation(description: "\(endpoint.url) 401")

        var response: DataResponse<Data?, AFError>?

        // When
        session.request(endpoint)
            .authenticate(username: "invalid", password: "credentials")
            .response { resp in
                response = resp
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertEqual(response?.response?.statusCode, 401)
        XCTAssertNil(response?.data)
        XCTAssertNil(response?.error)
    }

    func _testHTTPDigestAuthenticationWithValidCredentials() {
        // Given
        let session = Session()
        let user = "user", password = "password"
        let endpoint = Endpoint.digestAuth(forUser: user, password: password)
        let expectation = expectation(description: "\(endpoint.url) 200")

        var response: DataResponse<Data?, AFError>?

        // When
        session.request(endpoint)
            .authenticate(username: user, password: password)
            .response { resp in
                response = resp
                expectation.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(response?.request)
        XCTAssertNotNil(response?.response)
        XCTAssertEqual(response?.response?.statusCode, 200)
        XCTAssertNotNil(response?.data)
        XCTAssertNil(response?.error)
    }
}
