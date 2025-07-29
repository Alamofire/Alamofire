//
//  URLConvertibleTests.swift
//
//  Copyright (c) 2014-2024 Alamofire Software Foundation (http://alamofire.org/)
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
import XCTest

final class URLConvertibleTests: BaseTestCase {
    func testStringAsURLWithValidURL() {
        // Given
        let urlString = "https://httpbin.org/get"
        
        // When
        let url = try? urlString.asURL()
        
        // Then
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.absoluteString, urlString)
    }
    
    func testStringAsURLWithNonASCIICharacters() {
        // Given
        let urlString = "https://www.example.com/サリーサルマガンディ"
        let expectedURLString = "https://www.example.com/%E3%82%B5%E3%83%AA%E3%83%BC%E3%82%B5%E3%83%AB%E3%83%9E%E3%82%AC%E3%83%B3%E3%83%87%E3%82%A3"
        
        // When
        let url = try? urlString.asURL()
        
        // Then
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.absoluteString, expectedURLString)
    }
    
    func testStringAsURLWithChineseCharacters() {
        // Given
        let urlString = "https://example.com/中文测试"
        let expectedURLString = "https://example.com/%E4%B8%AD%E6%96%87%E6%B5%8B%E8%AF%95"
        
        // When
        let url = try? urlString.asURL()
        
        // Then
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.absoluteString, expectedURLString)
    }
    
    func testStringAsURLWithArabicCharacters() {
        // Given
        let urlString = "https://example.com/اختبار"
        let expectedURLString = "https://example.com/%D8%A7%D8%AE%D8%AA%D8%A8%D8%A7%D8%B1"
        
        // When
        let url = try? urlString.asURL()
        
        // Then
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.absoluteString, expectedURLString)
    }
    
    func testStringAsURLWithMixedCharacters() {
        // Given
        let urlString = "https://example.com/path/文件-file/データ?query=测试&param=value"
        
        // When
        let url = try? urlString.asURL()
        
        // Then
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.contains("example.com"))
        XCTAssertTrue(url!.absoluteString.contains("query="))
        XCTAssertTrue(url!.absoluteString.contains("param=value"))
    }
    
    func testStringAsURLWithInvalidURL() {
        // Given
        let urlString = "not a valid url"
        
        // When
        do {
            _ = try urlString.asURL()
            XCTFail("Should have thrown an error")
        } catch {
            // Then
            XCTAssertTrue(error is AFError)
            if let afError = error as? AFError {
                if case .invalidURL(let url) = afError {
                    XCTAssertEqual(url, urlString)
                } else {
                    XCTFail("Wrong error type")
                }
            }
        }
    }
    
    func testStringAsURLWithSpaces() {
        // Given
        let urlString = "https://example.com/path with spaces"
        let expectedURLString = "https://example.com/path%20with%20spaces"
        
        // When
        let url = try? urlString.asURL()
        
        // Then
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.absoluteString, expectedURLString)
    }
    
    func testStringAsURLWithSpecialCharacters() {
        // Given
        let urlString = "https://example.com/path?name=John+Doe&email=john@example.com"
        
        // When
        let url = try? urlString.asURL()
        
        // Then
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.absoluteString, urlString)
    }
}