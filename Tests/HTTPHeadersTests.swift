//
//  HTTPHeadersTests.swift
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
import Testing

@Suite
struct HTTPHeadersTests {
    @Test
    func headersAreStoreUniquelyByCaseInsensitiveName() {
        // Given
        let headersFromDictionaryLiteral: HTTPHeaders = ["key": "", "Key": "", "KEY": ""]
        let headersFromDictionary = HTTPHeaders(["key": "", "Key": "", "KEY": ""])
        let headersFromArrayLiteral: HTTPHeaders = [HTTPHeader(name: "key", value: ""),
                                                    HTTPHeader(name: "Key", value: ""),
                                                    HTTPHeader(name: "KEY", value: "")]
        let headersFromArray = HTTPHeaders([HTTPHeader(name: "key", value: ""),
                                            HTTPHeader(name: "Key", value: ""),
                                            HTTPHeader(name: "KEY", value: "")])
        var headersCreatedManually = HTTPHeaders()
        headersCreatedManually.update(HTTPHeader(name: "key", value: ""))
        headersCreatedManually.update(name: "Key", value: "")
        headersCreatedManually.update(name: "KEY", value: "")

        // When, Then
        #expect(headersFromDictionaryLiteral.count == 1)
        #expect(headersFromDictionary.count == 1)
        #expect(headersFromArrayLiteral.count == 1)
        #expect(headersFromArray.count == 1)
        #expect(headersCreatedManually.count == 1)
    }

    @Test
    func headersPreserveOrderOfInsertion() {
        // Given
        let headersFromDictionaryLiteral: HTTPHeaders = ["c": "", "a": "", "b": ""]
        // Dictionary initializer can't preserve order.
        let headersFromArrayLiteral: HTTPHeaders = [HTTPHeader(name: "b", value: ""),
                                                    HTTPHeader(name: "a", value: ""),
                                                    HTTPHeader(name: "c", value: "")]
        let headersFromArray = HTTPHeaders([HTTPHeader(name: "b", value: ""),
                                            HTTPHeader(name: "a", value: ""),
                                            HTTPHeader(name: "c", value: "")])
        var headersCreatedManually = HTTPHeaders()
        headersCreatedManually.update(HTTPHeader(name: "c", value: ""))
        headersCreatedManually.update(name: "b", value: "")
        headersCreatedManually.update(name: "a", value: "")

        // When
        let dictionaryLiteralNames = headersFromDictionaryLiteral.map(\.name)
        let arrayLiteralNames = headersFromArrayLiteral.map(\.name)
        let arrayNames = headersFromArray.map(\.name)
        let manualNames = headersCreatedManually.map(\.name)

        // Then
        #expect(dictionaryLiteralNames == ["c", "a", "b"])
        #expect(arrayLiteralNames == ["b", "a", "c"])
        #expect(arrayNames == ["b", "a", "c"])
        #expect(manualNames == ["c", "b", "a"])
    }

    @Test
    func headersCanBeProperlySortedByName() {
        // Given
        let headers: HTTPHeaders = ["c": "", "a": "", "b": ""]

        // When
        let sortedHeaders = headers.sorted()

        // Then
        #expect(headers.map(\.name) == ["c", "a", "b"])
        #expect(sortedHeaders.map(\.name) == ["a", "b", "c"])
    }

    @Test
    func headersCanInsensitivelyGetAndSetThroughSubscript() {
        // Given
        var headers: HTTPHeaders = ["c": "", "a": "", "b": ""]

        // When
        headers["C"] = "c"
        headers["a"] = "a"
        headers["b"] = "b"

        // Then
        #expect(headers["c"] == "c")
        #expect(headers.map(\.value) == ["c", "a", "b"])
        #expect(headers.count == 3)
    }

    @Test
    func headersPreserveLastFormAndValueOfAName() {
        // Given
        var headers: HTTPHeaders = ["c": "a"]

        // When
        headers["C"] = "c"

        // Then
        #expect(headers.description == "C: c")
    }

    @Test
    func headersHaveUnsortedDescription() {
        // Given
        let headers: HTTPHeaders = ["c": "c", "a": "a", "b": "b"]

        // When
        let description = headers.description
        let expectedDescription = """
        c: c
        a: a
        b: b
        """

        // Then
        #expect(description == expectedDescription)
    }
}
