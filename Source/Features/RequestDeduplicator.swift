//
//  RequestDeduplicator.swift
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

import Foundation

/// Coordinates concurrent `DataRequest`s for identical resources to avoid redundant network calls.
///
/// When multiple callers request the same resource simultaneously, `RequestDeduplicator` returns the same underlying
/// `DataRequest` to all of them. Each caller can attach its own response handlers; all handlers are invoked when the
/// single network call completes.
///
/// ```swift
/// let deduplicator = RequestDeduplicator()
///
/// // Only one HTTP request goes over the wire; both handlers receive the same response.
/// let req1 = deduplicator.request(using: session, "https://api.example.com/feed")
///     .responseDecodable(of: Feed.self) { response in /* update screen A */ }
///
/// let req2 = deduplicator.request(using: session, "https://api.example.com/feed")
///     .responseDecodable(of: Feed.self) { response in /* update screen B */ }
/// ```
///
/// **Cancellation**
/// Cancelling any one of the returned `DataRequest`s cancels the underlying request for **all** callers, since they
/// all hold a reference to the same object. This is intentional for the current implementation.
public final class RequestDeduplicator: @unchecked Sendable {
    // MARK: - Types

    /// Closure that maps a resolved `URL` and `HTTPMethod` to a deduplication key.
    ///
    /// Return `nil` to opt out of deduplication for a particular request; a fresh `DataRequest` is created instead.
    public typealias KeyProvider = @Sendable (_ url: URL, _ method: HTTPMethod) -> String?

    private enum Outcome {
        case existing(DataRequest)
        case new(DataRequest)
    }

    private struct State {
        var inflightRequests: [String: DataRequest] = [:]
    }

    // MARK: - Properties

    /// Default key strategy: `"<METHOD>:<absoluteURL>"`.
    ///
    /// Two requests share a key — and are therefore deduplicated — when they target the same absolute URL with the
    /// same HTTP method.
    public static let defaultKeyProvider: KeyProvider = { url, method in
        "\(method.rawValue):\(url.absoluteString)"
    }

    private let keyProvider: KeyProvider
    private let state = Protected(State())

    // MARK: - Initialization

    /// Creates a `RequestDeduplicator` using the default key strategy (HTTP method + absolute URL).
    public init() {
        keyProvider = Self.defaultKeyProvider
    }

    /// Creates a `RequestDeduplicator` with a custom key provider.
    ///
    /// Use a custom provider when the default strategy is too coarse (e.g. to ignore query parameters)
    /// or too broad (e.g. to deduplicate across methods).
    ///
    /// - Parameter keyProvider: Closure returning the deduplication key for a given `URL` and `HTTPMethod`.
    ///                          Return `nil` to bypass deduplication for a specific request.
    public init(keyProvider: @escaping KeyProvider) {
        self.keyProvider = keyProvider
    }

    // MARK: - Request

    /// Returns a `DataRequest` for the specified resource, reusing an in-flight request when a duplicate is detected.
    ///
    /// If no request with the computed key is currently in-flight, a new `DataRequest` is created via `session`
    /// and stored. The stored reference is cleared automatically once the request finishes or fails, so subsequent
    /// calls for the same resource always start a fresh request.
    ///
    /// - Parameters:
    ///   - session:         `Session` used to create new `DataRequest`s.
    ///   - url:             `URLConvertible` value for the request.
    ///   - method:          `HTTPMethod` for the request. `.get` by default.
    ///   - parameters:      `Parameters` to encode into the request. `nil` by default.
    ///   - encoding:        `ParameterEncoding` to apply. `URLEncoding.default` by default.
    ///   - headers:         `HTTPHeaders` to attach. `nil` by default.
    ///   - interceptor:     `RequestInterceptor` for per-request adapt/retry logic. `nil` by default.
    ///   - requestModifier: `Session.RequestModifier` applied before the `URLRequest` is sent. `nil` by default.
    ///
    /// - Returns: An existing in-flight `DataRequest` when a duplicate key is detected, or a new one otherwise.
    @discardableResult
    public func request(using session: Session,
                        _ url: URLConvertible,
                        method: HTTPMethod = .get,
                        parameters: Parameters? = nil,
                        encoding: ParameterEncoding = URLEncoding.default,
                        headers: HTTPHeaders? = nil,
                        interceptor: (any RequestInterceptor)? = nil,
                        requestModifier: Session.RequestModifier? = nil) -> DataRequest {
        // Resolve the URL before acquiring the lock so the key provider receives a stable, Sendable value.
        guard let resolvedURL = try? url.asURL(),
              let key = keyProvider(resolvedURL, method) else {
            return session.request(url,
                                   method: method,
                                   parameters: parameters,
                                   encoding: encoding,
                                   headers: headers,
                                   interceptor: interceptor,
                                   requestModifier: requestModifier)
        }

        let outcome: Outcome = state.write { state in
            if let existing = state.inflightRequests[key] {
                return .existing(existing)
            }

            // session.request() dispatches its setup work asynchronously onto Session.rootQueue,
            // so it returns immediately and holding the lock here is safe.
            let newRequest = session.request(url,
                                             method: method,
                                             parameters: parameters,
                                             encoding: encoding,
                                             headers: headers,
                                             interceptor: interceptor,
                                             requestModifier: requestModifier)
            state.inflightRequests[key] = newRequest
            return .new(newRequest)
        }

        switch outcome {
        case .existing(let request):
            return request

        case .new(let request):
            // Cleanup is registered outside the lock. Alamofire invokes response handlers immediately
            // upon registration when the request has already finished (e.g. from URLCache), ensuring
            // the map entry is always cleared regardless of timing.
            request.response { [weak self] _ in
                self?.state.write { $0.inflightRequests.removeValue(forKey: key) }
            }
            return request
        }
    }
}
