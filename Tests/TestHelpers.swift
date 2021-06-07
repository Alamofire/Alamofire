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
    static let nonexistentDomain = "https://nonexistent-domain.org"
}

extension URL {
    static let nonexistentDomain = URL(string: .nonexistentDomain)!
}

struct Endpoint {
    enum Scheme: String {
        case http, https

        var port: Int {
            switch self {
            case .http: return 80
            case .https: return 443
            }
        }
    }

    enum Host: String {
        case localhost = "127.0.0.1"
        case httpBin = "httpbin.org"

        func port(for scheme: Scheme) -> Int {
            switch self {
            case .localhost: return 8080
            case .httpBin: return scheme.port
            }
        }
    }

    enum Path {
        case basicAuth(username: String, password: String)
        case bytes(count: Int)
        case chunked(count: Int)
        case compression(Compression)
        case delay(interval: Int)
        case digestAuth(qop: String = "auth", username: String, password: String)
        case download(count: Int)
        case hiddenBasicAuth(username: String, password: String)
        case image(Image)
        case ip
        case method(HTTPMethod)
        case payloads(count: Int)
        case redirect(count: Int)
        case redirectTo
        case responseHeaders
        case status(Int)
        case stream(count: Int)
        case xml

        var string: String {
            switch self {
            case let .basicAuth(username: username, password: password):
                return "/basic-auth/\(username)/\(password)"
            case let .bytes(count):
                return "/bytes/\(count)"
            case let .chunked(count):
                return "/chunked/\(count)"
            case let .compression(compression):
                return "/\(compression.rawValue)"
            case let .delay(interval):
                return "/delay/\(interval)"
            case let .digestAuth(qop, username, password):
                return "/digest-auth/\(qop)/\(username)/\(password)"
            case let .download(count):
                return "/download/\(count)"
            case let .hiddenBasicAuth(username, password):
                return "/hidden-basic-auth/\(username)/\(password)"
            case let .image(type):
                return "/image/\(type.rawValue)"
            case .ip:
                return "/ip"
            case let .method(method):
                return "/\(method.rawValue.lowercased())"
            case let .payloads(count):
                return "/payloads/\(count)"
            case let .redirect(count):
                return "/redirect/\(count)"
            case .redirectTo:
                return "/redirect-to"
            case .responseHeaders:
                return "/response-headers"
            case let .status(code):
                return "/status/\(code)"
            case let .stream(count):
                return "/stream/\(count)"
            case .xml:
                return "/xml"
            }
        }
    }

    enum Image: String {
        case jpeg
    }

    enum Compression: String {
        case brotli, gzip, deflate
    }

    static var get: Endpoint { method(.get) }

    static func basicAuth(forUser user: String = "user", password: String = "password") -> Endpoint {
        Endpoint(path: .basicAuth(username: user, password: password))
    }

    static func bytes(_ count: Int) -> Endpoint {
        Endpoint(path: .bytes(count: count))
    }

    static func chunked(_ count: Int) -> Endpoint {
        Endpoint(path: .chunked(count: count))
    }

    static func compression(_ compression: Compression) -> Endpoint {
        Endpoint(path: .compression(compression))
    }

    static var `default`: Endpoint { .get }

    static func delay(_ interval: Int) -> Endpoint {
        Endpoint(path: .delay(interval: interval))
    }

    static func digestAuth(forUser user: String = "user", password: String = "password") -> Endpoint {
        Endpoint(path: .digestAuth(username: user, password: password))
    }

    static func download(_ count: Int = 10_000, produceError: Bool = false) -> Endpoint {
        Endpoint(path: .download(count: count), queryItems: [.init(name: "shouldProduceError",
                                                                   value: "\(produceError)")])
    }

    static func hiddenBasicAuth(forUser user: String = "user", password: String = "password") -> Endpoint {
        Endpoint(path: .hiddenBasicAuth(username: user, password: password),
                 headers: [.authorization(username: user, password: password)])
    }

    static func image(_ type: Image) -> Endpoint {
        Endpoint(path: .image(type))
    }

    static var ip: Endpoint {
        Endpoint(path: .ip)
    }

    static func method(_ method: HTTPMethod) -> Endpoint {
        Endpoint(path: .method(method), method: method)
    }

    static func payloads(_ count: Int) -> Endpoint {
        Endpoint(path: .payloads(count: count))
    }

    static func redirect(_ count: Int) -> Endpoint {
        Endpoint(path: .redirect(count: count))
    }

    static func redirectTo(_ url: String, code: Int? = nil) -> Endpoint {
        var items = [URLQueryItem(name: "url", value: url)]
        items = code.map { items + [.init(name: "statusCode", value: "\($0)")] } ?? items

        return Endpoint(path: .redirectTo, queryItems: items)
    }

    static func redirectTo(_ endpoint: Endpoint, code: Int? = nil) -> Endpoint {
        var items = [URLQueryItem(name: "url", value: endpoint.url.absoluteString)]
        items = code.map { items + [.init(name: "statusCode", value: "\($0)")] } ?? items

        return Endpoint(path: .redirectTo, queryItems: items)
    }

    static var responseHeaders: Endpoint {
        Endpoint(path: .responseHeaders)
    }

    static func status(_ code: Int) -> Endpoint {
        Endpoint(path: .status(code))
    }

    static func stream(_ count: Int) -> Endpoint {
        Endpoint(path: .stream(count: count))
    }

    static var xml: Endpoint {
        Endpoint(path: .xml, headers: [.contentType("application/xml")])
    }

    var scheme = Scheme.http
    var port: Int { host.port(for: scheme) }
    var host = Host.localhost
    var path = Path.method(.get)
    var method: HTTPMethod = .get
    var headers: HTTPHeaders = .init()
    var timeout: TimeInterval = 60
    var queryItems: [URLQueryItem] = []
    var cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy

    func modifying<T>(_ keyPath: WritableKeyPath<Endpoint, T>, to value: T) -> Endpoint {
        var copy = self
        copy[keyPath: keyPath] = value

        return copy
    }
}

extension Endpoint: URLRequestConvertible {
    var urlRequest: URLRequest { try! asURLRequest() }

    func asURLRequest() throws -> URLRequest {
        var request = URLRequest(url: try asURL())
        request.method = method
        request.headers = headers
        request.timeoutInterval = timeout
        request.cachePolicy = cachePolicy

        return request
    }
}

extension Endpoint: URLConvertible {
    var url: URL { try! asURL() }

    func asURL() throws -> URL {
        var components = URLComponents()
        components.scheme = scheme.rawValue
        components.port = port
        components.host = host.rawValue
        components.path = path.string

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        return try components.asURL()
    }
}

extension Session {
    func request(_ endpoint: Endpoint,
                 parameters: Parameters? = nil,
                 encoding: ParameterEncoding = URLEncoding.default,
                 headers: HTTPHeaders? = nil,
                 interceptor: RequestInterceptor? = nil,
                 requestModifier: RequestModifier? = nil) -> DataRequest {
        request(endpoint as URLConvertible,
                method: endpoint.method,
                parameters: parameters,
                encoding: encoding,
                headers: headers,
                interceptor: interceptor,
                requestModifier: requestModifier)
    }

    func request<Parameters: Encodable>(_ endpoint: Endpoint,
                                        parameters: Parameters? = nil,
                                        encoder: ParameterEncoder = URLEncodedFormParameterEncoder.default,
                                        headers: HTTPHeaders? = nil,
                                        interceptor: RequestInterceptor? = nil,
                                        requestModifier: RequestModifier? = nil) -> DataRequest {
        request(endpoint as URLConvertible,
                method: endpoint.method,
                parameters: parameters,
                encoder: encoder,
                headers: headers,
                interceptor: interceptor,
                requestModifier: requestModifier)
    }

    func request(_ endpoint: Endpoint, interceptor: RequestInterceptor? = nil) -> DataRequest {
        request(endpoint as URLRequestConvertible, interceptor: interceptor)
    }

    func streamRequest(_ endpoint: Endpoint,
                       headers: HTTPHeaders? = nil,
                       automaticallyCancelOnStreamError: Bool = false,
                       interceptor: RequestInterceptor? = nil,
                       requestModifier: RequestModifier? = nil) -> DataStreamRequest {
        streamRequest(endpoint as URLConvertible,
                      method: endpoint.method,
                      headers: headers,
                      automaticallyCancelOnStreamError: automaticallyCancelOnStreamError,
                      interceptor: interceptor,
                      requestModifier: requestModifier)
    }

    func streamRequest(_ endpoint: Endpoint,
                       automaticallyCancelOnStreamError: Bool = false,
                       interceptor: RequestInterceptor? = nil) -> DataStreamRequest {
        streamRequest(endpoint as URLRequestConvertible,
                      automaticallyCancelOnStreamError: automaticallyCancelOnStreamError,
                      interceptor: interceptor)
    }

    func download<Parameters: Encodable>(_ endpoint: Endpoint,
                                         parameters: Parameters? = nil,
                                         encoder: ParameterEncoder = URLEncodedFormParameterEncoder.default,
                                         headers: HTTPHeaders? = nil,
                                         interceptor: RequestInterceptor? = nil,
                                         requestModifier: RequestModifier? = nil,
                                         to destination: DownloadRequest.Destination? = nil) -> DownloadRequest {
        download(endpoint as URLConvertible,
                 method: endpoint.method,
                 parameters: parameters,
                 encoder: encoder,
                 headers: headers,
                 interceptor: interceptor,
                 requestModifier: requestModifier,
                 to: destination)
    }

    func download(_ endpoint: Endpoint,
                  parameters: Parameters? = nil,
                  encoding: ParameterEncoding = URLEncoding.default,
                  headers: HTTPHeaders? = nil,
                  interceptor: RequestInterceptor? = nil,
                  requestModifier: RequestModifier? = nil,
                  to destination: DownloadRequest.Destination? = nil) -> DownloadRequest {
        download(endpoint as URLConvertible,
                 method: endpoint.method,
                 parameters: parameters,
                 encoding: encoding,
                 headers: headers,
                 interceptor: interceptor,
                 requestModifier: requestModifier,
                 to: destination)
    }

    func download(_ endpoint: Endpoint,
                  interceptor: RequestInterceptor? = nil,
                  to destination: DownloadRequest.Destination? = nil) -> DownloadRequest {
        download(endpoint as URLRequestConvertible, interceptor: interceptor, to: destination)
    }

    func upload(_ data: Data,
                to endpoint: Endpoint,
                headers: HTTPHeaders? = nil,
                interceptor: RequestInterceptor? = nil,
                fileManager: FileManager = .default,
                requestModifier: RequestModifier? = nil) -> UploadRequest {
        upload(data, to: endpoint as URLConvertible,
               method: endpoint.method,
               headers: headers,
               interceptor: interceptor,
               fileManager: fileManager,
               requestModifier: requestModifier)
    }
}

extension Data {
    var asString: String {
        String(decoding: self, as: UTF8.self)
    }
}

struct TestResponse: Decodable {
    let headers: [String: String]
    let origin: String
    let url: String?
    let data: String?
    let form: [String: String]?
    let args: [String: String]?
}

struct TestParameters: Encodable {
    static let `default` = TestParameters(property: "property")

    let property: String
}
