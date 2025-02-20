//
//  URLConvertable.swift
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
@testable import Alamofire
import Foundation
import XCTest

final class URLConvertableTestCase: BaseTestCase{
    // MARK: Tests - Present String as Url

    @MainActor
    func testInitializerWithNonASCIICharacters() {
        // Given
        let domain = "https://example.com/"
        let urlString = generateRandomURLWithNonASCII(domain:domain)
        let expectedEncodedURL = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        
        //When
        do{
            let url = try urlString.asURL()
            // Then
            XCTAssertNotNil(url)
            XCTAssertEqual(url.absoluteString, expectedEncodedURL)
        } catch{
            XCTFail("actual url cannot be cast present as url with error: \(error)")
        }
    }
    
    @MainActor
    func testInitializerWithEmptyString() {
        // Given
        let urlString = ""
        
        // When
        do {
            let url = try urlString.asURL()
            XCTFail("expected error, but url was created \(url)")
        } catch {
            // Then
            XCTAssertTrue(error is AFError)
            XCTAssertTrue((error.asAFError?.isInvalidURLError) != nil)
        }
    }
    
    private func generateRandomURLWithNonASCII(domain: String) -> String {
        let pathLength = Int.random(in: 5...10)
        var path = ""
        
        for _ in 0..<pathLength {
            let character = randomCharacter(from: 0x3040...0x30FF)
            path.append(character)
        }
        
        return domain + path
    }
    
    private func randomCharacter(from range: ClosedRange<UInt32>) -> Character {
        let randomUnicode = UInt32.random(in: range)
        return Character(UnicodeScalar(randomUnicode)!)
    }
}
