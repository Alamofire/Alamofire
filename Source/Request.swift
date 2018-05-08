//
//  Request.swift
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

protocol RequestDelegate: AnyObject {
    func cancelRequest(_ request: Request)
    func suspendRequest(_ request: Request)
    func resumeRequest(_ request: Request)
}

open class Request {
    enum State {
        case initialized, performing, suspended, validating, finished
    }

    private(set) var state: State = .initialized

    let id: UUID
    let underlyingQueue: DispatchQueue
    let serializationQueue: DispatchQueue
    // TODO: Do we still want to expose the queue(s?) as public API?
    open let internalQueue: OperationQueue
    private weak var delegate: RequestDelegate?

    private(set) var initialRequest: URLRequest?
    open var request: URLRequest? {
        return lastTask?.currentRequest
    }
    open var response: HTTPURLResponse? {
        return lastTask?.response as? HTTPURLResponse
    }

    private(set) var metrics: URLSessionTaskMetrics?
    // TODO: Preseve all tasks?
    // TODO: How to expose task progress on iOS 11?
    private(set) var lastTask: URLSessionTask?
    fileprivate(set) var error: Error?
    private(set) var credential: URLCredential?
    fileprivate(set) var validators: [() -> Void] = []

    init(id: UUID = UUID(), underlyingQueue: DispatchQueue, serializationQueue: DispatchQueue? = nil, delegate: RequestDelegate) {
        self.id = id
        self.underlyingQueue = underlyingQueue
        self.serializationQueue = serializationQueue ?? underlyingQueue
        internalQueue = OperationQueue(maxConcurrentOperationCount: 1, underlyingQueue: underlyingQueue, name: "org.alamofire.request", startSuspended: true)
        self.delegate = delegate

        internalQueue.addOperation {
            self.validators.forEach { $0() }
            self.state = .finished
        }
    }

    // MARK: - Internal API
    // Called from internal queue.

    func didCreate(request: URLRequest) {
        self.initialRequest = request
    }

    func didResume() {
        state = .performing
    }

    func didSuspend() {
        state = .suspended
    }

    func didCancel() {
        error = AFError.explicitlyCancelled
    }

    func didGatherMetrics(_ metrics: URLSessionTaskMetrics) {
        self.metrics = metrics
    }

    func didFail(with task: URLSessionTask?, error: Error) {
        // TODO: Investigate whether we want a different mechanism here.
        self.error = self.error ?? error
        didComplete(task: task)
    }

    func didComplete(task: URLSessionTask?) {
        lastTask = task
        state = .validating

        internalQueue.isSuspended = false
    }

    // MARK: - Public API

    // Callable from any queue.

    public func cancel() {
        delegate?.cancelRequest(self)
    }

    public func suspend() {
        delegate?.suspendRequest(self)
    }

    public func resume() {
        delegate?.resumeRequest(self)
    }

    // MARK: - Closure API

    // Callable from any queue
    // TODO: Handle race from internal queue?
    @discardableResult
    open func authenticate(withUsername username: String, password: String, persistence: URLCredential.Persistence = .forSession) -> Self {
        let credential = URLCredential(user: username, password: password, persistence: persistence)
        return authenticate(with: credential)
    }

    @discardableResult
    open func authenticate(with credential: URLCredential) -> Self {
        self.credential = credential

        return self
    }
}

extension Request: Equatable {
    public static func == (lhs: Request, rhs: Request) -> Bool {
        return lhs.id == rhs.id
    }
}

extension Request: Hashable {
    public var hashValue: Int {
        return id.hashValue
    }
}

open class DataRequest: Request {
    private(set) var data: Data?

    func didRecieve(data: Data) {
        if self.data == nil {
            self.data = data
        } else {
            self.data?.append(data)
        }
    }

    /// Validates the request, using the specified closure.
    ///
    /// If validation fails, subsequent calls to response handlers will have an associated error.
    ///
    /// - parameter validation: A closure to validate the request.
    ///
    /// - returns: The request.
    @discardableResult
    public func validate(_ validation: @escaping Validation) -> Self {
        underlyingQueue.async {
            let validationExecution: () -> Void = { [unowned self] in
                if
                    let response = self.response,
                    self.error == nil,
                    case let .failure(error) = validation(self.request, response, self.data)
                {
                    self.error = error
                }
            }

            self.validators.append(validationExecution)
        }

        return self
    }
}

open class DownloadRequest: Request {
    /// A collection of options to be executed prior to moving a downloaded file from the temporary URL to the
    /// destination URL.
    public struct Options: OptionSet {
        /// Returns the raw bitmask value of the option and satisfies the `RawRepresentable` protocol.
        public let rawValue: Int

        /// Creates a `DownloadRequest.Options` instance with the specified raw value.
        ///
        /// - parameter rawValue: The raw bitmask value for the option.
        ///
        /// - returns: A new `DownloadRequest.Options` instance.
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        /// A `DownloadOptions` flag that creates intermediate directories for the destination URL if specified.
        public static let createIntermediateDirectories = Options(rawValue: 1 << 0)

        /// A `DownloadOptions` flag that removes a previous file from the destination URL if specified.
        public static let removePreviousFile = Options(rawValue: 1 << 1)
    }

    /// A closure executed once a download request has successfully completed in order to determine where to move the
    /// temporary file written to during the download process. The closure takes two arguments: the temporary file URL
    /// and the URL response, and returns a two arguments: the file URL where the temporary file should be moved and
    /// the options defining how the file should be moved.
    public typealias Destination = (_ temporaryURL: URL,
                                    _ response: HTTPURLResponse) -> (destinationURL: URL, options: Options)

    private let destination: Destination
    private(set) var temporaryURL: URL?

    init(id: UUID = UUID(), underlyingQueue: DispatchQueue, serializationQueue: DispatchQueue? = nil, delegate: RequestDelegate, destination: @escaping Destination) {
        self.destination = destination

        super.init(id: id, underlyingQueue: underlyingQueue, serializationQueue: serializationQueue, delegate: delegate)
    }

    func didComplete(task: URLSessionTask, with url: URL) {
        temporaryURL = url

        didComplete(task: task)
    }

    /// Validates the request, using the specified closure.
    ///
    /// If validation fails, subsequent calls to response handlers will have an associated error.
    ///
    /// - parameter validation: A closure to validate the request.
    ///
    /// - returns: The request.
    @discardableResult
    public func validate(_ validation: @escaping Validation) -> Self {
        underlyingQueue.async {
            let validationExecution: () -> Void = { [unowned self] in
                let request = self.request
                let temporaryURL = self.temporaryURL
                let destinationURL = self.temporaryURL

                if
                    let response = self.response,
                    self.error == nil,
                    case let .failure(error) = validation(request, response, temporaryURL, destinationURL)
                {
                    self.error = error
                }
            }

            self.validators.append(validationExecution)
        }

        return self
    }
}

open class UploadRequest: DataRequest {
    enum Uploadable {
        case data(Data)
        case file(URL)
        case stream(InputStream)
    }

    let uploadable: Uploadable

    init(id: UUID = UUID(), underlyingQueue: DispatchQueue, delegate: RequestDelegate, uploadable: Uploadable) {
        self.uploadable = uploadable

        super.init(id: id, underlyingQueue: underlyingQueue, delegate: delegate)
    }

    func inputStream() -> InputStream {
        switch uploadable {
        case .stream(let stream): return stream
        default: fatalError("Attempted to access the stream of an UploadRequest that wasn't created with one.")
        }
    }
}
