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

public protocol UploadSession {
    func upload(_ data: Data,
                to convertible: URLConvertible,
                method: HTTPMethod,
                headers: HTTPHeaders?,
                interceptor: RequestInterceptor?) -> UploadRequest

    func upload(_ data: Data,
                with convertible: URLRequestConvertible,
                interceptor: RequestInterceptor?) -> UploadRequest

    func upload(_ fileURL: URL,
                to convertible: URLConvertible,
                method: HTTPMethod,
                headers: HTTPHeaders?,
                interceptor: RequestInterceptor?) -> UploadRequest

    func upload(_ fileURL: URL,
                with convertible: URLRequestConvertible,
                interceptor: RequestInterceptor?) -> UploadRequest

    func upload(_ stream: InputStream,
                to convertible: URLConvertible,
                method: HTTPMethod,
                headers: HTTPHeaders?,
                interceptor: RequestInterceptor?) -> UploadRequest

    func upload(_ stream: InputStream,
                with convertible: URLRequestConvertible,
                interceptor: RequestInterceptor?) -> UploadRequest

    func upload(multipartFormData: @escaping (MultipartFormData) -> Void,
                usingThreshold encodingMemoryThreshold: UInt64,
                fileManager: FileManager,
                to url: URLConvertible,
                method: HTTPMethod,
                headers: HTTPHeaders?,
                interceptor: RequestInterceptor?) -> UploadRequest

    func upload(multipartFormData: MultipartFormData,
                usingThreshold encodingMemoryThreshold: UInt64,
                with request: URLRequestConvertible,
                interceptor: RequestInterceptor?) -> UploadRequest

    func upload(_ uploadable: UploadRequest.Uploadable,
                with convertible: URLRequestConvertible,
                interceptor: RequestInterceptor?) -> UploadRequest

    func upload(_ upload: UploadConvertible, interceptor: RequestInterceptor?) -> UploadRequest
}

public struct ParameterlessRequestConvertible: URLRequestConvertible {
    let url: URLConvertible
    let method: HTTPMethod
    let headers: HTTPHeaders?

    public func asURLRequest() throws -> URLRequest {
        return try URLRequest(url: url, method: method, headers: headers)
    }
}

public struct Upload: UploadConvertible {
    let request: URLRequestConvertible
    let uploadable: UploadableConvertible

    public func createUploadable() throws -> UploadRequest.Uploadable {
        return try uploadable.createUploadable()
    }

    public func asURLRequest() throws -> URLRequest {
        return try request.asURLRequest()
    }
}

extension UploadSession {
    public func upload(_ data: Data,
                       to convertible: URLConvertible,
                       method: HTTPMethod = .post,
                       headers: HTTPHeaders? = nil,
                       interceptor: RequestInterceptor? = nil) -> UploadRequest {
        let convertible = ParameterlessRequestConvertible(url: convertible, method: method, headers: headers)

        return upload(data, with: convertible, interceptor: interceptor)
    }

    public func upload(_ data: Data,
                       with convertible: URLRequestConvertible,
                       interceptor: RequestInterceptor? = nil) -> UploadRequest {
        return upload(.data(data), with: convertible, interceptor: interceptor)
    }

    public func upload(_ fileURL: URL,
                       to convertible: URLConvertible,
                       method: HTTPMethod = .post,
                       headers: HTTPHeaders? = nil,
                       interceptor: RequestInterceptor? = nil) -> UploadRequest {
        let convertible = ParameterlessRequestConvertible(url: convertible, method: method, headers: headers)

        return upload(fileURL, with: convertible, interceptor: interceptor)
    }

    public func upload(_ fileURL: URL,
                       with convertible: URLRequestConvertible,
                       interceptor: RequestInterceptor? = nil) -> UploadRequest {
        return upload(.file(fileURL, shouldRemove: false), with: convertible, interceptor: interceptor)
    }

    public func upload(_ stream: InputStream,
                       to convertible: URLConvertible,
                       method: HTTPMethod = .post,
                       headers: HTTPHeaders? = nil,
                       interceptor: RequestInterceptor? = nil) -> UploadRequest {
        let convertible = ParameterlessRequestConvertible(url: convertible, method: method, headers: headers)

        return upload(stream, with: convertible, interceptor: interceptor)
    }

    public func upload(_ stream: InputStream,
                       with convertible: URLRequestConvertible,
                       interceptor: RequestInterceptor? = nil) -> UploadRequest {
        return upload(.stream(stream), with: convertible, interceptor: interceptor)
    }

    public func upload(multipartFormData: @escaping (MultipartFormData) -> Void,
                       usingThreshold encodingMemoryThreshold: UInt64 = MultipartFormData.encodingMemoryThreshold,
                       fileManager: FileManager = .default,
                       to url: URLConvertible,
                       method: HTTPMethod = .post,
                       headers: HTTPHeaders? = nil,
                       interceptor: RequestInterceptor? = nil) -> UploadRequest {
        let convertible = ParameterlessRequestConvertible(url: url, method: method, headers: headers)

        let formData = MultipartFormData(fileManager: fileManager)
        multipartFormData(formData)

        return upload(multipartFormData: formData,
                      usingThreshold: encodingMemoryThreshold,
                      with: convertible,
                      interceptor: interceptor)
    }

    public func upload(_ uploadable: UploadRequest.Uploadable,
                       with convertible: URLRequestConvertible,
                       interceptor: RequestInterceptor?) -> UploadRequest {
        let uploadable = Upload(request: convertible, uploadable: uploadable)

        return upload(uploadable, interceptor: interceptor)
    }
}
