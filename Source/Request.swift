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
    func isRetryingRequest(_ request: Request, ifNecessaryWithError error: Error) -> Bool

    func cancelRequest(_ request: Request)
    func cancelDownloadRequest(_ request: DownloadRequest, byProducingResumeData: @escaping (Data?) -> Void)
    func suspendRequest(_ request: Request)
    func resumeRequest(_ request: Request)
}

open class Request {
    /// A closure executed when monitoring upload or download progress of a request.
    public typealias ProgressHandler = (Progress) -> Void

    // TODO: Make publicly readable properties protected?
    public enum State {
        case initialized, resumed, suspended, cancelled

        func canTransitionTo(_ state: State) -> Bool {
            switch (self, state) {
            case (.initialized, _): return true
            case (_, .initialized), (.cancelled, _): return false
            case (.resumed, .cancelled), (.suspended, .cancelled),
                 (.resumed, .suspended), (.suspended, .resumed): return true
            case (.suspended, .suspended), (.resumed, .resumed): return false
            }
        }
    }

    // MARK: - Initial State

    let id: UUID
    let underlyingQueue: DispatchQueue
    let serializationQueue: DispatchQueue
    let eventMonitor: RequestEventMonitor?
    weak var delegate: RequestDelegate?

    // TODO: Do we still want to expose the queue(s?) as public API?
    open let internalQueue: OperationQueue

    // MARK: - Updated State

    let uploadProgress = Progress()
    let downloadProgress = Progress()
    var uploadProgressHandler: (handler: ProgressHandler, queue: DispatchQueue)?
    var downloadProgressHandler: (handler: ProgressHandler, queue: DispatchQueue)?

    private var protectedState: Protector<State> = Protector(.initialized)
    public fileprivate(set) var state: State {
        get { return protectedState.directValue }
        set { protectedState.directValue = newValue }
    }
    public var isCancelled: Bool { return state == .cancelled }
    public var isResumed: Bool { return state == .resumed }
    public var isSuspended: Bool { return state == .suspended }
    public var isInitialized: Bool { return state == .initialized }

    public var retryCount: Int { return protectedTasks.read { max($0.count - 1, 0) } }
    private(set) var initialRequest: URLRequest?
    open var request: URLRequest? {
        return finalTask?.currentRequest
    }
    open var response: HTTPURLResponse? {
        return finalTask?.response as? HTTPURLResponse
    }

    private(set) var metrics: URLSessionTaskMetrics?
    // TODO: How to expose task progress on iOS 11?

    private var protectedTasks = Protector<[URLSessionTask]>([])
    public var tasks: [URLSessionTask] {
        get { return protectedTasks.directValue }
    }
    public var initialTask: URLSessionTask? { return tasks.first }
    public var finalTask: URLSessionTask? { return tasks.last }
    public var task: URLSessionTask? { return finalTask }

    fileprivate(set) public var error: Error?
    private(set) var credential: URLCredential?
    fileprivate(set) var validators: [() -> Void] = []

    init(id: UUID = UUID(),
         underlyingQueue: DispatchQueue,
         serializationQueue: DispatchQueue? = nil,
         eventMonitor: RequestEventMonitor?,
         delegate: RequestDelegate) {
        self.id = id
        self.underlyingQueue = underlyingQueue
        self.serializationQueue = serializationQueue ?? underlyingQueue
        internalQueue = OperationQueue(maxConcurrentOperationCount: 1,
                                       underlyingQueue: underlyingQueue,
                                       name: "org.alamofire.request-\(id)",
                                       startSuspended: true)
        self.eventMonitor = eventMonitor
        self.delegate = delegate
    }

    // MARK: - Internal API
    // Called from internal queue.

    func didCreateURLRequest(_ request: URLRequest) {
        initialRequest = request

        eventMonitor?.request(self, didCreateURLRequest: request)
    }

    func didFailToCreateURLRequest(with error: Error) {
        self.error = error

        eventMonitor?.request(self, didFailToCreateURLRequestWithError: error)

        retryOrFinish(error: error)
    }

    func didAdaptInitialRequest(_ initialRequest: URLRequest, to adaptedRequest: URLRequest) {
        self.initialRequest = adaptedRequest
        // Set initialRequest or something else?
        eventMonitor?.request(self, didAdaptInitialRequest: initialRequest, to: adaptedRequest)
    }

    func didFailToAdaptURLRequest(_ request: URLRequest, withError error: Error) {
        self.error = error

        eventMonitor?.request(self, didFailToAdaptURLRequest: request, withError: error)

        retryOrFinish(error: error)
    }

    func didCreateTask(_ task: URLSessionTask) {
        protectedTasks.append(task)
        // TODO: Reset behavior?
        reset()

        eventMonitor?.request(self, didCreateTask: task)
    }

    func updateUploadProgress(totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        uploadProgress.totalUnitCount = totalBytesExpectedToSend
        uploadProgress.completedUnitCount = totalBytesSent

        uploadProgressHandler?.queue.async { self.uploadProgressHandler?.handler(self.uploadProgress) }
    }

    // Resets task related state
    func reset() {
        error = nil

        uploadProgress.totalUnitCount = 0
        uploadProgress.completedUnitCount = 0
        downloadProgress.totalUnitCount = 0
        downloadProgress.completedUnitCount = 0
    }

    func didResume() {
        eventMonitor?.requestDidResume(self)
    }

    func didSuspend() {
        eventMonitor?.requestDidSuspend(self)
    }

    func didCancel() {
        error = AFError.explicitlyCancelled

        eventMonitor?.requestDidCancel(self)
    }

    func didGatherMetrics(_ metrics: URLSessionTaskMetrics) {
        self.metrics = metrics

        eventMonitor?.request(self, didGatherMetrics: metrics)
    }

    // Should only be triggered by internal AF code, never URLSession
    func didFailTask(_ task: URLSessionTask, earlyWithError error: Error) {
        self.error = error
        // Task will still complete, so didCompleteTask(_:with:) will handle retry.
        eventMonitor?.request(self, didFailTask: task, earlyWithError: error)
    }

    // Completion point for all tasks.
    func didCompleteTask(_ task: URLSessionTask, with error: Error?) {
        self.error = self.error ?? error
        validators.forEach { $0() }

        eventMonitor?.request(self, didCompleteTask: task, with: error)

        retryOrFinish(error: self.error)
    }

    func retryOrFinish(error: Error?) {
        if let error = error, delegate?.isRetryingRequest(self, ifNecessaryWithError: error) == true {
            return
        } else {
            finish()
        }
    }

    func finish() {
        // Start response handlers
        internalQueue.isSuspended = false

        eventMonitor?.requestDidFinish(self)
    }

    // MARK: Task Creation

    // Subclasses wanting something other than URLSessionDataTask should override.
    func task(for request: URLRequest, using session: URLSession) -> URLSessionTask {
        return session.dataTask(with: request)
    }

    // MARK: - Public API

    // Callable from any queue.

    @discardableResult
    public func cancel() -> Self {
        guard state.canTransitionTo(.cancelled) else { return self }

        state = .cancelled

        delegate?.cancelRequest(self)

        return self
    }

    @discardableResult
    public func suspend() -> Self {
        guard state.canTransitionTo(.suspended) else { return self }

        state = .suspended

        delegate?.suspendRequest(self)

        return self
    }

    @discardableResult
    public func resume() -> Self {
        guard state.canTransitionTo(.resumed) else { return self }

        state = .resumed

        delegate?.resumeRequest(self)

        return self
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

    /// Sets a closure to be called periodically during the lifecycle of the `Request` as data is read from the server.
    ///
    /// - parameter queue:   The dispatch queue to execute the closure on.
    /// - parameter closure: The code to be executed periodically as data is read from the server.
    ///
    /// - returns: The request.
    @discardableResult
    open func downloadProgress(queue: DispatchQueue = DispatchQueue.main, closure: @escaping ProgressHandler) -> Self {
        underlyingQueue.async { self.downloadProgressHandler = (closure, queue) }

        return self
    }

    // MARK: Upload Progress

    /// Sets a closure to be called periodically during the lifecycle of the `UploadRequest` as data is sent to
    /// the server.
    ///
    /// After the data is sent to the server, the `progress(queue:closure:)` APIs can be used to monitor the progress
    /// of data being read from the server.
    ///
    /// - parameter queue:   The dispatch queue to execute the closure on.
    /// - parameter closure: The code to be executed periodically as data is sent to the server.
    ///
    /// - returns: The request.
    @discardableResult
    open func uploadProgress(queue: DispatchQueue = DispatchQueue.main, closure: @escaping ProgressHandler) -> Self {
        underlyingQueue.async { self.uploadProgressHandler = (closure, queue) }

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
    let convertible: URLRequestConvertible

    private(set) var data: Data?

    init(id: UUID = UUID(),
         convertible: URLRequestConvertible,
         underlyingQueue: DispatchQueue,
         serializationQueue: DispatchQueue? = nil,
         eventMonitor: RequestEventMonitor?,
         delegate: RequestDelegate) {
        self.convertible = convertible

        super.init(id: id,
                   underlyingQueue: underlyingQueue,
                   serializationQueue: serializationQueue,
                   eventMonitor: eventMonitor,
                   delegate: delegate)
    }

    override func reset() {
        super.reset()

        data = nil
    }

    func didRecieve(data: Data) {
        if self.data == nil {
            self.data = data
        } else {
            self.data?.append(data)
        }

        updateDownloadProgress()
    }

    func updateDownloadProgress() {
        let totalBytesRecieved = Int64(self.data?.count ?? 0)
        let totalBytesExpected = task?.response?.expectedContentLength ?? NSURLSessionTransferSizeUnknown

        downloadProgress.totalUnitCount = totalBytesExpected
        downloadProgress.completedUnitCount = totalBytesRecieved

        downloadProgressHandler?.queue.async { self.downloadProgressHandler?.handler(self.downloadProgress) }
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
        /// A `DownloadOptions` flag that creates intermediate directories for the destination URL if specified.
        public static let createIntermediateDirectories = Options(rawValue: 1 << 0)

        /// A `DownloadOptions` flag that removes a previous file from the destination URL if specified.
        public static let removePreviousFile = Options(rawValue: 1 << 1)

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
    }

    /// A closure executed once a download request has successfully completed in order to determine where to move the
    /// temporary file written to during the download process. The closure takes two arguments: the temporary file URL
    /// and the URL response, and returns a two arguments: the file URL where the temporary file should be moved and
    /// the options defining how the file should be moved.
    public typealias Destination = (_ temporaryURL: URL,
                                    _ response: HTTPURLResponse) -> (destinationURL: URL, options: Options)

    // MARK: Destination

    /// Creates a download file destination closure which uses the default file manager to move the temporary file to a
    /// file URL in the first available directory with the specified search path directory and search path domain mask.
    ///
    /// - parameter directory: The search path directory. `.documentDirectory` by default.
    /// - parameter domain:    The search path domain mask. `.userDomainMask` by default.
    ///
    /// - returns: A download file destination closure.
    open class func suggestedDownloadDestination(for directory: FileManager.SearchPathDirectory = .documentDirectory,
                                                 in domain: FileManager.SearchPathDomainMask = .userDomainMask,
                                                 options: Options = []) -> Destination {
        return { (temporaryURL, response) in
            let directoryURLs = FileManager.default.urls(for: directory, in: domain)
            let url = directoryURLs.first?.appendingPathComponent(response.suggestedFilename!) ?? temporaryURL

            return (url, options)
        }
    }

    public enum Downloadable {
        case request(URLRequestConvertible)
        case resumeData(Data)
    }

    // MARK: Initial State
    let downloadable: Downloadable
    private let destination: Destination?

    // MARK: Updated State

    open internal(set) var resumeData: Data?
    open internal(set) var temporaryURL: URL?
    open internal(set) var destinationURL: URL?
    open var fileURL: URL? {
        return destinationURL ?? temporaryURL
    }

    // MARK: Init

    init(id: UUID = UUID(),
         downloadable: Downloadable,
         underlyingQueue: DispatchQueue,
         serializationQueue: DispatchQueue? = nil,
         eventMonitor: RequestEventMonitor?,
         delegate: RequestDelegate,
         destination: Destination? = nil) {
        self.downloadable = downloadable
        self.destination = destination

        super.init(id: id,
                   underlyingQueue: underlyingQueue,
                   serializationQueue: serializationQueue,
                   eventMonitor: eventMonitor,
                   delegate: delegate)
    }

    override func reset() {
        super.reset()

        temporaryURL = nil
        destinationURL = nil
        resumeData = nil
    }

    func didComplete(task: URLSessionTask, with url: URL) {
        temporaryURL = url

        guard let destination = destination, let response = response else { return }

        let (destinationURL, options) = destination(url, response)
        self.destinationURL = destinationURL
        // TODO: Inject FileManager?
        do {
            if options.contains(.removePreviousFile), FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }

            if options.contains(.createIntermediateDirectories) {
                let directory = destinationURL.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            }

            try FileManager.default.moveItem(at: url, to: destinationURL)
        } catch {
            self.error = error
        }
    }

    func updateDownloadProgress(bytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        downloadProgress.totalUnitCount = totalBytesExpectedToWrite
        downloadProgress.completedUnitCount += bytesWritten

        downloadProgressHandler?.queue.async { self.downloadProgressHandler?.handler(self.downloadProgress) }
    }

    override func task(for request: URLRequest, using session: URLSession) -> URLSessionTask {
        return session.downloadTask(with: request)
    }

    open func task(forResumeData data: Data, using session: URLSession) -> URLSessionTask {
        return session.downloadTask(withResumeData: data)
    }

    @discardableResult
    public override func cancel() -> Self {
        // TODO: EventMonitor?
        guard state.canTransitionTo(.cancelled) else { return self }

        state = .cancelled

        delegate?.cancelDownloadRequest(self) { self.resumeData = $0 }

        return self
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
    public enum Uploadable {
        case data(Data)
        case file(URL, shouldRemove: Bool)
        case stream(InputStream)
    }

    // MARK: - Initial State

    let upload: UploadableConvertible

    // MARK: - Updated State

    public var uploadable: Uploadable?

    init(id: UUID = UUID(),
         convertible: UploadConvertible,
         underlyingQueue: DispatchQueue,
         serializationQueue: DispatchQueue? = nil,
         eventMonitor: RequestEventMonitor?,
         delegate: RequestDelegate) {
        self.upload = convertible

        super.init(id: id,
                   convertible: convertible,
                   underlyingQueue: underlyingQueue,
                   serializationQueue: serializationQueue,
                   eventMonitor: eventMonitor,
                   delegate: delegate)

        // Automatically remove temporary upload files (e.g. multipart form data)
        internalQueue.addOperation {
            guard
                let uploadable = self.uploadable,
                case let .file(url, shouldRemove) = uploadable,
                shouldRemove else { return }

            // TODO: Abstract file manager
            try? FileManager.default.removeItem(at: url)
        }
    }

    func didCreateUploadable(_ uploadable: Uploadable) {
        // TODO: Event Monitor here.

        self.uploadable = uploadable
    }

    func didFailToCreateUploadable(with error: Error) {
        // TODO: Event monitor
        self.error = error

        retryOrFinish(error: error)
    }

    override func task(for request: URLRequest, using session: URLSession) -> URLSessionTask {
        guard let uploadable = uploadable else {
            fatalError("Attempting to create a URLSessionUploadTask when Uploadable value doesn't exist.")
        }

        switch uploadable {
        case let .data(data): return session.uploadTask(with: request, from: data)
        case let .file(url, _): return session.uploadTask(with: request, fromFile: url)
        case .stream: return session.uploadTask(withStreamedRequest: request)
        }
    }

    func inputStream() -> InputStream {
        guard let uploadable = uploadable else {
            fatalError("Attempting to access the input stream but the uploadable doesn't exist.")
        }

        guard case let .stream(stream) = uploadable else {
            fatalError("Attempted to access the stream of an UploadRequest that wasn't created with one.")
        }

        return stream
    }
}

protocol UploadableConvertible {
    func createUploadable() throws -> UploadRequest.Uploadable
}

extension UploadRequest.Uploadable: UploadableConvertible {
    func createUploadable() throws -> UploadRequest.Uploadable {
        return self
    }
}

protocol UploadConvertible: UploadableConvertible & URLRequestConvertible { }

