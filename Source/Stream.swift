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
        case stream(String, Int)
        case netService(Foundation.NetService)
    }

    private func stream(_ streamable: Streamable) -> Request {
        var streamTask: URLSessionStreamTask!

        switch streamable {
        case .stream(let hostName, let port):
            queue.sync {
                streamTask = self.session.streamTask(withHostName: hostName, port: port)
            }
        case .netService(let netService):
            queue.sync {
                streamTask = self.session.streamTask(with: netService)
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

        - returns: The created stream request.
    */
    public func stream(hostName: String, port: Int) -> Request {
        return stream(.stream(hostName, port))
    }

    /**
        Creates a request for bidirectional streaming with the given `NSNetService`.

        - parameter netService: The net service used to identify the endpoint.

        - returns: The created stream request.
    */
    public func stream(netService: NetService) -> Request {
        return stream(.netService(netService))
    }
}

// MARK: -

@available(iOS 9.0, OSX 10.11, tvOS 9.0, *)
extension Manager.SessionDelegate: URLSessionStreamDelegate {

    // MARK: Override Closures

    /// Overrides default behavior for NSURLSessionStreamDelegate method `URLSession:readClosedForStreamTask:`.
    public var streamTaskReadClosed: ((Foundation.URLSession, URLSessionStreamTask) -> Void)? {
        get {
            return _streamTaskReadClosed as? (Foundation.URLSession, URLSessionStreamTask) -> Void
        }
        set {
            _streamTaskReadClosed = newValue
        }
    }

    /// Overrides default behavior for NSURLSessionStreamDelegate method `URLSession:writeClosedForStreamTask:`.
    public var streamTaskWriteClosed: ((Foundation.URLSession, URLSessionStreamTask) -> Void)? {
        get {
            return _streamTaskWriteClosed as? (Foundation.URLSession, URLSessionStreamTask) -> Void
        }
        set {
            _streamTaskWriteClosed = newValue
        }
    }

    /// Overrides default behavior for NSURLSessionStreamDelegate method `URLSession:betterRouteDiscoveredForStreamTask:`.
    public var streamTaskBetterRouteDiscovered: ((Foundation.URLSession, URLSessionStreamTask) -> Void)? {
        get {
            return _streamTaskBetterRouteDiscovered as? (Foundation.URLSession, URLSessionStreamTask) -> Void
        }
        set {
            _streamTaskBetterRouteDiscovered = newValue
        }
    }

    /// Overrides default behavior for NSURLSessionStreamDelegate method `URLSession:streamTask:didBecomeInputStream:outputStream:`.
    public var streamTaskDidBecomeInputStream: ((Foundation.URLSession, URLSessionStreamTask, InputStream, NSOutputStream) -> Void)? {
        get {
            return _streamTaskDidBecomeInputStream as? (Foundation.URLSession, URLSessionStreamTask, InputStream, NSOutputStream) -> Void
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
    public func urlSession(_ session: URLSession, readClosedFor streamTask: URLSessionStreamTask) {
        streamTaskReadClosed?(session, streamTask)
    }

    /**
        Tells the delegate that the write side of the connection has been closed.

        - parameter session:    The session.
        - parameter streamTask: The stream task.
    */
    public func urlSession(_ session: URLSession, writeClosedFor streamTask: URLSessionStreamTask) {
        streamTaskWriteClosed?(session, streamTask)
    }

    /**
        Tells the delegate that the system has determined that a better route to the host is available.

        - parameter session:    The session.
        - parameter streamTask: The stream task.
    */
    public func urlSession(_ session: URLSession, betterRouteDiscoveredFor streamTask: URLSessionStreamTask) {
        streamTaskBetterRouteDiscovered?(session, streamTask)
    }

    /**
        Tells the delegate that the stream task has been completed and provides the unopened stream objects.

        - parameter session:      The session.
        - parameter streamTask:   The stream task.
        - parameter inputStream:  The new input stream.
        - parameter outputStream: The new output stream.
    */
    public func urlSession(
        _ session: URLSession,
        streamTask: URLSessionStreamTask,
        didBecome inputStream: InputStream,
        outputStream: NSOutputStream)
    {
        streamTaskDidBecomeInputStream?(session, streamTask, inputStream, outputStream)
    }
}

#endif
