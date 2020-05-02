//
//  AuthenticationInterceptor.swift
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

import Foundation

/// NOTE: CN docstring
public protocol AuthenticationCredential {
    /// NOTE: CN docstring
    var requiresRefresh: Bool { get }
}

// MARK: -

/// NOTE: CN docstring
public protocol Authenticator: AnyObject {
    /// NOTE: CN docstring
    associatedtype Credential: AuthenticationCredential

    /// NOTE: CN rework docstring
    ///
    /// Authenticates the `URLRequest` with the `Credential` information. In the case of OAuth2, the access token of
    /// the `Credential` would be added as a Bearer token to the `Authorization` header.
    func apply(_ credential: Credential, to urlRequest: inout URLRequest)

    /// NOTE: CN rework docstring
    ///
    /// Refreshes the `Credential` and executes the completion closure with the `Result` once complete.
    func refresh(_ credential: Credential, for session: Session, completion: @escaping (Result<Credential, Error>) -> Void)

    /// NOTE: CN rework docstring
    ///
    /// Returns whether the `URLRequest` failed due to an authentication error based on the `HTTPURLResponse` and
    /// the `Error`. In the case of OAuth2, if you authentication server can invalidate access tokens, then you need
    /// to use this method to inspect the `HTTPURLResponse` looking for an indicator that this happened. This is
    /// commonly handled by the authentication server returning a 401 and some additional header to indicate that
    /// the `Authorization` header is invalid or not authorized.
    ///
    /// It is very important to understand how your authentication server works to be able to implement this correctly.
    /// For example, if your authentication server returns a 401 when an OAuth2 error occurs, and your downstream
    /// service also returns a 401 when you are not authorized to perform that operation, how do you know which layer
    /// of the backend returned you a 401? You do not want to trigger a refresh unless you know your authentication
    /// server is actually the layer rejecting the request.
    ///
    /// If your authentication server will never reject non-expired credentials for performance reasons, then you can
    /// safely return `false` for this method.
    func didRequest(_ urlRequest: URLRequest, with response: HTTPURLResponse, failDueToAuthenticationError error: Error) -> Bool

    /// NOTE: CN rework docstring
    ///
    /// Returns whether the `URLRequest` was authenticated with the specified `Credential`. If it was not, then we know
    /// the `URLRequest` was authenticated with a previous `Credential` and can be immediately retried with the new
    /// `Credential`.
    ///
    /// This is an edge case that can occur if the authentication server can invalidate non-expired credentials. In
    /// this case, it's possible for requests to be executed with non-expired, invalid credentials. Refresh will be
    /// triggered when the first failing response comes back from the authentication server. It is possible that some
    /// of the requests will not return from the authentication server until the refresh is completed. In this case,
    /// we inspect the slower requests when returned from the authentication server to see if the credential applied
    /// to them is the same as the latest credential. If not, then we know we've refreshed the credential while the
    /// request was in flight and it is immediately retried with the new credential. If yes, then we know we've found
    /// the first request to fail due to a non-expired, invalidate credential and refresh is triggered.
    func isRequest(_ urlRequest: URLRequest, authenticatedWith credential: Credential) -> Bool
}

// MARK: -

/// NOTE: CN docstring
public enum AuthenticationError: Error {
    /// NOTE: CN docstring
    case missingCredential

    /// NOTE: CN docstring
    case excessiveRefresh
}

// MARK: -

/// NOTE: CN docstring
public class AuthenticationInterceptor<AuthenticatorType>: RequestInterceptor where AuthenticatorType: Authenticator {

    // MARK: Typealiases

    /// NOTE: CN docstring
    public typealias Credential = AuthenticatorType.Credential

    // MARK: Helper Types

    /// NOTE: CN docstring
    public struct RefreshWindow {
        /// NOTE: CN docstring
        public let interval: TimeInterval

        /// NOTE: CN docstring
        public let maximumAttempts: Int

        /// NOTE: CN docstring
        public init(interval: TimeInterval = 30.0, maximumAttempts: Int = 5) {
            self.interval = interval
            self.maximumAttempts = maximumAttempts
        }
    }

    private struct AdaptOperation {
        let urlRequest: URLRequest
        let session: Alamofire.Session
        let completion: (Result<URLRequest, Error>) -> Void
    }

    private enum AdaptResult {
        case adapt(Credential)
        case doNotAdapt(AuthenticationError)
        case adaptDeferred
    }

    private struct MutableState {
        var credential: Credential?

        var isRefreshing = false
        var refreshTimestamps: [Date] = []
        var refreshWindow: RefreshWindow?

        var adaptOperations: [AdaptOperation] = []
        var requestsToRetry: [(Alamofire.RetryResult) -> Void] = []
    }

    // MARK: Properties

    /// NOTE: CN docstring
    public var credential: Credential? {
        get { mutableState.credential }
        set { mutableState.credential = newValue }
    }

    let authenticator: AuthenticatorType
    let queue = DispatchQueue(label: "org.alamofire.authentication.inspector")

    @Protected
    private var mutableState = MutableState()

    // MARK: Initialization

    /// NOTE: CN docstring
    public init(
        authenticator: AuthenticatorType,
        credential: Credential? = nil,
        refreshWindow: RefreshWindow? = nil)
    {
        self.authenticator = authenticator
        self.mutableState.credential = credential
        self.mutableState.refreshWindow = refreshWindow
    }

    // MARK: Adapt

    public func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        let adaptResult: AdaptResult = $mutableState.write { mutableState in
            // Queue the adapt operation if a refresh is already in place
            guard !mutableState.isRefreshing else {
                let operation = AdaptOperation(urlRequest: urlRequest, session: session, completion: completion)
                mutableState.adaptOperations.append(operation)
                return .adaptDeferred
            }

            // Throw missing credential error is the credential is missing
            guard let credential = mutableState.credential else {
                let error = AuthenticationError.missingCredential
                return .doNotAdapt(error)
            }

            // Queue the adapt operation and trigger refresh operation if credential is requires refresh
            guard !credential.requiresRefresh else {
                let operation = AdaptOperation(urlRequest: urlRequest, session: session, completion: completion)
                mutableState.adaptOperations.append(operation)
                refresh(credential, for: session, insideLock: &mutableState)
                return .adaptDeferred
            }

            return .adapt(credential)
        }

        switch adaptResult {
        case .adapt(let credential):
            var authenticatedRequest = urlRequest
            authenticator.apply(credential, to: &authenticatedRequest)
            completion(.success(authenticatedRequest))

        case .doNotAdapt(let adaptError):
            completion(.failure(adaptError))

        case .adaptDeferred:
            // No-op: adapt operation captured during refresh
            break
        }
    }

    // MARK: Retry

    public func retry(_ request: Request, for session: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
        // Do not attempt retry if there was not an original request and response from the server
        guard let urlRequest = request.request, let response = request.response else {
            completion(.doNotRetry)
            return
        }

        // Do not attempt retry unless inspector verifies failure was due to authentication error (i.e. 401 status code)
        guard authenticator.didRequest(urlRequest, with: response, failDueToAuthenticationError: error) else {
            completion(.doNotRetry)
            return
        }

        // Do not attempt retry if there is no credential (throw missing credential error instead since retry required)
        guard let credential = credential else {
            let error = AuthenticationError.missingCredential
            completion(.doNotRetryWithError(error))
            return
        }

        // Retry the request if inspector verifies it was authenticated with a previous credential
        guard authenticator.isRequest(urlRequest, authenticatedWith: credential) else {
            completion(.retry)
            return
        }

        $mutableState.write { mutableState in
            mutableState.requestsToRetry.append(completion)

            guard !mutableState.isRefreshing else { return }

            refresh(credential, for: session, insideLock: &mutableState)
        }
    }

    // MARK: Refresh

    private func refresh(_ credential: Credential, for session: Session, insideLock mutableState: inout MutableState) {
        guard !isRefreshExcessive(insideLock: &mutableState) else {
            let error = AuthenticationError.excessiveRefresh
            handleRefreshFailure(error, insideLock: &mutableState)
            return
        }

        mutableState.refreshTimestamps.append(Date())
        mutableState.isRefreshing = true

        authenticator.refresh(credential, for: session) { result in
            self.$mutableState.write { mutableState in
                switch result {
                case .success(let credential):
                    self.handleRefreshSuccess(credential, insideLock: &mutableState)

                case .failure(let error):
                    self.handleRefreshFailure(error, insideLock: &mutableState)
                }
            }
        }
    }

    private func isRefreshExcessive(insideLock mutableState: inout MutableState) -> Bool {
        guard let refreshWindow = mutableState.refreshWindow else { return false }

        let refreshWindowMin = Date(timeIntervalSinceNow: -refreshWindow.interval)

        let refreshAttemptsWithinWindow = mutableState.refreshTimestamps.reduce(into: 0) { attempts, refreshTimestamp in
            guard refreshWindowMin <= refreshTimestamp else { return }
            attempts += 1
        }

        let isRefreshExcessive = refreshAttemptsWithinWindow >= refreshWindow.maximumAttempts

        return isRefreshExcessive
    }

    private func handleRefreshSuccess(_ credential: Credential, insideLock mutableState: inout MutableState) {
        mutableState.credential = credential

        let adaptOperations = mutableState.adaptOperations
        let requestsToRetry = mutableState.requestsToRetry

        mutableState.adaptOperations.removeAll()
        mutableState.requestsToRetry.removeAll()

        mutableState.isRefreshing = false

        // Dispatch to queue to hop out of the mutable state lock
        queue.async {
            adaptOperations.forEach { self.adapt($0.urlRequest, for: $0.session, completion: $0.completion) }
            requestsToRetry.forEach { $0(.retry) }
        }
    }

    private func handleRefreshFailure(_ error: Error, insideLock mutableState: inout MutableState) {
        let adaptOperations = mutableState.adaptOperations
        let requestsToRetry = mutableState.requestsToRetry

        mutableState.adaptOperations.removeAll()
        mutableState.requestsToRetry.removeAll()

        mutableState.isRefreshing = false

        // Dispatch to queue to hop out of the mutable state lock
        queue.async {
            adaptOperations.forEach { $0.completion(.failure(error)) }
            requestsToRetry.forEach { $0(.doNotRetryWithError(error)) }
        }
    }
}
