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
import Foundation
import Testing

@Suite(.storesInstances)
struct RequestModifierTests {
    // MARK: - DataRequest

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataRequestsCanHaveCustomTimeoutValueSet() async {
        // Given
        let session = stored(Session.independent())
        let completed = Completion("request completed")
        let modified = Completion("request should be modified")
        let response = Capture<AFDataResponse<Data?>?>()

        // When
        session.request(.delay(1)) { $0.timeoutInterval = 0.001; modified.complete() }
            .response { response.value = $0; completed.complete() }

        await wait(for: [completed, modified])

        // Then
        #expect((response.error?.underlyingError as? URLError)?.code == .timedOut)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataRequestsCallRequestModifiersOnRetry() async {
        // Given
        let inspector = InspectorInterceptor(RetryPolicy(retryLimit: 1, exponentialBackoffScale: 0))
        let session = stored(Session.independent(interceptor: inspector))
        let completed = Completion("request completed")
        let modified = Completion("request should be modified twice", expectedCount: 2)
        let response = Capture<AFDataResponse<Data?>?>()

        // When
        session.request(.delay(1)) { $0.timeoutInterval = 0.001; modified.complete() }
            .response { response.value = $0; completed.complete() }

        await wait(for: [completed, modified])

        // Then
        #expect((response.error?.underlyingError as? URLError)?.code == .timedOut)
        #expect(inspector.retryCalledCount == 2)
    }

    // MARK: - UploadRequest

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func uploadRequestsCanHaveCustomTimeoutValueSet() async {
        // Given
        let session = stored(Session.independent())
        let endpoint = Endpoint.delay(1).modifying(\.method, to: .post)
        let data = Data("data".utf8)
        let completed = Completion("request completed")
        let modified = Completion("request should be modified")
        let response = Capture<AFDataResponse<Data?>?>()

        // When
        session.upload(data, to: endpoint) { $0.timeoutInterval = 0.001; modified.complete() }
            .response { response.value = $0; completed.complete() }

        await wait(for: [completed, modified])

        // Then
        #expect((response.error?.underlyingError as? URLError)?.code == .timedOut)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func uploadRequestsCallRequestModifiersOnRetry() async {
        // Given
        let endpoint = Endpoint.delay(1).modifying(\.method, to: .post)
        let data = Data("data".utf8)
        let policy = RetryPolicy(retryLimit: 1, exponentialBackoffScale: 0, retryableHTTPMethods: [.post])
        let inspector = InspectorInterceptor(policy)
        let session = stored(Session.independent(interceptor: inspector))
        let completed = Completion("request completed")
        let modified = Completion("request should be modified twice", expectedCount: 2)
        let response = Capture<AFDataResponse<Data?>?>()

        // When
        session.upload(data, to: endpoint) { $0.timeoutInterval = 0.001; modified.complete() }
            .response { response.value = $0; completed.complete() }

        await wait(for: [completed, modified])

        // Then
        #expect((response.error?.underlyingError as? URLError)?.code == .timedOut)
        #expect(inspector.retryCalledCount == 2)
    }

    // MARK: - DownloadRequest

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func downloadRequestsCanHaveCustomTimeoutValueSet() async {
        // Given
        let session = stored(Session.independent())
        let url = Endpoint.delay(1).url
        let completed = Completion("request completed")
        let modified = Completion("request should be modified")
        let response = Capture<AFDownloadResponse<URL?>?>()

        // When
        session.download(url, requestModifier: { $0.timeoutInterval = 0.001; modified.complete() })
            .response { response.value = $0; completed.complete() }

        await wait(for: [completed, modified])

        // Then
        #expect((response.error?.underlyingError as? URLError)?.code == .timedOut)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func downloadRequestsCallRequestModifiersOnRetry() async {
        // Given
        let inspector = InspectorInterceptor(RetryPolicy(retryLimit: 1, exponentialBackoffScale: 0))
        let session = stored(Session.independent(interceptor: inspector))
        let completed = Completion("request completed")
        let modified = Completion("request should be modified twice", expectedCount: 2)
        let response = Capture<AFDownloadResponse<URL?>?>()

        // When
        session.download(.delay(1), requestModifier: { $0.timeoutInterval = 0.001; modified.complete() })
            .response { response.value = $0; completed.complete() }

        await wait(for: [completed, modified])

        // Then
        #expect((response.error?.underlyingError as? URLError)?.code == .timedOut)
        #expect(inspector.retryCalledCount == 2)
    }

    // MARK: - DataStreamRequest

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataStreamRequestsCanHaveCustomTimeoutValueSet() async {
        // Given
        let session = stored(Session.independent())
        let completed = Completion("request completed")
        let modified = Completion("request should be modified")
        let response = Capture<DataStreamRequest.Completion?>()

        // When
        session.streamRequest(.delay(1)) { $0.timeoutInterval = 0.001; modified.complete() }
            .responseStream { stream in
                guard case let .complete(completion) = stream.event else { return }

                response.value = completion
                completed.complete()
            }

        await wait(for: [completed, modified])

        // Then
        #expect((response.error?.underlyingError as? URLError)?.code == .timedOut)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func dataStreamRequestsCallRequestModifiersOnRetry() async {
        // Given
        let inspector = InspectorInterceptor(RetryPolicy(retryLimit: 1, exponentialBackoffScale: 0))
        let session = stored(Session.independent(interceptor: inspector))
        let completed = Completion("request completed")
        let modified = Completion("request should be modified twice", expectedCount: 2)
        let response = Capture<DataStreamRequest.Completion?>()

        // When
        session.streamRequest(.delay(1)) { $0.timeoutInterval = 0.001; modified.complete() }
            .responseStream { stream in
                guard case let .complete(completion) = stream.event else { return }

                response.value = completion
                completed.complete()
            }

        await wait(for: [completed, modified])

        // Then
        #expect((response.error?.underlyingError as? URLError)?.code == .timedOut)
        #expect(inspector.retryCalledCount == 2)
    }
}
