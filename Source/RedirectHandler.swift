//
//  RedirectHandler.swift
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

import Foundation

/// A type that handles how an HTTP redirect response from a remote server should be redirected to the new request.
public protocol RedirectHandler {
    /// Determines how the HTTP redirect response should be redirected to the new request.
    ///
    /// The `completion` closure should be passed one of three possible options:
    ///
    ///   1. The new request specified by the redirect (this is the most common use case).
    ///   2. A modified version of the new request (you may want to route it somewhere else).
    ///   3. A `nil` value to deny the redirect request and return the body of the redirect response.
    ///
    /// - Parameters:
    ///   - task:       The task whose request resulted in a redirect.
    ///   - request:    The URL request object to the new location specified by the redirect response.
    ///   - response:   The response containing the server's response to the original request.
    ///   - completion: The closure to execute containing the new request, a modified request, or `nil`.
    func task(_ task: URLSessionTask,
              willBeRedirectedTo request: URLRequest,
              for response: HTTPURLResponse,
              completion: @escaping (URLRequest?) -> Void)
}

// MARK: -

/// `Redirector` is a convenience `RedirectHandler` making it easy to follow, not follow, or modify a redirect.
public struct Redirector {
    /// Defines the behavior of the `Redirector` type.
    public enum Behavior {
        /// Follow the redirect as defined in the response.
        case follow
        /// Do not follow the redirect defined in the response.
        case doNotFollow
        /// Modify the redirect request defined in the response.
        case modify((URLSessionTask, URLRequest, HTTPURLResponse) -> URLRequest?)
    }

    /// Returns a `Redirector` with a `.follow` `Behavior`.
    public static let follow = Redirector(behavior: .follow)
    /// Returns a `Redirector` with a `.doNotFollow` `Behavior`.
    public static let doNotFollow = Redirector(behavior: .doNotFollow)

    /// The `Behavior` of the `Redirector`.
    public let behavior: Behavior

    /// Creates a `Redirector` instance from the `Behavior`.
    ///
    /// - Parameter behavior: The `Behavior`.
    public init(behavior: Behavior) {
        self.behavior = behavior
    }
}

// MARK: -

extension Redirector: RedirectHandler {
    public func task(_ task: URLSessionTask,
              willBeRedirectedTo request: URLRequest,
              for response: HTTPURLResponse,
              completion: @escaping (URLRequest?) -> Void) {
        switch behavior {
        case .follow:
            completion(request)
        case .doNotFollow:
            completion(nil)
        case .modify(let closure):
            let request = closure(task, request, response)
            completion(request)
        }
    }
}
