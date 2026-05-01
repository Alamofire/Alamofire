//
//  MIMETypeTests.swift
//
//  Copyright (c) 2026 Alamofire Software Foundation (http://alamofire.org/)
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
import Testing

@Suite("MIMEType Initialization")
struct MIMETypeInitTests {
    @Test("Parses standard type/subtype pairs", arguments: [("text/plain", "text", "plain"),
                                                            ("application/json", "application", "json"),
                                                            ("image/png", "image", "png"),
                                                            ("*/*", "*", "*"),
                                                            ("text/*", "text", "*"),
                                                            ("*/json", "*", "json")])
    func parsesWellFormedPair(input: String, expectedType: String, expectedSubtype: String) {
        let mime = Request.MIMEType(input)
        #expect(mime != nil)
        #expect(mime?.type == expectedType)
        #expect(mime?.subtype == expectedSubtype)
    }

    @Test("Strips semicolon-delimited parameters from the subtype field")
    func stripsParameters() {
        let mime = Request.MIMEType("text/plain; charset=utf-8")
        #expect(mime?.type == "text")
        #expect(mime?.subtype == "plain")
    }

    @Test("Strips surrounding whitespace before parsing")
    func stripsWhitespace() {
        let mime = Request.MIMEType("  text/plain  ")
        #expect(mime?.type == "text")
        #expect(mime?.subtype == "plain")
    }

    @Test("isWildcard is true only for */*")
    func wildcardDetection() {
        #expect(Request.MIMEType("*/*")?.isWildcard == true)
        #expect(Request.MIMEType("text/*")?.isWildcard == false)
        #expect(Request.MIMEType("*/json")?.isWildcard == false)
        #expect(Request.MIMEType("text/plain")?.isWildcard == false)
    }

    @Test("Single-component string without '/' must return nil")
    func singleComponentWithoutSlashReturnsNil() {
        #expect(Request.MIMEType("text") == nil, "A string with no '/' separator cannot represent a valid MIME type")
    }

    @Test("Empty string must return nil")
    func emptyStringReturnsNil() {
        #expect(Request.MIMEType("") == nil, "An empty string cannot represent a valid MIME type")
    }
}

// MARK: - MIMEType Matching Tests

@Suite("MIMEType Matching")
struct MIMETypeMatchingTests {
    @Test("Exact type/subtype pair matches itself")
    func exactMatch() throws {
        let acceptable = try #require(Request.MIMEType("text/plain"))
        let response = try #require(Request.MIMEType("text/plain"))
        #expect(acceptable.matches(response))
    }

    @Test("Wildcard subtype matches any subtype of the same type")
    func wildcardSubtypeMatchesAnySametype() throws {
        let textWildcard = try #require(Request.MIMEType("text/*"))
        let textPlain = try #require(Request.MIMEType("text/plain"))
        let textHTML = try #require(Request.MIMEType("text/html"))
        #expect(textWildcard.matches(textPlain))
        #expect(textWildcard.matches(textHTML))
    }

    @Test("Wildcard subtype does not match a different type")
    func wildcardSubtypeDoesNotMatchDifferentType() throws {
        let textWildcard = try #require(Request.MIMEType("text/*"))
        let appJSON = try #require(Request.MIMEType("application/json"))
        #expect(!textWildcard.matches(appJSON))
    }

    @Test("Wildcard type matches any type with the same subtype")
    func wildcardTypeMatchesSameSubtype() throws {
        let wildcardJSON = try #require(Request.MIMEType("*/json"))
        let appJSON = try #require(Request.MIMEType("application/json"))
        #expect(wildcardJSON.matches(appJSON))
    }

    @Test("Full wildcard */* matches any MIME type")
    func fullWildcardMatchesAny() throws {
        let wildcard = try #require(Request.MIMEType("*/*"))
        #expect(try wildcard.matches(#require(Request.MIMEType("text/plain"))))
        #expect(try wildcard.matches(#require(Request.MIMEType("application/json"))))
        #expect(try wildcard.matches(#require(Request.MIMEType("image/png"))))
    }

    @Test("Different type and subtype do not match")
    func noMatchOnDifferentPair() throws {
        let appJSON = try #require(Request.MIMEType("application/json"))
        let textPlain = try #require(Request.MIMEType("text/plain"))
        #expect(!appJSON.matches(textPlain))
    }

    @Test("Same type but different subtype does not match without a wildcard")
    func sameTypeButDifferentSubtypeNoMatch() throws {
        let textPlain = try #require(Request.MIMEType("text/plain"))
        let textHTML = try #require(Request.MIMEType("text/html"))
        #expect(!textPlain.matches(textHTML))
    }
}
