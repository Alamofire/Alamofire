//
//  RequestTaskMap.swift
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

/// A type that maintains a two way, one to one map of `URLSessionTask`s to `Request`s.
struct RequestTaskMap {
    private var tasksToRequests: [URLSessionTask: Request]
    private var requestsToTasks: [Request: URLSessionTask]

    var requests: [Request] {
        return Array(tasksToRequests.values)
    }

    init(tasksToRequests: [URLSessionTask: Request] = [:], requestsToTasks: [Request: URLSessionTask] = [:]) {
        self.tasksToRequests = tasksToRequests
        self.requestsToTasks = requestsToTasks
    }

    subscript(_ request: Request) -> URLSessionTask? {
        get { return requestsToTasks[request] }
        set {
            guard let newValue = newValue else {
                guard let task = requestsToTasks[request] else {
                    fatalError("RequestTaskMap consistency error: no task corresponding to request found.")
                }

                requestsToTasks.removeValue(forKey: request)
                tasksToRequests.removeValue(forKey: task)

                return
            }

            requestsToTasks[request] = newValue
            tasksToRequests[newValue] = request
        }
    }

    subscript(_ task: URLSessionTask) -> Request? {
        get { return tasksToRequests[task] }
        set {
            guard let newValue = newValue else {
                guard let request = tasksToRequests[task] else {
                    fatalError("RequestTaskMap consistency error: no request corresponding to task found.")
                }

                tasksToRequests.removeValue(forKey: task)
                requestsToTasks.removeValue(forKey: request)

                return
            }

            tasksToRequests[task] = newValue
            requestsToTasks[newValue] = task
        }
    }

    var count: Int {
        precondition(tasksToRequests.count == requestsToTasks.count,
                     "RequestTaskMap.count invalid, requests.count: \(tasksToRequests.count) != tasks.count: \(requestsToTasks.count)")

        return tasksToRequests.count
    }

    var isEmpty: Bool {
        precondition(tasksToRequests.isEmpty == requestsToTasks.isEmpty,
                     "RequestTaskMap.isEmpty invalid, requests.isEmpty: \(tasksToRequests.isEmpty) != tasks.isEmpty: \(requestsToTasks.isEmpty)")

        return tasksToRequests.isEmpty
    }
}
