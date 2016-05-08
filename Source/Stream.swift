//
//  Stream.swift
//
//  Copyright (c) 2014-2016 Alamofire Software Foundation (http://alamofire.org/)
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

#if !os(watchOS)

@available(iOS 9.0, OSX 10.11, tvOS 9.0, *)
extension Manager {
    private enum Streamable {
        case Stream(String, Int)
        case NetService(NSNetService)
    }

    private func stream(streamable: Streamable) -> Request {
        var streamTask: NSURLSessionStreamTask!

        switch streamable {
        case .Stream(let hostName, let port):
            dispatch_sync(queue) {
                streamTask = self.session.streamTaskWithHostName(hostName, port: port)
            }
        case .NetService(let netService):
            dispatch_sync(queue) {
                streamTask = self.session.streamTaskWithNetService(netService)
            }
        }

        let request = Request(session: session, task: streamTask)

        delegate[request.delegate.task] = request.delegate

        if startRequestsImmediately {
            request.resume()
        }

        return request
    }

    /**
        Creates a request for bidirectional streaming with the given hostname and port.

        - parameter hostName: The hostname of the server to connect to.
        - parameter port:     The port of the server to connect to.

        :returns: The created stream request.
    */
    public func stream(hostName hostName: String, port: Int) -> Request {
        return stream(.Stream(hostName, port))
    }

    /**
        Creates a request for bidirectional streaming with the given `NSNetService`.

        - parameter netService: The net service used to identify the endpoint.

        - returns: The created stream request.
    */
    public func stream(netService netService: NSNetService) -> Request {
        return stream(.NetService(netService))
    }
}

// MARK: -

@available(iOS 9.0, OSX 10.11, tvOS 9.0, *)
extension Manager.SessionDelegate: NSURLSessionStreamDelegate {

    // MARK: Override Closures

    /// Overrides default behavior for NSURLSessionStreamDelegate method `URLSession:readClosedForStreamTask:`.
    public var streamTaskReadClosed: ((NSURLSession, NSURLSessionStreamTask) -> Void)? {
        get {
            return _streamTaskReadClosed as? (NSURLSession, NSURLSessionStreamTask) -> Void
        }
        set {
            _streamTaskReadClosed = newValue
        }
    }

    /// Overrides default behavior for NSURLSessionStreamDelegate method `URLSession:writeClosedForStreamTask:`.
    public var streamTaskWriteClosed: ((NSURLSession, NSURLSessionStreamTask) -> Void)? {
        get {
            return _streamTaskWriteClosed as? (NSURLSession, NSURLSessionStreamTask) -> Void
        }
        set {
            _streamTaskWriteClosed = newValue
        }
    }

    /// Overrides default behavior for NSURLSessionStreamDelegate method `URLSession:betterRouteDiscoveredForStreamTask:`.
    public var streamTaskBetterRouteDiscovered: ((NSURLSession, NSURLSessionStreamTask) -> Void)? {
        get {
            return _streamTaskBetterRouteDiscovered as? (NSURLSession, NSURLSessionStreamTask) -> Void
        }
        set {
            _streamTaskBetterRouteDiscovered = newValue
        }
    }

    /// Overrides default behavior for NSURLSessionStreamDelegate method `URLSession:streamTask:didBecomeInputStream:outputStream:`.
    public var streamTaskDidBecomeInputStream: ((NSURLSession, NSURLSessionStreamTask, NSInputStream, NSOutputStream) -> Void)? {
        get {
            return _streamTaskDidBecomeInputStream as? (NSURLSession, NSURLSessionStreamTask, NSInputStream, NSOutputStream) -> Void
        }
        set {
            _streamTaskDidBecomeInputStream = newValue
        }
    }

    // MARK: Delegate Methods

    /**
        Tells the delegate that the read side of the connection has been closed.

        - parameter session:    The session.
        - parameter streamTask: The stream task.
    */
    public func URLSession(session: NSURLSession, readClosedForStreamTask streamTask: NSURLSessionStreamTask) {
        streamTaskReadClosed?(session, streamTask)
    }

    /**
        Tells the delegate that the write side of the connection has been closed.

        - parameter session:    The session.
        - parameter streamTask: The stream task.
    */
    public func URLSession(session: NSURLSession, writeClosedForStreamTask streamTask: NSURLSessionStreamTask) {
        streamTaskWriteClosed?(session, streamTask)
    }

    /**
        Tells the delegate that the system has determined that a better route to the host is available.

        - parameter session:    The session.
        - parameter streamTask: The stream task.
    */
    public func URLSession(session: NSURLSession, betterRouteDiscoveredForStreamTask streamTask: NSURLSessionStreamTask) {
        streamTaskBetterRouteDiscovered?(session, streamTask)
    }

    /**
        Tells the delegate that the stream task has been completed and provides the unopened stream objects.

        - parameter session:      The session.
        - parameter streamTask:   The stream task.
        - parameter inputStream:  The new input stream.
        - parameter outputStream: The new output stream.
    */
    public func URLSession(
        session: NSURLSession,
        streamTask: NSURLSessionStreamTask,
        didBecomeInputStream inputStream: NSInputStream,
        outputStream: NSOutputStream)
    {
        streamTaskDidBecomeInputStream?(session, streamTask, inputStream, outputStream)
    }
}

#endif
