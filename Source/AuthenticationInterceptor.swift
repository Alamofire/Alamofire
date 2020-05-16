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

/// Types adopting the `AuthenticationCredential` protocol can be used to authenticate `URLRequest`s.
///
/// One common example of an `AuthenticationCredential` is an OAuth2 credential containing an access token used to
/// authenticate all requests on behalf of a user. The access token generally has an expiration window of 60 minutes
/// which will then require a refresh of the credential using the refresh token to generate a new access token.
public protocol AuthenticationCredential {
    /// Whether the credential requires a refresh. This property should always return `true` when the credential is
    /// expired. It is also wise to consider returning `true` when the credential will expire in several seconds or
    /// minutes depending on the expiration window of the credential.
    ///
    /// For example, if the credential is valid for 60 minutes, then it would be wise to return `true` when the
    /// credential is only valid for 5 minutes or less. That ensures the credential will not expire as it is passed
    /// around backend services.
    var requiresRefresh: Bool { get }
}

// MARK: -

/// Types adopting the `Authenticator` protocol can be used to authenticate `URLRequest`s with an
/// `AuthenticationCredential` as well as refresh the `AuthenticationCredential` when required.
public protocol Authenticator: AnyObject {
    /// The type of credential associated with the `Authenticator` instance.
    associatedtype Credential: AuthenticationCredential

    /// Applies the `Credential` to the `URLRequest`.
    ///
    /// In the case of OAuth2, the access token of the `Credential` would be added to the `URLRequest` as a Bearer
    /// token to the `Authorization` header.
    ///
    /// - Parameters:
    ///   - credential: The `Credential`.
    ///   - urlRequest: The `URLRequest`.
    func apply(_ credential: Credential, to urlRequest: inout URLRequest)

    /// Refreshes the `Credential` and executes the `completion` closure with the `Result` once complete.
    ///
    /// Refresh can be called in one of two ways. It can be called before the `Request` is actually executed due to
    /// a `requiresRefresh` returning `true` during the adapt portion of the `Request` creation process. It can also
    /// be triggered by a failed `Request` where the authentication server denied access due to an expired or
    /// invalidated access token.
    ///
    /// In the case of OAuth2, this method would use the refresh token of the `Credential` to generate a new
    /// `Credential` using the authentication service. Once complete, the `completion` closure should be called with
    /// the new `Credential`, or the error that occurred.
    ///
    /// In general, if the refresh call fails with certain status codes from the authentication server (commonly a 401),
    /// the refresh token in the `Credential` can no longer be used to generate a valid `Credential`. In these cases,
    /// you will need to reauthenticate the user with their username / password.
    ///
    /// Please note, these are just general examples of common use cases. They are not meant to solve your specific
    /// authentication server challenges. Please work with your authentication server team to ensure your
    /// `Authenticator` logic matches their expectations.
    ///
    /// - Parameters:
    ///   - credential: The `Credential` to refresh.
    ///   - session:    The `Session` requiring the refresh.
    ///   - completion: The closure to be executed once the refresh is complete.
    func refresh(_ credential: Credential, for session: Session, completion: @escaping (Result<Credential, Error>) -> Void)

    /// Determines whether the `URLRequest` failed due to an authentication error based on the `HTTPURLResponse`.
    ///
    /// If the authentication server **CANNOT** invalidate credentials after they are issued, then simply return `false`
    /// for this method. If the authentication server **CAN** invalidate credentials due to security breaches, then you
    /// will need to work with your authentication server team to understand how to identify when this occurs.
    ///
    /// In the case of OAuth2, where an authentication server can invalidate credentials, you will need to inspect the
    /// `HTTPURLResponse` or possibly the `Error` for when this occurs. This is commonly handled by the authentication
    /// server returning a 401 status code and some additional header to indicate an OAuth2 failure occurred.
    ///
    /// It is very important to understand how your authentication server works to be able to implement this correctly.
    /// For example, if your authentication server returns a 401 when an OAuth2 error occurs, and your downstream
    /// service also returns a 401 when you are not authorized to perform that operation, how do you know which layer
    /// of the backend returned you a 401? You do not want to trigger a refresh unless you know your authentication
    /// server is actually the layer rejecting the request. Again, work with your authentication server team to understand
    /// how to identify an OAuth2 401 error vs. a downstream 401 error to avoid endless refresh loops.
    ///
    /// - Parameters:
    ///   - urlRequest: The `URLRequest`.
    ///   - response:   The `HTTPURLResponse`.
    ///   - error:      The `Error`.
    ///
    /// - Returns: `true` if the `URLRequest` failed due to an authentication error, `false` otherwise.
    func didRequest(_ urlRequest: URLRequest, with response: HTTPURLResponse, failDueToAuthenticationError error: Error) -> Bool

    /// Determines whether the `URLRequest` is authenticated with the `Credential`.
    ///
    /// If the authentication server **CANNOT** invalidate credentials after they are issued, then simply return `true`
    /// for this method. If the authentication server **CAN** invalidate credentials due to security breaches, then
    /// read on.
    ///
    /// When an authentication server can invalidate credentials, it means that you may have a non-expired credential
    /// that appears to be valid, but will be rejected by the authentication server when used. Generally when this
    /// happens, a number of requests are all sent when the application is foregrounded, and all of them will be
    /// rejected by the authentication server in the order they are received. The first failed request will trigger a
    /// refresh internally, which will update the credential, and then retry all the queued requests with the new
    /// credential. However, it is possible that some of the original requests will not return from the authentication
    /// server until the refresh has completed. This is where this method comes in.
    ///
    /// When the authentication server rejects a credential, we need to check to make sure we haven't refreshed the
    /// credential while the request was in flight. If it has already refreshed, then we don't need to trigger an
    /// additional refresh. If it hasn't refreshed, then we need to refresh.
    ///
    /// Now that it is understood how the result of this method is used in the refresh lifecyle, let's walk through how
    /// to implement it. You should return `true` in this method if the `URLRequest` is authenticated in a way that
    /// matches the values in the `Credential`. In the case of OAuth2, this would mean that the Bearer token in the
    /// `Authorization` header of the `URLRequest` matches the access token in the `Credential`. If it matches, then we
    /// know the `Credential` was used to authenticate the `URLRequest` and should return `true`. If the Bearer token
    /// did not match the access token, then you should return `false`.
    ///
    /// - Parameters:
    ///   - urlRequest: The `URLRequest`.
    ///   - credential: The `Credential`.
    ///
    /// - Returns: `true` if the `URLRequest` is authenticated with the `Credential`, `false` otherwise.
    func isRequest(_ urlRequest: URLRequest, authenticatedWith credential: Credential) -> Bool
}

// MARK: -

/// Represents various authentication failures that occur when using the `AuthenticationInterceptor`. All errors are
/// still vended from Alamofire as `AFError` types. The `AuthenticationError` instances will be embedded within
/// `AFError` `.requestAdaptationFailed` or `.requestRetryFailed` cases.
public enum AuthenticationError: Error {
    /// The credential was missing so the request could not be authenticated.
    case missingCredential
    /// The credential was refreshed too many times within the `RefreshWindow`.
    case excessiveRefresh
}

// MARK: -

/// The `AuthenticationInterceptor` class manages the queuing and threading complexity of authenticating requests.
/// It relies on an `Authenticator` type to handle the actual `URLRequest` authentication and `Credential` refresh.
public class AuthenticationInterceptor<AuthenticatorType>: RequestInterceptor where AuthenticatorType: Authenticator {
    // MARK: Typealiases

    /// Type of credential used to authenticate requests.
    public typealias Credential = AuthenticatorType.Credential

    // MARK: Helper Types

    /// Type that defines a time window used to identify excessive refresh calls. When enabled, prior to executing a
    /// refresh, the `AuthenticationInterceptor` compares the timestamp history of previous refresh calls against the
    /// `RefreshWindow`. If more refreshes have occurred within the refresh window than allowed, the refresh is
    /// cancelled and an `AuthorizationError.excessiveRefresh` error is thrown.
    public struct RefreshWindow {
        /// `TimeInterval` defining the duration of the time window before the current time in which the number of
        /// refresh attempts is compared against `maximumAttempts`. For example, if `interval` is 30 seconds, then the
        /// `RefreshWindow` represents the past 30 seconds. If more attempts occurred in the past 30 seconds than
        /// `maximumAttempts`, an `.excessiveRefresh` error will be thrown.
        public let interval: TimeInterval

        /// Total refresh attempts allowed within `interval` before throwing an `.excessiveRefresh` error.
        public let maximumAttempts: Int

        /// Creates a `RefreshWindow` instance from the specified `interval` and `maximumAttempts`.
        ///
        /// - Parameters:
        ///   - interval:        `TimeInterval` defining the duration of the time window before the current time.
        ///   - maximumAttempts: The maximum attempts allowed within the `TimeInterval`.
        public init(interval: TimeInterval = 30.0, maximumAttempts: Int = 5) {
            self.interval = interval
            self.maximumAttempts = maximumAttempts
        }
    }

    private struct AdaptOperation {
        let urlRequest: URLRequest
        let session: Session
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
        var refreshTimestamps: [TimeInterval] = []
        var refreshWindow: RefreshWindow?

        var adaptOperations: [AdaptOperation] = []
        var requestsToRetry: [(Alamofire.RetryResult) -> Void] = []
    }

    // MARK: Properties

    /// The `Credential` used to authenticate requests.
    public var credential: Credential? {
        get { mutableState.credential }
        set { mutableState.credential = newValue }
    }

    let authenticator: AuthenticatorType
    let queue = DispatchQueue(label: "org.alamofire.authentication.inspector")

    @Protected
    private var mutableState = MutableState()

    // MARK: Initialization

    /// Creates an `AuthenticationInterceptor` instance from the specified parameters.
    ///
    /// A `nil` `RefreshWindow` will result in the `AuthenticationInterceptor` not checking for excessive refresh calls.
    /// It is recommended to always use a `RefreshWindow` to avoid endless refresh cycles.
    ///
    /// - Parameters:
    ///   - authenticator: The `Authenticator` type.
    ///   - credential:    The `Credential` if it exists. `nil` by default.
    ///   - refreshWindow: The `RefreshWindow` used to identify excessive refresh calls. `RefreshWindow()` by default.
    public init(authenticator: AuthenticatorType,
                credential: Credential? = nil,
                refreshWindow: RefreshWindow? = RefreshWindow()) {
        self.authenticator = authenticator
        mutableState.credential = credential
        mutableState.refreshWindow = refreshWindow
    }

    // MARK: Adapt

    public func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        let adaptResult: AdaptResult = $mutableState.write { mutableState in
            // Queue the adapt operation if a refresh is already in place.
            guard !mutableState.isRefreshing else {
                let operation = AdaptOperation(urlRequest: urlRequest, session: session, completion: completion)
                mutableState.adaptOperations.append(operation)
                return .adaptDeferred
            }

            // Throw missing credential error is the credential is missing.
            guard let credential = mutableState.credential else {
                let error = AuthenticationError.missingCredential
                return .doNotAdapt(error)
            }

            // Queue the adapt operation and trigger refresh operation if credential requires refresh.
            guard !credential.requiresRefresh else {
                let operation = AdaptOperation(urlRequest: urlRequest, session: session, completion: completion)
                mutableState.adaptOperations.append(operation)
                refresh(credential, for: session, insideLock: &mutableState)
                return .adaptDeferred
            }

            return .adapt(credential)
        }

        switch adaptResult {
        case let .adapt(credential):
            var authenticatedRequest = urlRequest
            authenticator.apply(credential, to: &authenticatedRequest)
            completion(.success(authenticatedRequest))

        case let .doNotAdapt(adaptError):
            completion(.failure(adaptError))

        case .adaptDeferred:
            // No-op: adapt operation captured during refresh.
            break
        }
    }

    // MARK: Retry

    public func retry(_ request: Request, for session: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
        // Do not attempt retry if there was not an original request and response from the server.
        guard let urlRequest = request.request, let response = request.response else {
            completion(.doNotRetry)
            return
        }

        // Do not attempt retry unless the `Authenticator` verifies failure was due to authentication error (i.e. 401 status code).
        guard authenticator.didRequest(urlRequest, with: response, failDueToAuthenticationError: error) else {
            completion(.doNotRetry)
            return
        }

        // Do not attempt retry if there is no credential.
        guard let credential = credential else {
            let error = AuthenticationError.missingCredential
            completion(.doNotRetryWithError(error))
            return
        }

        // Retry the request if the `Authenticator` verifies it was authenticated with a previous credential.
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

        mutableState.refreshTimestamps.append(ProcessInfo.processInfo.systemUptime)
        mutableState.isRefreshing = true

        authenticator.refresh(credential, for: session) { result in
            self.$mutableState.write { mutableState in
                switch result {
                case let .success(credential):
                    self.handleRefreshSuccess(credential, insideLock: &mutableState)

                case let .failure(error):
                    self.handleRefreshFailure(error, insideLock: &mutableState)
                }
            }
        }
    }

    private func isRefreshExcessive(insideLock mutableState: inout MutableState) -> Bool {
        guard let refreshWindow = mutableState.refreshWindow else { return false }

        let refreshWindowMin = ProcessInfo.processInfo.systemUptime - refreshWindow.interval

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
