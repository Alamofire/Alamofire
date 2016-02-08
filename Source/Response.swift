// Response.swift
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

/// Used to store all response data returned from a completed `Request`.
public struct Response<Value, Error: ErrorType> {
    /// The URL request sent to the server.
    public let request: NSURLRequest?

    /// The server's response to the URL request.
    public let response: NSHTTPURLResponse?

    /// The data returned by the server.
    public let data: NSData?

    /// The result of response serialization.
    public let result: Result<Value, Error>

    /// The timeline of the complete lifecycle of the `Request`.
    public let timeline: Timeline

    /**
        Initializes the `Response` instance with the specified URL request, URL response, server data and response
        serialization result.
    
        - parameter request:  The URL request sent to the server.
        - parameter response: The server's response to the URL request.
        - parameter data:     The data returned by the server.
        - parameter result:   The result of response serialization.
        - parameter timeline: The timeline of the complete lifecycle of the `Request`. Defaults to `Timeline()`.

        - returns: the new `Response` instance.
    */
    public init(
        request: NSURLRequest?,
        response: NSHTTPURLResponse?,
        data: NSData?,
        result: Result<Value, Error>,
        timeline: Timeline = Timeline())
    {
        self.request = request
        self.response = response
        self.data = data
        self.result = result
        self.timeline = timeline
    }
}

// MARK: - CustomStringConvertible

extension Response: CustomStringConvertible {
    /// The textual representation used when written to an output stream, which includes whether the result was a
    /// success or failure.
    public var description: String {
        return result.debugDescription
    }
}

// MARK: - CustomDebugStringConvertible

extension Response: CustomDebugStringConvertible {
    /// The debug textual representation used when written to an output stream, which includes the URL request, the URL
    /// response, the server data and the response serialization result.
    public var debugDescription: String {
        var output: [String] = []

        output.append(request != nil ? "[Request]: \(request!)" : "[Request]: nil")
        output.append(response != nil ? "[Response]: \(response!)" : "[Response]: nil")
        output.append("[Data]: \(data?.length ?? 0) bytes")
        output.append("[Result]: \(result.debugDescription)")
        output.append("[Timeline]: \(timeline.debugDescription)")

        return output.joinWithSeparator("\n")
    }
}
