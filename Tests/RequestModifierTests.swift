//
//  RequestModifierTests.swift
//
//  Copyright (c) 2020 Alamofire Software Foundation (http://alamofire.org/)
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
import XCTest

final class RequestModifierTests: BaseTestCase {
    // MARK: - DataRequest

    func testThatDataRequestsCanHaveCustomTimeoutValueSet() {
        // Given
        let completed = expectation(description: "request completed")
        let modified = expectation(description: "request should be modified")
        var response: AFDataResponse<Data?>?

        // When
        AF.request(.delay(1)) { $0.timeoutInterval = 0.01; modified.fulfill() }
            .response { response = $0; completed.fulfill() }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual((response?.error?.underlyingError as? URLError)?.code, .timedOut)
    }

    func testThatDataRequestsCallRequestModifiersOnRetry() {
        // Given
        let inspector = InspectorInterceptor(RetryPolicy(retryLimit: 1, exponentialBackoffScale: 0))
        let session = Session(interceptor: inspector)
        let completed = expectation(description: "request completed")
        let modified = expectation(description: "request should be modified twice")
        modified.expectedFulfillmentCount = 2
        var response: AFDataResponse<Data?>?

        // When
        session.request(.delay(1)) { $0.timeoutInterval = 0.01; modified.fulfill() }
            .response { response = $0; completed.fulfill() }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual((response?.error?.underlyingError as? URLError)?.code, .timedOut)
        XCTAssertEqual(inspector.retryCalledCount, 2)
    }

    // MARK: - UploadRequest

    func testThatUploadRequestsCanHaveCustomTimeoutValueSet() {
        // Given
        let endpoint = Endpoint.delay(1).modifying(\.method, to: .post)
        let data = Data("data".utf8)
        let completed = expectation(description: "request completed")
        let modified = expectation(description: "request should be modified")
        var response: AFDataResponse<Data?>?

        // When
        AF.upload(data, to: endpoint) { $0.timeoutInterval = 0.01; modified.fulfill() }
            .response { response = $0; completed.fulfill() }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual((response?.error?.underlyingError as? URLError)?.code, .timedOut)
    }

    func testThatUploadRequestsCallRequestModifiersOnRetry() {
        // Given
        let endpoint = Endpoint.delay(1).modifying(\.method, to: .post)
        let data = Data("data".utf8)
        let policy = RetryPolicy(retryLimit: 1, exponentialBackoffScale: 0, retryableHTTPMethods: [.post])
        let inspector = InspectorInterceptor(policy)
        let session = Session(interceptor: inspector)
        let completed = expectation(description: "request completed")
        let modified = expectation(description: "request should be modified twice")
        modified.expectedFulfillmentCount = 2
        var response: AFDataResponse<Data?>?

        // When
        session.upload(data, to: endpoint) { $0.timeoutInterval = 0.01; modified.fulfill() }
            .response { response = $0; completed.fulfill() }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual((response?.error?.underlyingError as? URLError)?.code, .timedOut)
        XCTAssertEqual(inspector.retryCalledCount, 2)
    }

    // MARK: - DownloadRequest

    func testThatDownloadRequestsCanHaveCustomTimeoutValueSet() {
        // Given
        let url = Endpoint.delay(1).url
        let completed = expectation(description: "request completed")
        let modified = expectation(description: "request should be modified")
        var response: AFDownloadResponse<URL?>?

        // When
        AF.download(url, requestModifier: { $0.timeoutInterval = 0.01; modified.fulfill() })
            .response { response = $0; completed.fulfill() }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual((response?.error?.underlyingError as? URLError)?.code, .timedOut)
    }

    func testThatDownloadRequestsCallRequestModifiersOnRetry() {
        // Given
        let inspector = InspectorInterceptor(RetryPolicy(retryLimit: 1, exponentialBackoffScale: 0))
        let session = Session(interceptor: inspector)
        let completed = expectation(description: "request completed")
        let modified = expectation(description: "request should be modified twice")
        modified.expectedFulfillmentCount = 2
        var response: AFDownloadResponse<URL?>?

        // When
        session.download(.delay(1), requestModifier: { $0.timeoutInterval = 0.01; modified.fulfill() })
            .response { response = $0; completed.fulfill() }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual((response?.error?.underlyingError as? URLError)?.code, .timedOut)
        XCTAssertEqual(inspector.retryCalledCount, 2)
    }

    // MARK: - DataStreamRequest

    func testThatDataStreamRequestsCanHaveCustomTimeoutValueSet() {
        // Given
        let completed = expectation(description: "request completed")
        let modified = expectation(description: "request should be modified")
        var response: DataStreamRequest.Completion?

        // When
        AF.streamRequest(.delay(1)) { $0.timeoutInterval = 0.01; modified.fulfill() }
            .responseStream { stream in
                guard case let .complete(completion) = stream.event else { return }

                response = completion
                completed.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual((response?.error?.underlyingError as? URLError)?.code, .timedOut)
    }

    func testThatDataStreamRequestsCallRequestModifiersOnRetry() {
        // Given
        let inspector = InspectorInterceptor(RetryPolicy(retryLimit: 1, exponentialBackoffScale: 0))
        let session = Session(interceptor: inspector)
        let completed = expectation(description: "request completed")
        let modified = expectation(description: "request should be modified twice")
        modified.expectedFulfillmentCount = 2
        var response: DataStreamRequest.Completion?

        // When
        session.streamRequest(.delay(1)) { $0.timeoutInterval = 0.01; modified.fulfill() }
            .responseStream { stream in
                guard case let .complete(completion) = stream.event else { return }

                response = completion
                completed.fulfill()
            }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertEqual((response?.error?.underlyingError as? URLError)?.code, .timedOut)
        XCTAssertEqual(inspector.retryCalledCount, 2)
    }
}
