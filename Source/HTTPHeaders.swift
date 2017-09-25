//
//  HTTPHeaders.swift
//
//  Copyright (c) 2014-2017 Alamofire Software Foundation (http://alamofire.org/)
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

public struct HTTPHeaders {
    private var headers: Set<HTTPHeader> = []
    
    public init(_ headers: [String : String]?) {
        guard let headers = headers else { return }
        
        self.headers = Set(headers.map { HTTPHeader(name: HTTPHeader.Name($0), value: HTTPHeader.Value($1)) })
    }
    
    public mutating func add(_ headers: HTTPHeader...) {
        headers.forEach { self.headers.insert($0) }
    }
    
    public mutating func remove(_ headers: HTTPHeader...) {
        headers.forEach { self.headers.remove($0) }
    }
    
    public func asDictionary() -> [String : String] {
        let names = headers.map { $0.name.rawValue }
        let values = headers.map { $0.value.rawValue }
        return Dictionary(zip(names, values),
                          uniquingKeysWith: { (_, last) in last })
    }
    
    public func header(for name: HTTPHeader.Name) -> HTTPHeader? {
        return headers.first { $0.name == name }
    }
    
    public func value(for name: HTTPHeader.Name) -> HTTPHeader.Value? {
        return header(for: name)?.value
    }
    
    public func contains(name: HTTPHeader.Name) -> Bool {
        return headers.contains { $0.name == name }
    }
    
    public subscript(name: HTTPHeader.Name) -> HTTPHeader.Value? {
        get { return value(for: name) }
        set {
            if let value = newValue {
                add(HTTPHeader(name: name, value: value))
            } else if let index = headers.index(where: { $0.name == name }) {
                headers.remove(at: index)
            }
        }
    }
    
    public subscript(name: HTTPHeader.Name) -> HTTPHeader? {
        get { return header(for: name) }
        set {
            if let value = newValue {
                add(value)
            } else if let index = headers.index(where: { $0.name == name }) {
                headers.remove(at: index)
            }
        }
    }
}

extension HTTPHeaders: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: HTTPHeader...) {
        headers = Set(elements)
    }
}

extension HTTPHeaders: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, String)...) {
        self.headers = Set(elements.map { HTTPHeader(name: HTTPHeader.Name($0), value: HTTPHeader.Value($1)) })
    }
}

extension HTTPHeaders: CustomStringConvertible {
    public var description: String {
        return asDictionary().description
    }
}

extension HTTPHeaders: Sequence {
    public func makeIterator() -> AnyIterator<HTTPHeader> {
        return AnyIterator(headers.sorted{ $0.name < $1.name }.makeIterator())
    }
}

public struct HTTPHeader {
    public let name: Name
    public let value: Value
    
    public struct Name {
        public let rawValue: String
        
        public init(_ rawValue: String) {
            self.rawValue = rawValue
        }
    }
    
    public struct Value {
        public let rawValue: String
        
        public init(_ rawValue: String) {
            self.rawValue = rawValue
        }
    }
}

extension HTTPHeader: Comparable {
    public static func ==(lhs: HTTPHeader, rhs: HTTPHeader) -> Bool {
        return lhs.name == rhs.name && lhs.value == rhs.value
    }
    
    public static func <(lhs: HTTPHeader, rhs: HTTPHeader) -> Bool {
        if lhs.name == rhs.name {
            return lhs.value < rhs.value
        } else {
            return lhs.name < rhs.name
        }
    }
}

extension HTTPHeader: Hashable {
    public var hashValue: Int {
        return name.hashValue ^ value.hashValue &* 16777619
    }
}

extension HTTPHeader.Name: CustomStringConvertible {
    public var description: String {
        return rawValue
    }
}

extension HTTPHeader.Name: CustomDebugStringConvertible {
    public var debugDescription: String {
        return description
    }
}

extension HTTPHeader.Value: CustomStringConvertible {
    public var description: String {
        return rawValue
    }
}

extension HTTPHeader.Value: CustomDebugStringConvertible {
    public var debugDescription: String {
        return description
    }
}

extension HTTPHeader.Name: Comparable {
    public static func ==(lhs: HTTPHeader.Name, rhs: HTTPHeader.Name) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
    
    public static func <(lhs: HTTPHeader.Name, rhs: HTTPHeader.Name) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

extension HTTPHeader.Name: Hashable {
    public var hashValue: Int { return rawValue.hashValue }
}

extension HTTPHeader.Value: Comparable {
    public static func ==(lhs: HTTPHeader.Value, rhs: HTTPHeader.Value) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
    
    public static func <(lhs: HTTPHeader.Value, rhs: HTTPHeader.Value) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

extension HTTPHeader.Value: Hashable {
    public var hashValue: Int { return rawValue.hashValue }
}

extension HTTPHeader.Name: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        rawValue = value
    }
}

extension HTTPHeader.Value: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        rawValue = value
    }
}

public extension HTTPHeader {
    public static func contentEncoding(_ value: Value) -> HTTPHeader {
        return HTTPHeader(name: .contentEncoding, value: value)
    }
    
    //    static func contentEncoding(_ mimeType: MIMEType) -> HTTPHeader {
    //        return HTTPHeader(name: .contentEncoding, value: mimeType.)
    //    }
    
    public static func authorization(_ string: String) -> HTTPHeader {
        return HTTPHeader(name: .authorization, value: Value(string))
    }
    
    public static func acceptLanguage(_ value: String) -> HTTPHeader {
        return HTTPHeader(name: .acceptLanguage, value: Value(value))
    }
    
    public static func acceptEncoding(_ value: Value) -> HTTPHeader {
        return HTTPHeader(name: .acceptEncoding, value: value)
    }
    
    public static func contentDisposition(_ value: String) -> HTTPHeader {
        return HTTPHeader(name: .contentDisposition, value: Value(value))
    }
    
    public static let defaultAcceptEncoding = HTTPHeader(name: .acceptEncoding, value: .defaultAcceptEncoding)
    public static let defaultAcceptLanguage = HTTPHeader(name: .acceptLanguage, value: .defaultAcceptLanguage)
    public static let defaultUserAgent = HTTPHeader(name: .userAgent, value: .defaultUserAgent)
}

public extension HTTPHeader.Name {
    public static let contentEncoding = HTTPHeader.Name("Content-Encoding")
    public static let authorization = HTTPHeader.Name("Authorization")
    public static let userAgent = HTTPHeader.Name("User-Agent")
    public static let acceptLanguage = HTTPHeader.Name("Accept-Language")
    public static let acceptEncoding = HTTPHeader.Name("Accept-Encoding")
    public static let contentDisposition = HTTPHeader.Name("Content-Disposition")
    public static let contentType = HTTPHeader.Name("Content-Type")
}

public extension HTTPHeader.Value {
    public static let json = HTTPHeader.Value("application/json")
    public static let xml = HTTPHeader.Value("application/xml")
    // Accept-Encoding HTTP Header; see https://tools.ietf.org/html/rfc7230#section-4.2.3
    public static let defaultAcceptEncoding = HTTPHeader.Value("br;q=1.0, gzip;q=0.9, compress;q=0.8") // Determine whether this is actually necessary
    // Accept-Language HTTP Header; see https://tools.ietf.org/html/rfc7231#section-5.3.5
    public static let defaultAcceptLanguage: HTTPHeader.Value = {
        let languageString = Locale.preferredLanguages.prefix(6).enumerated().map { index, languageCode in
            let quality = 1.0 - (Double(index) * 0.1)
            return "\(languageCode);q=\(quality)"
            }.joined(separator: ", ")
        
        return HTTPHeader.Value(languageString)
    }()
    // User-Agent Header; see https://tools.ietf.org/html/rfc7231#section-5.5.3
    // Example: `iOS Example/1.0 (org.alamofire.iOS-Example; build:1; iOS 11.0.0) Alamofire/5.0.0`
    public static let defaultUserAgent: HTTPHeader.Value = {
        guard let info = Bundle.main.infoDictionary else { return "Alamofire" }
        
        let executable = info[kCFBundleExecutableKey as String] as? String ?? "Unknown"
        let bundle = info[kCFBundleIdentifierKey as String] as? String ?? "Unknown"
        let appVersion = info["CFBundleShortVersionString"] as? String ?? "Unknown"
        let appBuild = info[kCFBundleVersionKey as String] as? String ?? "Unknown"
        
        let osNameVersion: String = {
            let version = ProcessInfo.processInfo.operatingSystemVersion
            let versionString = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
            
            let osName: String = {
                #if os(iOS)
                    return "iOS"
                #elseif os(watchOS)
                    return "watchOS"
                #elseif os(tvOS)
                    return "tvOS"
                #elseif os(macOS)
                    return "macOS"
                #elseif os(Linux)
                    return "Linux"
                #else
                    return "Unknown"
                #endif
            }()
            
            return "\(osName) \(versionString)"
        }()
        
        let alamofireVersion: String = {
            guard
                let afInfo = Bundle(for: SessionManager.self).infoDictionary,
                let build = afInfo["CFBundleShortVersionString"]
                else { return "Unknown" }
            
            return "Alamofire/\(build)"
        }()
        
        return HTTPHeader.Value("\(executable)/\(appVersion) (\(bundle); build:\(appBuild); \(osNameVersion)) \(alamofireVersion)")
    }()
}

public extension URLRequest {
    var httpHeaders: HTTPHeaders {
        get { return HTTPHeaders(allHTTPHeaderFields) }
        set { allHTTPHeaderFields = newValue.asDictionary() }
    }
}

public extension HTTPURLResponse {
    var httpHeaders: HTTPHeaders {
        return HTTPHeaders(allHeaderFields as? [String : String])
    }
}

public extension URLSessionConfiguration {
    var httpHeaders: HTTPHeaders {
        get { return HTTPHeaders(httpAdditionalHeaders as? [String : String]) }
        set { httpAdditionalHeaders = newValue.asDictionary() }
    }
}
