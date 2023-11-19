//
//  RequestCompression.swift
//
//  Copyright (c) 2023 Alamofire Software Foundation (http://alamofire.org/)
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

#if canImport(zlib)
import Foundation
import zlib

/// `RequestAdapter` which compresses outgoing `URLRequest` bodies using the `deflate` `Content-Encoding` and adds the
/// appropriate header.
///
/// - Note: Most requests to most APIs are small and so would only be slowed down by applying this adapter. Measure the
///         size of your request bodies and the performance impact of using this adapter before use. Using this adapter
///         with already compressed data, such as images, will, at best, have no effect. Additionally, body compression
///         is a synchronous operation, so measuring the performance impact may be important to determine whether you
///         want to use a dedicated `requestQueue` in your `Session` instance. Finally, not all servers support request
///         compression, so test with all of your server configurations before deploying.
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public struct DeflateRequestCompressor: RequestInterceptor {
    /// Type that determines the action taken when the `URLRequest` already has a `Content-Encoding` header.
    public enum DuplicateHeaderBehavior {
        /// Throws a `DuplicateHeaderError`. The default.
        case error
        /// Replaces the existing header value with `deflate`.
        case replace
        /// Silently skips compression when the header exists.
        case skip
    }

    /// `Error` produced when the outgoing `URLRequest` already has a `Content-Encoding` header, when the instance has
    /// been configured to produce an error.
    public struct DuplicateHeaderError: Error {}

    /// Behavior to use when the outgoing `URLRequest` already has a `Content-Encoding` header.
    public let duplicateHeaderBehavior: DuplicateHeaderBehavior
    /// Closure which determines whether the outgoing body data should be compressed.
    public let shouldCompressBodyData: (_ bodyData: Data) -> Bool

    /// Creates an instance with the provided parameters.
    ///
    /// - Parameters:
    ///   - duplicateHeaderBehavior: `DuplicateHeaderBehavior` to use. `.error` by default.
    ///   - shouldCompressBodyData:  Closure which determines whether the outgoing body data should be compressed. `true` by default.
    public init(duplicateHeaderBehavior: DuplicateHeaderBehavior = .error,
                shouldCompressBodyData: @escaping (_ bodyData: Data) -> Bool = { _ in true }) {
        self.duplicateHeaderBehavior = duplicateHeaderBehavior
        self.shouldCompressBodyData = shouldCompressBodyData
    }

    public func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        // No need to compress unless we have body data. No support for compressing streams.
        guard let bodyData = urlRequest.httpBody else {
            completion(.success(urlRequest))
            return
        }

        guard shouldCompressBodyData(bodyData) else {
            completion(.success(urlRequest))
            return
        }

        if urlRequest.headers.value(for: "Content-Encoding") != nil {
            switch duplicateHeaderBehavior {
            case .error:
                completion(.failure(DuplicateHeaderError()))
                return
            case .replace:
                // Header will be replaced once the body data is compressed.
                break
            case .skip:
                completion(.success(urlRequest))
                return
            }
        }

        var compressedRequest = urlRequest

        do {
            compressedRequest.httpBody = try deflate(bodyData)
            compressedRequest.headers.update(.contentEncoding("deflate"))
            completion(.success(compressedRequest))
        } catch {
            completion(.failure(error))
        }
    }

    func deflate(_ data: Data) throws -> Data {
        var output = Data([0x78, 0x5E]) // Header
        try output.append((data as NSData).compressed(using: .zlib) as Data)
        var checksum = adler32Checksum(of: data).bigEndian
        output.append(Data(bytes: &checksum, count: MemoryLayout<UInt32>.size))

        return output
    }

    func adler32Checksum(of data: Data) -> UInt32 {
        data.withUnsafeBytes { buffer in
            UInt32(adler32(1, buffer.baseAddress, UInt32(buffer.count)))
        }
    }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension RequestInterceptor where Self == DeflateRequestCompressor {
    /// Create a `DeflateRequestCompressor` with default `duplicateHeaderBehavior` and `shouldCompressBodyData` values.
    public static var deflateCompressor: DeflateRequestCompressor {
        DeflateRequestCompressor()
    }

    /// Creates a `DeflateRequestCompressor` with the provided `DuplicateHeaderBehavior` and `shouldCompressBodyData`
    /// closure.
    ///
    /// - Parameters:
    ///   - duplicateHeaderBehavior: `DuplicateHeaderBehavior` to use.
    ///   - shouldCompressBodyData: Closure which determines whether the outgoing body data should be compressed. `true` by default.
    ///
    /// - Returns: The `DeflateRequestCompressor`.
    public static func deflateCompressor(
        duplicateHeaderBehavior: DeflateRequestCompressor.DuplicateHeaderBehavior = .error,
        shouldCompressBodyData: @escaping (_ bodyData: Data) -> Bool = { _ in true }
    ) -> DeflateRequestCompressor {
        DeflateRequestCompressor(duplicateHeaderBehavior: duplicateHeaderBehavior,
                                 shouldCompressBodyData: shouldCompressBodyData)
    }
}
#endif
