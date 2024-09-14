//
//  Notifications.swift
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

extension Request {
    /// Posted when a `Request` is resumed. The `Notification` contains the resumed `Request`.
    public static let didResumeNotification = Notification.Name(rawValue: "org.alamofire.notification.name.request.didResume")
    /// Posted when a `Request` is suspended. The `Notification` contains the suspended `Request`.
    public static let didSuspendNotification = Notification.Name(rawValue: "org.alamofire.notification.name.request.didSuspend")
    /// Posted when a `Request` is cancelled. The `Notification` contains the cancelled `Request`.
    public static let didCancelNotification = Notification.Name(rawValue: "org.alamofire.notification.name.request.didCancel")
    /// Posted when a `Request` is finished. The `Notification` contains the completed `Request`.
    public static let didFinishNotification = Notification.Name(rawValue: "org.alamofire.notification.name.request.didFinish")

    /// Posted when a `URLSessionTask` is resumed. The `Notification` contains the `Request` associated with the `URLSessionTask`.
    public static let didResumeTaskNotification = Notification.Name(rawValue: "org.alamofire.notification.name.request.didResumeTask")
    /// Posted when a `URLSessionTask` is suspended. The `Notification` contains the `Request` associated with the `URLSessionTask`.
    public static let didSuspendTaskNotification = Notification.Name(rawValue: "org.alamofire.notification.name.request.didSuspendTask")
    /// Posted when a `URLSessionTask` is cancelled. The `Notification` contains the `Request` associated with the `URLSessionTask`.
    public static let didCancelTaskNotification = Notification.Name(rawValue: "org.alamofire.notification.name.request.didCancelTask")
    /// Posted when a `URLSessionTask` is completed. The `Notification` contains the `Request` associated with the `URLSessionTask`.
    public static let didCompleteTaskNotification = Notification.Name(rawValue: "org.alamofire.notification.name.request.didCompleteTask")
}

// MARK: -

extension Notification {
    /// The `Request` contained by the instance's `userInfo`, `nil` otherwise.
    public var request: Request? {
        userInfo?[String.requestKey] as? Request
    }

    /// Convenience initializer for a `Notification` containing a `Request` payload.
    ///
    /// - Parameters:
    ///   - name:    The name of the notification.
    ///   - request: The `Request` payload.
    init(name: Notification.Name, request: Request) {
        self.init(name: name, object: nil, userInfo: [String.requestKey: request])
    }
}

extension NotificationCenter {
    /// Convenience function for posting notifications with `Request` payloads.
    ///
    /// - Parameters:
    ///   - name:    The name of the notification.
    ///   - request: The `Request` payload.
    func postNotification(named name: Notification.Name, with request: Request) {
        let notification = Notification(name: name, request: request)
        post(notification)
    }
}

extension String {
    /// User info dictionary key representing the `Request` associated with the notification.
    fileprivate static let requestKey = "org.alamofire.notification.key.request"
}

/// `EventMonitor` that provides Alamofire's notifications.
public final class AlamofireNotifications: EventMonitor {
    /// Creates an instance.
    public init() {}

    public func requestDidResume(_ request: Request) {
        NotificationCenter.default.postNotification(named: Request.didResumeNotification, with: request)
    }

    public func requestDidSuspend(_ request: Request) {
        NotificationCenter.default.postNotification(named: Request.didSuspendNotification, with: request)
    }

    public func requestDidCancel(_ request: Request) {
        NotificationCenter.default.postNotification(named: Request.didCancelNotification, with: request)
    }

    public func requestDidFinish(_ request: Request) {
        NotificationCenter.default.postNotification(named: Request.didFinishNotification, with: request)
    }

    public func request(_ request: Request, didResumeTask task: URLSessionTask) {
        NotificationCenter.default.postNotification(named: Request.didResumeTaskNotification, with: request)
    }

    public func request(_ request: Request, didSuspendTask task: URLSessionTask) {
        NotificationCenter.default.postNotification(named: Request.didSuspendTaskNotification, with: request)
    }

    public func request(_ request: Request, didCancelTask task: URLSessionTask) {
        NotificationCenter.default.postNotification(named: Request.didCancelTaskNotification, with: request)
    }

    public func request(_ request: Request, didCompleteTask task: URLSessionTask, with error: AFError?) {
        NotificationCenter.default.postNotification(named: Request.didCompleteTaskNotification, with: request)
    }
}
