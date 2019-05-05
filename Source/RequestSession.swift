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

public protocol RequestSession {
    func request(_ url: URLConvertible,
                 method: HTTPMethod,
                 parameters: Parameters?,
                 encoding: ParameterEncoding,
                 headers: HTTPHeaders?,
                 interceptor: RequestInterceptor?) -> DataRequest

    func request<Parameters: Encodable>(_ url: URLConvertible,
                                        method: HTTPMethod,
                                        parameters: Parameters?,
                                        encoder: ParameterEncoder,
                                        headers: HTTPHeaders?,
                                        interceptor: RequestInterceptor?) -> DataRequest

    func request(_ convertible: URLRequestConvertible, interceptor: RequestInterceptor?) -> DataRequest
}

extension RequestSession {
    public func request(_ url: URLConvertible,
                        method: HTTPMethod = .get,
                        parameters: Parameters? = nil,
                        encoding: ParameterEncoding = URLEncoding.default,
                        headers: HTTPHeaders? = nil,
                        interceptor: RequestInterceptor? = nil) -> DataRequest {
        let convertible = RequestConvertible(url: url,
                                             method: method,
                                             parameters: parameters,
                                             encoding: encoding,
                                             headers: headers)

        return request(convertible, interceptor: interceptor)
    }

    public func request<Parameters: Encodable>(_ url: URLConvertible,
                                               method: HTTPMethod = .get,
                                               parameters: Parameters? = nil,
                                               encoder: ParameterEncoder = JSONParameterEncoder.default,
                                               headers: HTTPHeaders? = nil,
                                               interceptor: RequestInterceptor? = nil) -> DataRequest {
        let convertible = RequestEncodableConvertible(url: url,
                                                      method: method,
                                                      parameters: parameters,
                                                      encoder: encoder,
                                                      headers: headers)

        return request(convertible, interceptor: interceptor)
    }
}
