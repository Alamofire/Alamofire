//
//  Session.swift
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

public protocol DownloadSession {
    func download(_ convertible: URLConvertible,
                  method: HTTPMethod,
                  parameters: Parameters?,
                  encoding: ParameterEncoding,
                  headers: HTTPHeaders?,
                  interceptor: RequestInterceptor?,
                  to destination: DownloadRequest.Destination?) -> DownloadRequest

    func download<Parameters: Encodable>(_ convertible: URLConvertible,
                                         method: HTTPMethod,
                                         parameters: Parameters?,
                                         encoder: ParameterEncoder,
                                         headers: HTTPHeaders?,
                                         interceptor: RequestInterceptor?,
                                         to destination: DownloadRequest.Destination?) -> DownloadRequest

    func download(_ convertible: URLRequestConvertible,
                  interceptor: RequestInterceptor?,
                  to destination: DownloadRequest.Destination?) -> DownloadRequest

    func download(resumingWith data: Data,
                  interceptor: RequestInterceptor?,
                  to destination: DownloadRequest.Destination?) -> DownloadRequest
}

extension DownloadSession {
    public func download(_ convertible: URLConvertible,
                         method: HTTPMethod = .get,
                         parameters: Parameters? = nil,
                         encoding: ParameterEncoding = URLEncoding.default,
                         headers: HTTPHeaders? = nil,
                         interceptor: RequestInterceptor? = nil,
                         to destination: DownloadRequest.Destination? = nil) -> DownloadRequest {
        let convertible = RequestConvertible(url: convertible,
                                             method: method,
                                             parameters: parameters,
                                             encoding: encoding,
                                             headers: headers)

        return download(convertible, interceptor: interceptor, to: destination)
    }

    public func download<Parameters: Encodable>(_ convertible: URLConvertible,
                                                method: HTTPMethod = .get,
                                                parameters: Parameters? = nil,
                                                encoder: ParameterEncoder = JSONParameterEncoder.default,
                                                headers: HTTPHeaders? = nil,
                                                interceptor: RequestInterceptor? = nil,
                                                to destination: DownloadRequest.Destination? = nil) -> DownloadRequest {
        let convertible = RequestEncodableConvertible(url: convertible,
                                                      method: method,
                                                      parameters: parameters,
                                                      encoder: encoder,
                                                      headers: headers)

        return download(convertible, interceptor: interceptor, to: destination)
    }
}
