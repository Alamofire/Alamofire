//
//  TestHelpers.swift
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
    static let invalidURL = "invalid"
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
            case .http: 80
            case .https: 443
            }
        }
    }

    enum Host: String {
        case localhost = "127.0.0.1"
        case httpBin = "httpbin.org"

        func port(for scheme: Scheme) -> Int {
            switch self {
            case .localhost: 8080
            case .httpBin: scheme.port
            }
        }
    }

    enum Path {
        case basicAuth(username: String, password: String)
        case bytes(count: Int)
        case cache
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
        case upload
        case websocket
        case websocketCount(Int)
        case websocketEcho
        case websocketPingCount(Int)
        case xml

        var string: String {
            switch self {
            case let .basicAuth(username: username, password: password):
                "/basic-auth/\(username)/\(password)"
            case let .bytes(count):
                "/bytes/\(count)"
            case .cache:
                "/cache"
            case let .chunked(count):
                "/chunked/\(count)"
            case let .compression(compression):
                "/\(compression.rawValue)"
            case let .delay(interval):
                "/delay/\(interval)"
            case let .digestAuth(qop, username, password):
                "/digest-auth/\(qop)/\(username)/\(password)"
            case let .download(count):
                "/download/\(count)"
            case let .hiddenBasicAuth(username, password):
                "/hidden-basic-auth/\(username)/\(password)"
            case let .image(type):
                "/image/\(type.rawValue)"
            case .ip:
                "/ip"
            case let .method(method):
                "/\(method.rawValue.lowercased())"
            case let .payloads(count):
                "/payloads/\(count)"
            case let .redirect(count):
                "/redirect/\(count)"
            case .redirectTo:
                "/redirect-to"
            case .responseHeaders:
                "/response-headers"
            case let .status(code):
                "/status/\(code)"
            case let .stream(count):
                "/stream/\(count)"
            case .upload:
                "/upload"
            case .websocket:
                "/websocket"
            case let .websocketCount(count):
                "/websocket/payloads/\(count)"
            case .websocketEcho:
                "/websocket/echo"
            case let .websocketPingCount(count):
                "/websocket/ping/\(count)"
            case .xml:
                "/xml"
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

    static let cache: Endpoint = .init(path: .cache)

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

    static let upload: Endpoint = .init(path: .upload, method: .post, headers: [.contentType("application/octet-stream")])

    #if canImport(Darwin) && !canImport(FoundationNetworking)
    static var defaultCloseDelay: Int64 {
        if #available(macOS 12, iOS 15, tvOS 15, watchOS 8, *) {
            0
        } else if #available(macOS 11.3, iOS 14.5, tvOS 14.5, watchOS 7.4, *) {
            // iOS 14.5 to 14.7 have a bug where immediate connection closure will drop messages, so delay close by 60
            // milliseconds.
            60
        } else {
            0
        }
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    static func websocket(closeCode: URLSessionWebSocketTask.CloseCode = .normalClosure, closeDelay: Int64 = defaultCloseDelay) -> Endpoint {
        Endpoint(path: .websocket, queryItems: [.init(name: "closeCode", value: "\(closeCode.rawValue)"),
                                                .init(name: "closeDelay", value: "\(closeDelay)")])
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    static func websocketCount(_ count: Int = 2,
                               closeCode: URLSessionWebSocketTask.CloseCode = .normalClosure,
                               closeDelay: Int64 = defaultCloseDelay) -> Endpoint {
        Endpoint(path: .websocketCount(count), queryItems: [.init(name: "closeCode", value: "\(closeCode.rawValue)"),
                                                            .init(name: "closeDelay", value: "\(closeDelay)")])
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    static let websocketEcho = Endpoint(path: .websocketEcho)

    static func websocketPings(count: Int = 5) -> Endpoint {
        Endpoint(path: .websocketPingCount(count))
    }
    #endif

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
        var request = try URLRequest(url: asURL())
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

final class EndpointSequence: URLRequestConvertible {
    enum Error: Swift.Error { case noRemainingEndpoints }

    private var remainingEndpoints: [Endpoint]

    init(endpoints: [Endpoint]) {
        remainingEndpoints = endpoints
    }

    func asURLRequest() throws -> URLRequest {
        guard !remainingEndpoints.isEmpty else { throw Error.noRemainingEndpoints }

        return try remainingEndpoints.removeFirst().asURLRequest()
    }
}

extension URLRequestConvertible where Self == EndpointSequence {
    static func endpoints(_ endpoints: Endpoint...) -> Self {
        EndpointSequence(endpoints: endpoints)
    }
}

extension Session {
    func request(_ endpoint: Endpoint,
                 parameters: Parameters? = nil,
                 encoding: any ParameterEncoding = URLEncoding.default,
                 headers: HTTPHeaders? = nil,
                 interceptor: (any RequestInterceptor)? = nil,
                 requestModifier: RequestModifier? = nil) -> DataRequest {
        request(endpoint as (any URLConvertible),
                method: endpoint.method,
                parameters: parameters,
                encoding: encoding,
                headers: headers,
                interceptor: interceptor,
                requestModifier: requestModifier)
    }

    func request<Parameters: Encodable>(_ endpoint: Endpoint,
                                        parameters: Parameters? = nil,
                                        encoder: any ParameterEncoder = URLEncodedFormParameterEncoder.default,
                                        headers: HTTPHeaders? = nil,
                                        interceptor: (any RequestInterceptor)? = nil,
                                        requestModifier: RequestModifier? = nil) -> DataRequest {
        request(endpoint as (any URLConvertible),
                method: endpoint.method,
                parameters: parameters,
                encoder: encoder,
                headers: headers,
                interceptor: interceptor,
                requestModifier: requestModifier)
    }

    func request(_ endpoint: Endpoint, interceptor: (any RequestInterceptor)? = nil) -> DataRequest {
        request(endpoint as (any URLRequestConvertible), interceptor: interceptor)
    }

    func streamRequest(_ endpoint: Endpoint,
                       headers: HTTPHeaders? = nil,
                       automaticallyCancelOnStreamError: Bool = false,
                       interceptor: (any RequestInterceptor)? = nil,
                       requestModifier: RequestModifier? = nil) -> DataStreamRequest {
        streamRequest(endpoint as (any URLConvertible),
                      method: endpoint.method,
                      headers: headers,
                      automaticallyCancelOnStreamError: automaticallyCancelOnStreamError,
                      interceptor: interceptor,
                      requestModifier: requestModifier)
    }

    func streamRequest(_ endpoint: Endpoint,
                       automaticallyCancelOnStreamError: Bool = false,
                       interceptor: (any RequestInterceptor)? = nil) -> DataStreamRequest {
        streamRequest(endpoint as (any URLRequestConvertible),
                      automaticallyCancelOnStreamError: automaticallyCancelOnStreamError,
                      interceptor: interceptor)
    }

    func download<Parameters: Encodable>(_ endpoint: Endpoint,
                                         parameters: Parameters? = nil,
                                         encoder: any ParameterEncoder = URLEncodedFormParameterEncoder.default,
                                         headers: HTTPHeaders? = nil,
                                         interceptor: (any RequestInterceptor)? = nil,
                                         requestModifier: RequestModifier? = nil,
                                         to destination: DownloadRequest.Destination? = nil) -> DownloadRequest {
        download(endpoint as (any URLConvertible),
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
                  encoding: any ParameterEncoding = URLEncoding.default,
                  headers: HTTPHeaders? = nil,
                  interceptor: (any RequestInterceptor)? = nil,
                  requestModifier: RequestModifier? = nil,
                  to destination: DownloadRequest.Destination? = nil) -> DownloadRequest {
        download(endpoint as (any URLConvertible),
                 method: endpoint.method,
                 parameters: parameters,
                 encoding: encoding,
                 headers: headers,
                 interceptor: interceptor,
                 requestModifier: requestModifier,
                 to: destination)
    }

    func download(_ endpoint: Endpoint,
                  interceptor: (any RequestInterceptor)? = nil,
                  to destination: DownloadRequest.Destination? = nil) -> DownloadRequest {
        download(endpoint as (any URLRequestConvertible), interceptor: interceptor, to: destination)
    }

    func upload(_ data: Data,
                to endpoint: Endpoint,
                headers: HTTPHeaders? = nil,
                interceptor: (any RequestInterceptor)? = nil,
                fileManager: FileManager = .default,
                requestModifier: RequestModifier? = nil) -> UploadRequest {
        upload(data, to: endpoint as (any URLConvertible),
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

    func asJSONObject() throws -> Any {
        try JSONSerialization.jsonObject(with: self, options: .allowFragments)
    }
}

struct TestResponse: Decodable {
    let headers: HTTPHeaders
    let origin: String
    let url: String
    let data: String?
    let form: [String: String]?
    let args: [String: String]
}

extension Alamofire.HTTPHeaders: Swift.Decodable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()

        let headers = try container.decode([HTTPHeader].self)

        self = .init(headers)
    }
}

extension Alamofire.HTTPHeader: Swift.Decodable {
    enum CodingKeys: String, CodingKey {
        case name, value
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let name = try container.decode(String.self, forKey: .name)
        let value = try container.decode(String.self, forKey: .value)

        self = .init(name: name, value: value)
    }
}

struct TestParameters: Encodable {
    static let `default` = TestParameters(property: "property")

    let property: String
}

struct UploadResponse: Decodable {
    let bytes: Int
}
