//
//  RequestDeduplicatorTests.swift
//
//  Copyright (c) 2026 Alamofire Software Foundation (http://alamofire.org/)
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
import Testing

@Suite
struct RequestDeduplicatorTests {
    // MARK: - Key Provider

    @Test
    func defaultKeyProviderEncodesMethodAndAbsoluteURL() {
        // Given
        let url = URL(string: "https://api.example.com/feed?page=1")!

        // When
        let getKey = RequestDeduplicator.defaultKeyProvider(url, .get)
        let postKey = RequestDeduplicator.defaultKeyProvider(url, .post)

        // Then: key includes both method and full URL so method changes produce distinct keys.
        #expect(getKey == "GET:https://api.example.com/feed?page=1")
        #expect(postKey == "POST:https://api.example.com/feed?page=1")
        #expect(getKey != postKey)
    }

    // MARK: - Deduplication

    @Test
    func concurrentRequestsForTheSameURLReturnTheSameDataRequest() async {
        // Given
        let session = Session()
        let deduplicator = RequestDeduplicator()

        // When: two calls are made before either request completes.
        let first = deduplicator.request(using: session, .endpoints(.status(200), .get))
        let second = deduplicator.request(using: session, .endpoints(.status(200), .get))

        // Then: both variables point to the same DataRequest object.
        #expect(first === second)

        // Then: the shared request produces a single network task.
        _ = await first.serializingData().result
        #expect(first.tasks.count == 1)
    }

    @Test
    func bothCallersReceiveASuccessfulResponseViaTheSharedRequest() async {
        // Given
        let session = Session()
        let deduplicator = RequestDeduplicator()

        // When
        let first = deduplicator.request(using: session, .endpoints(.status(200), .get))
        let second = deduplicator.request(using: session, .endpoints(.status(200), .get))

        // Then: response handlers attached by each caller both succeed.
        async let firstResult = first.serializingData().result
        async let secondResult = second.serializingData().result
        await #expect(firstResult.isSuccess == true)
        await #expect(secondResult.isSuccess == true)
    }

    @Test
    func requestsForDifferentURLsAreNotDeduplicated() {
        // Given
        let session = Session()
        let deduplicator = RequestDeduplicator()

        // When: two requests target different endpoints.
        let first = deduplicator.request(using: session, .endpoints(.status(200), .get))
        let second = deduplicator.request(using: session, .endpoints(.status(201), .get))

        // Then: distinct DataRequest objects are returned.
        #expect(first !== second)
    }

    @Test
    func requestsWithDifferentHTTPMethodsAreNotDeduplicated() {
        // Given
        let session = Session()
        let deduplicator = RequestDeduplicator()
        let url = URL(string: "https://httpbin.org/anything")!

        // When: same URL, different method.
        let getRequest = deduplicator.request(using: session, url, method: .get)
        let postRequest = deduplicator.request(using: session, url, method: .post)

        // Then: the method is part of the key, so these are independent requests.
        #expect(getRequest !== postRequest)
    }

    @Test
    func inflightEntryIsClearedAfterCompletionAllowingFreshDeduplication() async {
        // Given
        let session = Session()
        let deduplicator = RequestDeduplicator()

        // When: the first request runs to completion.
        // The internal cleanup response handler is registered before the serializingData handler,
        // so the in-flight map entry is guaranteed to be removed before the await below returns.
        let first = deduplicator.request(using: session, .endpoints(.status(200), .get))
        _ = await first.serializingData().result

        // When: a new request is made for the same URL.
        let second = deduplicator.request(using: session, .endpoints(.status(200), .get))

        // Then: the map was cleared, so a distinct DataRequest is created.
        #expect(first !== second)
    }

    // MARK: - Key Provider Customisation

    @Test
    func returningNilFromKeyProviderBypassesDeduplication() {
        // Given
        let session = Session()
        // When: key provider always opts out.
        let deduplicator = RequestDeduplicator { _, _ in nil }

        // When
        let first = deduplicator.request(using: session, .endpoints(.status(200), .get))
        let second = deduplicator.request(using: session, .endpoints(.status(200), .get))

        // Then: each call produces an independent DataRequest.
        #expect(first !== second)
    }

    @Test
    func customKeyProviderCanWidenDeduplicationBoundaryAcrossMethods() {
        // Given
        let session = Session()
        // When: custom key ignores the HTTP method — GET and POST to the same URL share a key.
        let deduplicator = RequestDeduplicator { url, _ in url.absoluteString }
        let url = URL(string: "https://httpbin.org/anything")!

        // When
        let getRequest = deduplicator.request(using: session, url, method: .get)
        let postRequest = deduplicator.request(using: session, url, method: .post)

        // Then: same key → same DataRequest.
        #expect(getRequest === postRequest)
    }

    @Test
    func urlResolutionFailureBypassesDeduplication() {
        // Given
        let session = Session()
        let deduplicator = RequestDeduplicator()

        // When: URLConvertible fails to resolve — deduplication is skipped and Session handles the error.
        let first = deduplicator.request(using: session, ThrowingURL())
        let second = deduplicator.request(using: session, ThrowingURL())

        // Then: each call produces a distinct (failed) DataRequest.
        #expect(first !== second)
    }
}

// MARK: - Helpers

/// A `URLConvertible` that always throws, used to exercise the URL-resolution failure path.
private struct ThrowingURL: URLConvertible {
    private enum TestError: Error { case alwaysThrows }
    func asURL() throws -> URL { throw TestError.alwaysThrows }
}
