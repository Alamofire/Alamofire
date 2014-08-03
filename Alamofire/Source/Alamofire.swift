// Alamofire.swift
//
// Copyright (c) 2014 Alamofire (http://alamofire.org)
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

// MARK: - Request

public func request(method: Method, URL: String, parameters: [String: AnyObject]? = nil, encoding: ParameterEncoding = .URL) -> Request {
    var mutableRequest = NSMutableURLRequest(URL: NSURL(string: URL))
    mutableRequest.HTTPMethod = method.toRaw()
    
    return Manager.sharedInstance.request(encoding.encode(URLRequest(method, URL), parameters: parameters).0)
}

// MARK: - Upload

public func upload(method: Method, URL: String, #file: NSURL) -> Request {
    return Manager.sharedInstance.upload(URLRequest(method, URL), file: file)
}

public func upload(method: Method, URL: String, #data: NSData) -> Request {
    return Manager.sharedInstance.upload(URLRequest(method, URL), data: data)
}

public func upload(method: Method, URL: String, #stream: NSInputStream) -> Request {
    return Manager.sharedInstance.upload(URLRequest(method, URL), stream: stream)
}

// MARK: - Download

public func download(method: Method, URL: String, #destination: (NSURL, NSHTTPURLResponse) -> (NSURL)) -> Request {
    return Manager.sharedInstance.download(URLRequest(method, URL), destination: destination)
}

public func download(resumeData data: NSData, #destination: (NSURL, NSHTTPURLResponse) -> (NSURL)) -> Request {
    return Manager.sharedInstance.download(data, destination: destination)
}

// MARK: - Private

private func URLRequest(method: Method, URL: String) -> NSURLRequest {
    let mutableURLRequest = NSMutableURLRequest(URL: NSURL(string: URL))
    mutableURLRequest.HTTPMethod = method.toRaw()
    
    return mutableURLRequest
}
