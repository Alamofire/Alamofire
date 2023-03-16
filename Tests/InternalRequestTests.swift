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
import XCTest

final class InternalRequestTests: BaseTestCase {
    func testThatMultipleFinishInvocationsDoNotCallSerializersMoreThanOnce() {
        // Given
        let session = Session(rootQueue: .main, startRequestsImmediately: false)
        let expect = expectation(description: "request complete")
        var response: DataResponse<Data?, AFError>?

        // When
        let request = session.request(.get).response { resp in
            response = resp
            expect.fulfill()
        }

        for _ in 0..<100 {
            request.finish()
        }

        waitForExpectations(timeout: timeout)

        // Then
        XCTAssertNotNil(response)
    }

    #if canImport(zlib)
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testThatRequestCompressorProperlyCalculatesAdler32() {
        // Given
        let compressor = DeflateRequestCompressor()

        // When
        let checksum = compressor.adler32Checksum(of: Data("Wikipedia".utf8))

        // Then
        // From https://en.wikipedia.org/wiki/Adler-32
        XCTAssertEqual(checksum, 300_286_872)
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testThatRequestCompressorDeflatesDataCorrectly() throws {
        // Given
        let compressor = DeflateRequestCompressor()

        // When
        let compressedData = try compressor.deflate(Data([0]))

        // Then
        XCTAssertEqual(compressedData, Data([0x78, 0x5E, 0x63, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01]))
    }
    #endif
}
