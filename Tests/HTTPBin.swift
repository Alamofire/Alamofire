//
//  HTTPBin.swift
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

import Alamofire
import Foundation

extension String {
    static let httpBinURLString = "https://httpbin.org"
}

extension URL {
    static func makeHTTPBinURL(path: String = "get") -> URL {
        let url = URL(string: .httpBinURLString)!
        return url.appendingPathComponent(path)
    }
}

extension URLRequest {
    static func makeHTTPBinRequest(path: String = "get",
                                   method: HTTPMethod = .get,
                                   headers: HTTPHeaders = .init(),
                                   timeout: TimeInterval = 60,
                                   cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy) -> URLRequest {
        var request = URLRequest(url: .makeHTTPBinURL(path: path))
        request.httpMethod = method.rawValue
        request.headers = headers
        request.timeoutInterval = timeout
        request.cachePolicy = cachePolicy

        return request
    }
}

extension Data {
    var asString: String {
        String(decoding: self, as: UTF8.self)
    }
}

struct HTTPBinResponse: Decodable {
    let headers: [String: String]
    let origin: String
    let url: String
    let data: String?
    let form: [String: String]?
    let args: [String: String]
}

struct HTTPBinParameters: Encodable {
    static let `default` = HTTPBinParameters(property: "property")

    let property: String
}
