// Notifications.swift
//
// Copyright (c) 2014–2016 Alamofire Software Foundation (http://alamofire.org/)
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

import Foundation

/// Contains all the `NSNotification` names posted by Alamofire with descriptions of each notification's payload.
public struct Notifications {
    /// Used as a namespace for all `NSURLSessionTask` related notifications.
    public struct Task {
        /// Notification posted when an `NSURLSessionTask` is resumed. The notification `object` contains the resumed
        /// `NSURLSessionTask`.
        public static let DidResume = "com.alamofire.notifications.task.didResume"

        /// Notification posted when an `NSURLSessionTask` is suspended. The notification `object` contains the 
        /// suspended `NSURLSessionTask`.
        public static let DidSuspend = "com.alamofire.notifications.task.didSuspend"

        /// Notification posted when an `NSURLSessionTask` is cancelled. The notification `object` contains the
        /// cancelled `NSURLSessionTask`.
        public static let DidCancel = "com.alamofire.notifications.task.didCancel"

        /// Notification posted when an `NSURLSessionTask` is completed. The notification `object` contains the
        /// completed `NSURLSessionTask`.
        public static let DidComplete = "com.alamofire.notifications.task.didComplete"
    }
}
