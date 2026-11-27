//
//  InternalRequestTests.swift
//
//  Copyright (c) 2020 Alamofire Software Foundation (http://alamofire.org/)
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

@testable import Alamofire
import Foundation
import Testing

@Suite(.storesInstances)
struct InternalRequestTests {
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func multipleFinishInvocationsDoNotCallSerializersMoreThanOnce() async {
        // Given
        let session = stored(Session.independent(startRequestsImmediately: false))
        let expect = Completion("request complete")
        let response = Capture<DataResponse<Data?, AFError>?>()

        // When
        let request = session.request(.get).response { resp in
            response.value = resp
            expect.complete()
        }

        // finish() must be called on the request's underlying queue, which is the session's rootQueue.
        session.rootQueue.sync {
            for _ in 0..<100 {
                request.finish()
            }
        }

        await expect.wait()

        // Then
        #expect(response.value != nil)
    }

    #if canImport(zlib) && !os(Android) // Match RequestCompression support.
    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func requestCompressorProperlyCalculatesAdler32() {
        // Given
        let compressor = DeflateRequestCompressor()

        // When
        let checksum = compressor.adler32Checksum(of: Data("Wikipedia".utf8))

        // Then
        // From https://en.wikipedia.org/wiki/Adler-32
        #expect(checksum == 300_286_872)
    }

    @Test
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func requestCompressorDeflatesDataCorrectly() throws {
        // Given
        let compressor = DeflateRequestCompressor()

        // When
        let compressedData = try compressor.deflate(Data([0]))

        // Then
        #expect(compressedData == Data([0x78, 0x5E, 0x63, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01]))
    }
    #endif
}
