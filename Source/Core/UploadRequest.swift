//
//  UploadRequest.swift
//
//  Copyright (c) 2014-2024 Alamofire Software Foundation (http://alamofire.org/)
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

/// `DataRequest` subclass which handles `Data` upload from memory, file, or stream using `URLSessionUploadTask`.
public final class UploadRequest: DataRequest, @unchecked Sendable {
    /// Type describing the origin of the upload, whether `Data`, file, or stream.
    public enum Uploadable: @unchecked Sendable { // Must be @unchecked Sendable due to InputStream.
        /// Upload from the provided `Data` value.
        case data(Data)
        /// Upload from the provided file `URL`, as well as a `Bool` determining whether the source file should be
        /// automatically removed once uploaded.
        case file(URL, shouldRemove: Bool)
        /// Upload from the provided `InputStream`.
        case stream(InputStream)
    }

    // MARK: Initial State

    /// The `UploadableConvertible` value used to produce the `Uploadable` value for this instance.
    public let upload: any UploadableConvertible

    /// `FileManager` used to perform cleanup tasks, including the removal of multipart form encoded payloads written
    /// to disk.
    public let fileManager: FileManager

    // MARK: Mutable State

    /// `Uploadable` value used by the instance.
    public var uploadable: Uploadable?

    /// Creates an `UploadRequest` using the provided parameters.
    ///
    /// - Parameters:
    ///   - id:                 `UUID` used for the `Hashable` and `Equatable` implementations. `UUID()` by default.
    ///   - convertible:        `UploadConvertible` value used to determine the type of upload to be performed.
    ///   - underlyingQueue:    `DispatchQueue` on which all internal `Request` work is performed.
    ///   - serializationQueue: `DispatchQueue` on which all serialization work is performed. By default targets
    ///                         `underlyingQueue`, but can be passed another queue from a `Session`.
    ///   - eventMonitor:       `EventMonitor` called for event callbacks from internal `Request` actions.
    ///   - interceptor:        `RequestInterceptor` used throughout the request lifecycle.
    ///   - fileManager:        `FileManager` used to perform cleanup tasks, including the removal of multipart form
    ///                         encoded payloads written to disk.
    ///   - delegate:           `RequestDelegate` that provides an interface to actions not performed by the `Request`.
    init(id: UUID = UUID(),
         convertible: any UploadConvertible,
         underlyingQueue: DispatchQueue,
         serializationQueue: DispatchQueue,
         eventMonitor: (any EventMonitor)?,
         interceptor: (any RequestInterceptor)?,
         fileManager: FileManager,
         delegate: any RequestDelegate) {
        upload = convertible
        self.fileManager = fileManager

        super.init(id: id,
                   convertible: convertible,
                   underlyingQueue: underlyingQueue,
                   serializationQueue: serializationQueue,
                   eventMonitor: eventMonitor,
                   interceptor: interceptor,
                   delegate: delegate)
    }

    /// Called when the `Uploadable` value has been created from the `UploadConvertible`.
    ///
    /// - Parameter uploadable: The `Uploadable` that was created.
    func didCreateUploadable(_ uploadable: Uploadable) {
        self.uploadable = uploadable

        eventMonitor?.request(self, didCreateUploadable: uploadable)
    }

    /// Called when the `Uploadable` value could not be created.
    ///
    /// - Parameter error: `AFError` produced by the failure.
    func didFailToCreateUploadable(with error: AFError) {
        self.error = error

        eventMonitor?.request(self, didFailToCreateUploadableWithError: error)

        retryOrFinish(error: error)
    }

    override func task(for request: URLRequest, using session: URLSession) -> URLSessionTask {
        guard let uploadable else {
            fatalError("Attempting to create a URLSessionUploadTask when Uploadable value doesn't exist.")
        }

        switch uploadable {
        case let .data(data): return session.uploadTask(with: request, from: data)
        case let .file(url, _): return session.uploadTask(with: request, fromFile: url)
        case .stream: return session.uploadTask(withStreamedRequest: request)
        }
    }

    override func reset() {
        // Uploadable must be recreated on every retry.
        uploadable = nil

        super.reset()
    }

    /// Produces the `InputStream` from `uploadable`, if it can.
    ///
    /// - Note: Calling this method with a non-`.stream` `Uploadable` is a logic error and will crash.
    ///
    /// - Returns: The `InputStream`.
    func inputStream() -> InputStream {
        guard let uploadable else {
            fatalError("Attempting to access the input stream but the uploadable doesn't exist.")
        }

        guard case let .stream(stream) = uploadable else {
            fatalError("Attempted to access the stream of an UploadRequest that wasn't created with one.")
        }

        eventMonitor?.request(self, didProvideInputStream: stream)

        return stream
    }

    override public func cleanup() {
        defer { super.cleanup() }

        guard
            let uploadable,
            case let .file(url, shouldRemove) = uploadable,
            shouldRemove
        else { return }

        try? fileManager.removeItem(at: url)
    }
}

/// A type that can produce an `UploadRequest.Uploadable` value.
public protocol UploadableConvertible: Sendable {
    /// Produces an `UploadRequest.Uploadable` value from the instance.
    ///
    /// - Returns: The `UploadRequest.Uploadable`.
    /// - Throws:  Any `Error` produced during creation.
    func createUploadable() throws -> UploadRequest.Uploadable
}

extension UploadRequest.Uploadable: UploadableConvertible {
    public func createUploadable() throws -> UploadRequest.Uploadable {
        self
    }
}

/// A type that can be converted to an upload, whether from an `UploadRequest.Uploadable` or `URLRequestConvertible`.
public protocol UploadConvertible: UploadableConvertible & URLRequestConvertible {}
