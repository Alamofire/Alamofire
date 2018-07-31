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
    private var requests: [URLSessionTask: Request]
    private var tasks: [Request: URLSessionTask]

    init(requests: [URLSessionTask: Request] = [:], tasks: [Request: URLSessionTask] = [:]) {
        self.requests = requests
        self.tasks = tasks
    }

    subscript(_ request: Request) -> URLSessionTask? {
        get { return tasks[request] }
        set {
            guard let newValue = newValue else {
                guard let task = tasks[request] else {
                    fatalError("RequestTaskMap consistency error: no task corresponding to request found.")
                }

                tasks.removeValue(forKey: request)
                requests.removeValue(forKey: task)

                return
            }

            tasks[request] = newValue
            requests[newValue] = request
        }
    }

    subscript(_ task: URLSessionTask) -> Request? {
        get { return requests[task] }
        set {
            guard let newValue = newValue else {
                guard let request = requests[task] else {
                    fatalError("RequestTaskMap consistency error: no request corresponding to task found.")
                }

                requests.removeValue(forKey: task)
                tasks.removeValue(forKey: request)

                return
            }

            requests[task] = newValue
            tasks[newValue] = task
        }
    }

    var count: Int {
        precondition(requests.count == tasks.count,
                     "RequestTaskMap.count invalid, requests.count: \(requests.count) != tasks.count: \(tasks.count)")

        return requests.count
    }

    var isEmpty: Bool {
        precondition(requests.isEmpty == tasks.isEmpty,
                     "RequestTaskMap.isEmpty invalid, requests.isEmpty: \(requests.isEmpty) != tasks.isEmpty: \(tasks.isEmpty)")

        return requests.isEmpty
    }
}
